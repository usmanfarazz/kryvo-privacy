import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';

/// Local alerts (predicted outages, live changes while the app runs) and,
/// when Firebase is configured, push topics per area.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Alert sound: 'default' or one of [kAlertSounds] (`res/raw/bk_<name>.wav`).
  /// Android fixes a channel's sound when it is created, so each sound has
  /// its own channel.
  static String sound = 'default';

  static AndroidNotificationDetails _alert(
    String id,
    String name,
    String description,
  ) {
    final custom = sound != 'default';
    return AndroidNotificationDetails(
      custom ? '${id}_$sound' : id,
      custom ? '$name ($sound)' : name,
      channelDescription: description,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_bolt',
      color: const Color(0xFFFFD60A),
      sound: custom ? RawResourceAndroidNotificationSound('bk_$sound') : null,
    );
  }

  static AndroidNotificationDetails _predict() => _alert(
    'bk_predict',
    'Outage warnings',
    'Heads-up before a predicted power cut',
  );

  static AndroidNotificationDetails _live() => _alert(
    'bk_live',
    'Light gone / back',
    'When neighbours report the power changed',
  );

  static const _statusChannel = AndroidNotificationDetails(
    'bk_status',
    'Status in the notification bar',
    channelDescription: 'Always-on line showing your area\'s power status',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    showWhen: false,
    icon: 'ic_stat_bolt',
    color: Color(0xFFFFD60A),
  );

  static const _reminderChannel = AndroidNotificationDetails(
    'bk_checklist',
    'Prep reminders',
    channelDescription: 'Reminders from your before-the-cut checklist',
    importance: Importance.defaultImportance,
    icon: 'ic_stat_bolt',
    color: Color(0xFFFFD60A),
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_bolt'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// IDs 100–149: predicted outages for the primary area.
  static Future<void> schedulePredictions({
    required String areaName,
    required List<PredictedOutage> predictions,
    required int leadMinutes,
    required bool quietHours,
  }) async {
    if (!_ready) return;
    for (var i = 100; i < 150; i++) {
      await _plugin.cancel(id: i);
    }
    final now = DateTime.now();
    var id = 100;
    for (final p in predictions.take(12)) {
      final at = p.start.subtract(Duration(minutes: leadMinutes));
      if (!at.isAfter(now)) continue;
      if (quietHours && _isQuiet(at)) continue;
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: _predict()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: trf('⚡ Light may go in {0} min', [leadMinutes]),
        body: trf('{0}: expected {1} – {2}. Charge your phone & fill water!', [
          areaName,
          fmtTime(p.start),
          fmtTime(p.end),
        ]),
      );
    }
  }

  static Future<void> showLiveChange(
    String areaName,
    PowerState state, {
    required bool quietHours,
  }) async {
    if (!_ready) return;
    if (quietHours && _isQuiet(DateTime.now())) return;
    await _plugin.show(
      id: 200,
      title: state == PowerState.off
          ? trf('💡❌ Light gone in {0}', [areaName])
          : trf('💡✅ Light is back in {0}', [areaName]),
      body: state == PowerState.off
          ? tr('Neighbours just reported a power cut.')
          : tr('Neighbours just reported the power is back.'),
      notificationDetails: NotificationDetails(android: _live()),
    );
  }

  /// IDs 300–319: checklist reminders before the next outage.
  static Future<void> scheduleChecklist(
    DateTime outageStart,
    List<String> items,
  ) async {
    if (!_ready) return;
    for (var i = 300; i < 320; i++) {
      await _plugin.cancel(id: i);
    }
    final at = outageStart.subtract(const Duration(minutes: 30));
    if (!at.isAfter(DateTime.now()) || items.isEmpty) return;
    await _plugin.zonedSchedule(
      id: 300,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: tr('📝 Before the light goes'),
      body: items.take(4).join(' • '),
    );
  }

  // ------------------------------------------------------- extras

  static String _statusSig = '';

  /// ID 700: always-on status line in the notification bar.
  static Future<void> showStatus(String title, String body) async {
    if (!_ready) return;
    final sig = '$title|$body';
    if (sig == _statusSig) return;
    _statusSig = sig;
    await _plugin.show(
      id: 700,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _statusChannel),
    );
  }

  static Future<void> hideStatus() async {
    _statusSig = '';
    if (_ready) await _plugin.cancel(id: 700);
  }

  /// ID 500: "UPS should be full" some hours after the light came back.
  static Future<void> scheduleUpsFull(int hours) async {
    if (!_ready) return;
    await _plugin.cancel(id: 500);
    await _plugin.zonedSchedule(
      id: 500,
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(Duration(hours: hours)),
        tz.local,
      ),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: tr('🔋 UPS should be fully charged'),
      body: tr('The light has been on long enough to charge your UPS.'),
    );
  }

  static Future<void> cancelUpsFull() async {
    if (_ready) await _plugin.cancel(id: 500);
  }

  /// ID 501: right when the light goes — how long the UPS will last.
  static Future<void> showUpsBackup(String backup) async {
    if (!_ready) return;
    await _plugin.show(
      id: 501,
      title: tr('🔋 Running on UPS'),
      body: trf('Your UPS should last about {0} with your usual load.', [
        backup,
      ]),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
    );
  }

  /// ID 600: "light is back — run the water pump".
  static Future<void> showMotorNow(String areaName) async {
    if (!_ready) return;
    await _plugin.show(
      id: 600,
      title: tr('🚰 Light is back — run the water pump'),
      body: trf('{0}: fill the tank while there is power.', [areaName]),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
    );
  }

  /// ID 601: tank-full timer.
  static Future<void> scheduleMotorDone(DateTime at) async {
    if (!_ready) return;
    await _plugin.cancel(id: 601);
    await _plugin.zonedSchedule(
      id: 601,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(android: _live()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: tr('🚰 Tank should be full'),
      body: tr('Switch off the water pump.'),
    );
  }

  static Future<void> cancelMotorDone() async {
    if (_ready) await _plugin.cancel(id: 601);
  }

  /// ID 602: the light went while the pump timer was running.
  static Future<void> showMotorStopped() async {
    if (!_ready) return;
    await _plugin.show(
      id: 602,
      title: tr('🚰 Light gone — pump stopped'),
      body: tr(
        'The tank timer was cancelled. Start it again when the light is back.',
      ),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
    );
  }

  /// Plays the chosen alert sound once.
  static Future<void> test() async {
    if (!_ready) return;
    await _plugin.show(
      id: 800,
      title: tr('💡✅ Light is back!'),
      body: tr('This is how alerts will sound.'),
      notificationDetails: NotificationDetails(android: _live()),
    );
  }

  static Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  static bool _isQuiet(DateTime t) => t.hour >= 23 || t.hour < 7;

  // ------------------------------------------------------------- push

  /// Push topics, one per area: `area_<geohash>`. The optional Cloud
  /// Function in /functions sends to them when an area's state flips.
  static Future<void> syncTopics(Set<String> follow, Set<String> before) async {
    try {
      final fm = FirebaseMessaging.instance;
      for (final id in before.difference(follow)) {
        await fm.unsubscribeFromTopic('area_$id');
      }
      for (final id in follow.difference(before)) {
        await fm.subscribeToTopic('area_$id');
      }
    } catch (e) {
      debugPrint('push topics unavailable: $e');
    }
  }
}

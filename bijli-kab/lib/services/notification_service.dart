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

  static const _predictChannel = AndroidNotificationDetails(
    'bk_predict',
    'Outage warnings',
    channelDescription: 'Heads-up before a predicted power cut',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_bolt',
    color: Color(0xFFFFD60A),
  );

  static const _liveChannel = AndroidNotificationDetails(
    'bk_live',
    'Light gone / back',
    channelDescription: 'When neighbours report the power changed',
    importance: Importance.high,
    priority: Priority.high,
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
        notificationDetails: const NotificationDetails(
          android: _predictChannel,
        ),
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
      notificationDetails: const NotificationDetails(android: _liveChannel),
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

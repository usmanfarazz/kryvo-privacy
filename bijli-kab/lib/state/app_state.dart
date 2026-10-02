import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/demo_repository.dart';
import '../services/gamification.dart';
import '../services/notification_service.dart';
import '../services/repository.dart';
import '../services/status_engine.dart';
import '../services/widget_service.dart';
import '../theme.dart';

/// Everything derived from one area's reports.
class AreaLive {
  final List<PowerReport> reports;
  final List<Segment> segments;
  final List<Segment> outages;
  final AreaStatus status;
  final List<List<double>> matrix;
  final List<PredictedOutage> predictions;
  final DateTime? restoreEta;
  final int observedDays;
  final DateTime computedAt;

  const AreaLive({
    required this.reports,
    required this.segments,
    required this.outages,
    required this.status,
    required this.matrix,
    required this.predictions,
    required this.restoreEta,
    required this.observedDays,
    required this.computedAt,
  });

  factory AreaLive.compute(
    List<PowerReport> reports,
    List<ScheduleSlot> schedule,
    DateTime now,
  ) {
    final segs = StatusEngine.segments(reports, now);
    final outs = StatusEngine.outages(segs);
    final status = StatusEngine.current(reports, segs, now);
    DateTime? first;
    for (final r in reports) {
      if (first == null || r.at.isBefore(first)) first = r.at;
    }
    final matrix = StatusEngine.probabilityMatrix(outs, now, first);
    return AreaLive(
      reports: reports,
      segments: segs,
      outages: outs,
      status: status,
      matrix: matrix,
      predictions: StatusEngine.predict(
        matrix: matrix,
        now: now,
        schedule: schedule,
        status: status,
        outages: outs,
      ),
      restoreEta: StatusEngine.predictRestore(status, outs, matrix, now),
      observedDays: StatusEngine.observedDays(now, first),
      computedAt: now,
    );
  }

  PredictedOutage? get next => predictions.isEmpty ? null : predictions.first;
}

class ChecklistItem {
  String text;
  bool done;
  ChecklistItem(this.text, [this.done = false]);
  Map<String, dynamic> toJson() => {'t': text, 'd': done};
  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(j['t'] as String, j['d'] == true);
}

class ReportOutcome {
  final bool ok;
  final int points;
  final bool first;
  final List<Award> newAwards;
  final Level? levelUp;
  final Duration? wait;
  const ReportOutcome({
    required this.ok,
    this.points = 0,
    this.first = false,
    this.newAwards = const [],
    this.levelUp,
    this.wait,
  });
}

class AppState extends ChangeNotifier {
  AppState(this.repo);

  PowerRepository repo;
  late SharedPreferences _p;
  bool ready = false;

  // ------------------------------------------------------------ settings
  String themeId = 'volt';
  String lang = 'rur';
  bool onboarded = false;
  List<SavedArea> areas = [];
  String? activeId;
  bool predictAlerts = true;
  int leadMinutes = 15;
  bool liveAlerts = true;
  bool quietHours = false;
  bool haptics = true;
  bool checklistReminder = true;
  String name = '';
  String avatar = '😎';

  // -------------------------------------------------------------- player
  int points = 0, reportCount = 0, firsts = 0, nightReports = 0;
  int detailReports = 0, shares = 0;
  List<String> reportDays = [];
  final Map<String, DateTime> _lastReportAt = {};

  // ---------------------------------------------------------- per area
  Map<String, List<ScheduleSlot>> schedules = {};
  List<ChecklistItem> checklist = [];
  Map<String, dynamic> toolPrefs = {};

  final Map<String, AreaLive> live = {};
  final Map<String, List<PowerReport>> _raw = {};
  final Map<String, StreamSubscription> _subs = {};
  final Map<String, PowerState> _lastAlerted = {};
  Timer? _tick;
  String _scheduledSig = '';
  Set<String> _topics = {};

  SavedArea? get active =>
      areas.where((a) => a.id == activeId).firstOrNull ?? areas.firstOrNull;
  SavedArea? get primary => areas.firstOrNull;
  AreaLive? get activeLive => active == null ? null : live[active!.id];

  Level get level => levelFor(points);

  PlayerStats get playerStats => PlayerStats(
    points: points,
    reports: reportCount,
    firsts: firsts,
    nightReports: nightReports,
    detailReports: detailReports,
    streak: streak,
    areas: areas.length,
    shares: shares,
  );

  List<Award> get earnedAwards =>
      kAwards.where((b) => b.earned(playerStats)).toList();

  int get streak {
    if (reportDays.isEmpty) return 0;
    final days = reportDays.toSet();
    var d = DateTime.now();
    var n = 0;
    // Today not reported yet doesn't break yesterday's streak.
    if (!days.contains(_day(d))) d = d.subtract(const Duration(days: 1));
    while (days.contains(_day(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    themeId = _p.getString('theme') ?? themeId;
    lang = _p.getString('lang') ?? lang;
    onboarded = _p.getBool('onboarded') ?? false;
    areas = (_p.getStringList('areas') ?? [])
        .map((s) => SavedArea.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    activeId = _p.getString('active');
    predictAlerts = _p.getBool('predictAlerts') ?? true;
    leadMinutes = _p.getInt('leadMinutes') ?? 15;
    liveAlerts = _p.getBool('liveAlerts') ?? true;
    quietHours = _p.getBool('quietHours') ?? false;
    haptics = _p.getBool('haptics') ?? true;
    checklistReminder = _p.getBool('checklistReminder') ?? true;
    name = _p.getString('name') ?? '';
    avatar = _p.getString('avatar') ?? avatar;
    points = _p.getInt('points') ?? 0;
    reportCount = _p.getInt('reports') ?? 0;
    firsts = _p.getInt('firsts') ?? 0;
    nightReports = _p.getInt('nightReports') ?? 0;
    detailReports = _p.getInt('detailReports') ?? 0;
    shares = _p.getInt('shares') ?? 0;
    reportDays = _p.getStringList('reportDays') ?? [];
    _topics = (_p.getStringList('topics') ?? []).toSet();
    final sch = _p.getString('schedules');
    if (sch != null) {
      final m = jsonDecode(sch) as Map<String, dynamic>;
      schedules = m.map(
        (k, v) => MapEntry(
          k,
          (v as List)
              .map((e) => ScheduleSlot.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
    }
    final cl = _p.getString('checklist');
    checklist = cl == null
        ? [
            ChecklistItem('Charge phone & power bank'),
            ChecklistItem('Fill the water tank'),
            ChecklistItem('Iron tomorrow\'s clothes'),
            ChecklistItem('Charge the laptop'),
            ChecklistItem('Keep torch / candles ready'),
          ]
        : (jsonDecode(cl) as List)
              .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList();
    toolPrefs =
        jsonDecode(_p.getString('tools') ?? '{}') as Map<String, dynamic>;

    BK.setTheme(themeId);
    setCurrentLang(lang);

    await NotificationService.init();
    try {
      await repo.init();
    } catch (e) {
      debugPrint('live backend unavailable, using demo: $e');
      repo = DemoRepository();
      await repo.init();
    }
    final r = repo;
    if (r is DemoRepository) r.restorePoints(points, reportCount);

    ready = true;
    _resubscribe();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _recomputeAll());
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  // ------------------------------------------------------- live updates

  void _resubscribe() {
    final want = {
      if (active != null) active!.id,
      if (primary != null) primary!.id,
    };
    for (final id in _subs.keys.toList()) {
      if (!want.contains(id)) {
        _subs.remove(id)?.cancel();
        _raw.remove(id);
        live.remove(id);
      }
    }
    for (final id in want) {
      _subs[id] ??= repo
          .watchReports(id, const Duration(days: 28))
          .listen(
            (reports) => _onReports(id, reports),
            onError: (e) => debugPrint('reports $id: $e'),
          );
    }
    _syncTopics();
  }

  void _onReports(String id, List<PowerReport> reports) {
    _raw[id] = reports;
    _recompute(id);
    notifyListeners();
  }

  void _recomputeAll() {
    for (final id in _raw.keys) {
      _recompute(id);
    }
    notifyListeners();
  }

  void _recompute(String id) {
    final reports = _raw[id] ?? const [];
    final prev = live[id]?.status.state;
    final l = AreaLive.compute(
      reports,
      schedules[id] ?? const [],
      DateTime.now(),
    );
    live[id] = l;
    if (id != primary?.id) return;

    // Live alert when the neighbours flip the state (not on first load, and
    // not when the flip was our own tap).
    final mine = _lastReportAt[id];
    final ownRecent =
        mine != null && DateTime.now().difference(mine).inMinutes < 3;
    if (prev != null &&
        prev != PowerState.unknown &&
        l.status.state != PowerState.unknown &&
        prev != l.status.state &&
        _lastAlerted[id] != l.status.state &&
        !ownRecent &&
        liveAlerts) {
      NotificationService.showLiveChange(
        primary!.title,
        l.status.state,
        quietHours: quietHours,
      );
    }
    if (l.status.state != PowerState.unknown) {
      _lastAlerted[id] = l.status.state;
    }
    _schedule(l);
    WidgetService.update(
      areaName: primary!.title,
      status: l.status,
      next: l.next,
      restoreEta: l.restoreEta,
    );
  }

  void _schedule(AreaLive l) {
    final preds = predictAlerts ? l.predictions : const <PredictedOutage>[];
    final sig =
        '${preds.map((p) => p.start.millisecondsSinceEpoch ~/ 900000).join(',')}'
        '|$leadMinutes|$quietHours|$lang|$checklistReminder';
    if (sig == _scheduledSig) return;
    _scheduledSig = sig;
    NotificationService.schedulePredictions(
      areaName: primary?.title ?? '',
      predictions: preds,
      leadMinutes: leadMinutes,
      quietHours: quietHours,
    );
    final todo = checklist
        .where((c) => !c.done)
        .map((c) => tr(c.text))
        .toList();
    if (checklistReminder && preds.isNotEmpty) {
      NotificationService.scheduleChecklist(preds.first.start, todo);
    } else {
      NotificationService.scheduleChecklist(DateTime(2000), const []);
    }
  }

  Future<void> _syncTopics() async {
    if (!repo.isLive) return;
    final follow = liveAlerts ? areas.map((a) => a.id).toSet() : <String>{};
    await NotificationService.syncTopics(follow, _topics);
    _topics = follow;
    await _p.setStringList('topics', _topics.toList());
  }

  // ------------------------------------------------------------ actions

  Future<ReportOutcome> report(bool on, PowerIssue issue) async {
    final area = active;
    if (area == null) return const ReportOutcome(ok: false);
    final now = DateTime.now();
    final last = _lastReportAt[area.id];
    const cooldown = Duration(minutes: 2);
    if (last != null && now.difference(last) < cooldown) {
      return ReportOutcome(ok: false, wait: cooldown - now.difference(last));
    }
    final current = live[area.id]?.status.state ?? PowerState.unknown;
    final wanted = on ? PowerState.on : PowerState.off;
    final changes = current != wanted;
    // "First" = you announced a change the area didn't know about yet.
    final first = changes && current != PowerState.unknown;
    final earned =
        Points.report +
        (first ? Points.firstToReport : 0) +
        (issue != PowerIssue.none ? Points.withDetail : 0);

    final before = earnedAwards.map((b) => b.id).toSet();
    final levelBefore = level;

    _lastReportAt[area.id] = now;
    points += earned;
    reportCount++;
    if (first) firsts++;
    if (now.hour < 5) nightReports++;
    if (issue != PowerIssue.none) detailReports++;
    final today = _day(now);
    if (!reportDays.contains(today)) {
      reportDays = [...reportDays, today];
      if (reportDays.length > 60) {
        reportDays = reportDays.sublist(reportDays.length - 60);
      }
    }
    await _saveStats();

    try {
      await repo.submitReport(
        area: area,
        on: on,
        issue: issue,
        changesState: changes,
        points: earned,
      );
    } catch (e) {
      debugPrint('report failed: $e');
    }

    final newAwards = earnedAwards
        .where((b) => !before.contains(b.id))
        .toList();
    final lv = level;
    notifyListeners();
    return ReportOutcome(
      ok: true,
      points: earned,
      first: first,
      newAwards: newAwards,
      levelUp: lv.number > levelBefore.number ? lv : null,
    );
  }

  Future<void> _saveStats() async {
    await _p.setInt('points', points);
    await _p.setInt('reports', reportCount);
    await _p.setInt('firsts', firsts);
    await _p.setInt('nightReports', nightReports);
    await _p.setInt('detailReports', detailReports);
    await _p.setInt('shares', shares);
    await _p.setStringList('reportDays', reportDays);
  }

  Future<void> countShare() async {
    shares++;
    await _p.setInt('shares', shares);
    notifyListeners();
  }

  // ---------------------------------------------------------- areas

  Future<void> addArea(SavedArea a, {bool makeActive = true}) async {
    areas = [...areas.where((x) => x.id != a.id), a];
    if (makeActive) activeId = a.id;
    await _saveAreas();
    _resubscribe();
    notifyListeners();
  }

  Future<void> updateArea(SavedArea a) async {
    areas = [for (final x in areas) x.id == a.id ? a : x];
    await _saveAreas();
    notifyListeners();
  }

  Future<void> removeArea(String id) async {
    areas = areas.where((a) => a.id != id).toList();
    if (activeId == id) activeId = areas.firstOrNull?.id;
    await _saveAreas();
    _resubscribe();
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    activeId = id;
    await _p.setString('active', id);
    _resubscribe();
    notifyListeners();
  }

  /// The primary area drives alerts and the home-screen widget.
  Future<void> makePrimary(String id) async {
    final a = areas.firstWhere((x) => x.id == id);
    areas = [a, ...areas.where((x) => x.id != id)];
    _scheduledSig = '';
    await _saveAreas();
    _resubscribe();
    if (_raw.containsKey(id)) _recompute(id);
    notifyListeners();
  }

  Future<void> _saveAreas() async {
    await _p.setStringList(
      'areas',
      areas.map((a) => jsonEncode(a.toJson())).toList(),
    );
    if (activeId != null) await _p.setString('active', activeId!);
  }

  // ------------------------------------------------------- schedule

  List<ScheduleSlot> scheduleFor(String id) => schedules[id] ?? const [];

  Future<void> setSchedule(String id, List<ScheduleSlot> slots) async {
    schedules = {...schedules, id: slots};
    await _p.setString(
      'schedules',
      jsonEncode(
        schedules.map((k, v) => MapEntry(k, v.map((s) => s.toJson()).toList())),
      ),
    );
    _scheduledSig = '';
    if (_raw.containsKey(id)) _recompute(id);
    notifyListeners();
  }

  // ------------------------------------------------------ checklist

  Future<void> saveChecklist() async {
    await _p.setString(
      'checklist',
      jsonEncode(checklist.map((c) => c.toJson()).toList()),
    );
    _scheduledSig = '';
    notifyListeners();
  }

  Future<void> resetChecklist() async {
    for (final c in checklist) {
      c.done = false;
    }
    await saveChecklist();
  }

  Future<void> saveTools(Map<String, dynamic> prefs) async {
    toolPrefs = {...toolPrefs, ...prefs};
    await _p.setString('tools', jsonEncode(toolPrefs));
  }

  // ------------------------------------------------------- settings

  Future<void> setTheme(String id) async {
    themeId = id;
    BK.setTheme(id);
    await _p.setString('theme', id);
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    lang = code;
    setCurrentLang(code);
    await _p.setString('lang', code);
    _scheduledSig = '';
    _recomputeAll();
  }

  Future<void> setAlerts({
    bool? predict,
    int? lead,
    bool? liveChanges,
    bool? quiet,
    bool? checklistReminder,
  }) async {
    if (predict != null) predictAlerts = predict;
    if (lead != null) leadMinutes = lead;
    if (liveChanges != null) liveAlerts = liveChanges;
    if (quiet != null) quietHours = quiet;
    if (checklistReminder != null) this.checklistReminder = checklistReminder;
    await _p.setBool('predictAlerts', predictAlerts);
    await _p.setInt('leadMinutes', leadMinutes);
    await _p.setBool('liveAlerts', liveAlerts);
    await _p.setBool('quietHours', quietHours);
    await _p.setBool('checklistReminder', this.checklistReminder);
    _scheduledSig = '';
    final pid = primary?.id;
    if (pid != null && live[pid] != null) _schedule(live[pid]!);
    _syncTopics();
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    await _p.setBool('haptics', v);
    notifyListeners();
  }

  Future<void> saveProfile(String newName, String newAvatar) async {
    name = newName.trim();
    avatar = newAvatar;
    await _p.setString('name', name);
    await _p.setString('avatar', avatar);
    try {
      await repo.saveProfile(
        name: name.isEmpty ? 'Reporter' : name,
        avatar: avatar,
        city: primary?.city ?? '',
      );
    } catch (e) {
      debugPrint('profile sync failed: $e');
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _p.setBool('onboarded', true);
    notifyListeners();
  }

  /// Wipes everything stored on this phone.
  Future<void> resetAll() async {
    await NotificationService.cancelAll();
    await _p.clear();
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _raw.clear();
    live.clear();
    areas = [];
    activeId = null;
    onboarded = false;
    points = reportCount = firsts = nightReports = detailReports = shares = 0;
    reportDays = [];
    schedules = {};
    name = '';
    notifyListeners();
  }
}

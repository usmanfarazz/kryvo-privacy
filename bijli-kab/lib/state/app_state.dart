import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../l10n/format.dart';
import '../services/app_lock.dart';
import '../services/challenges.dart';
import '../services/demo_repository.dart';
import '../services/geohash.dart';
import '../services/location_service.dart';
import '../services/power_math.dart';
import '../services/share_service.dart';
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

/// A guess of when the light will come back ("Andaza Lagao").
class Guess {
  final String areaId;
  final DateTime outageStart;
  final DateTime at; // guessed return time
  final DateTime madeAt;
  const Guess(this.areaId, this.outageStart, this.at, this.madeAt);
  Map<String, dynamic> toJson() => {
    'a': areaId,
    's': outageStart.millisecondsSinceEpoch,
    't': at.millisecondsSinceEpoch,
    'm': madeAt.millisecondsSinceEpoch,
  };
  factory Guess.fromJson(Map<String, dynamic> j) => Guess(
    j['a'] as String,
    DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
    DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    DateTime.fromMillisecondsSinceEpoch(j['m'] as int),
  );
}

class GuessResult {
  final DateTime guessed;
  final DateTime actual;
  final int points;
  final bool tooLate;
  const GuessResult(this.guessed, this.actual, this.points, this.tooLate);
  int get minutesOff => guessed.difference(actual).inMinutes.abs();
}

class Complaint {
  final DateTime at;
  final String number;
  final String note;
  const Complaint(this.at, this.number, this.note);
  Map<String, dynamic> toJson() => {
    't': at.millisecondsSinceEpoch,
    'n': number,
    'x': note,
  };
  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
    DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    (j['n'] ?? '') as String,
    (j['x'] ?? '') as String,
  );
}

enum FriendCodeResult { added, alreadyFollowing, invalid }

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

  // ------------------------------------------------------------ extras
  int bonus = 0; // points from games and challenges (kept on this phone)
  Guess? guess;
  GuessResult? guessResult; // shown once on the home screen
  int guessesMade = 0, guessWins = 0;
  bool celebrateOn = true;
  int celebrateTick = 0; // bumps when the light comes back
  String alertSound = 'default';
  bool upsReminder = false;
  int upsChargeHours = 6;
  bool motorReminder = false;
  int tankMinutes = 30;
  DateTime? motorEndsAt;
  bool statusBar = false;
  String helpline = '118';
  String consumerRef = '';
  List<Complaint> complaints = [];
  int invites = 0;
  bool usedFriendCode = false;
  String _week = '';
  Map<String, int> weekCounts = {};
  List<String> weekDays = [];
  List<String> claimed = []; // "<week>|<challengeId>"
  int challengesDone = 0;
  final List<Challenge> justCompleted = [];
  Map<String, String> myMoods = {};
  Map<String, int> moods = {};
  StreamSubscription? _moodSub;
  String? _moodArea;
  bool lockEnabled = false, lockBiometric = false, locked = false;
  String _lockHash = '', _lockSalt = '';

  int get totalPoints => points + bonus;

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

  Level get level => levelFor(totalPoints);

  PlayerStats get playerStats => PlayerStats(
    points: totalPoints,
    guessWins: guessWins,
    challenges: challengesDone,
    invites: invites,
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
    _loadExtras(
      jsonDecode(_p.getString('extras') ?? '{}') as Map<String, dynamic>,
    );
    locked = lockEnabled;

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
    _moodSub?.cancel();
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
    _watchMoods();
  }

  void _watchMoods() {
    final id = active?.id;
    if (id == _moodArea) return;
    _moodSub?.cancel();
    _moodArea = id;
    moods = {};
    if (id == null) return;
    _moodSub = repo.watchMoods(id).listen((m) {
      moods = m;
      notifyListeners();
    }, onError: (e) => debugPrint('moods: $e'));
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
    _checkGuess(id, l);
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
    final flipped =
        prev != null &&
        prev != PowerState.unknown &&
        l.status.state != PowerState.unknown &&
        prev != l.status.state;
    if (flipped) _onFlip(l, ownRecent);
    if (l.status.state != PowerState.unknown) {
      _lastAlerted[id] = l.status.state;
    }
    _updateStatusBar(l);
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
    _bumpWeek(ChallengeKind.reports);
    _bumpWeek(ChallengeKind.days);
    if (first) _bumpWeek(ChallengeKind.firsts);
    if (issue != PowerIssue.none) _bumpWeek(ChallengeKind.details);

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
    _bumpWeek(ChallengeKind.shares);
    notifyListeners();
  }

  // --------------------------------------------------- light flips

  /// The main area's light just went or came back.
  void _onFlip(AreaLive l, bool own) {
    if (l.status.state == PowerState.on) {
      if (celebrateOn && !own) celebrateTick++;
      if (upsReminder) NotificationService.scheduleUpsFull(upsChargeHours);
      if (motorReminder) NotificationService.showMotorNow(primary!.title);
    } else {
      NotificationService.cancelUpsFull();
      if (upsReminder) {
        final h = upsHoursFromPrefs(toolPrefs);
        if (h > 0) {
          NotificationService.showUpsBackup(
            fmtDuration(Duration(minutes: (h * 60).round())),
          );
        }
      }
      if (motorEndsAt != null) {
        motorEndsAt = null;
        NotificationService.cancelMotorDone();
        NotificationService.showMotorStopped();
        _saveExtras();
      }
    }
  }

  void _updateStatusBar(AreaLive l) {
    if (!statusBar) {
      NotificationService.hideStatus();
      return;
    }
    final s = l.status;
    final head = switch (s.state) {
      PowerState.on => '💡 ${tr('Light is ON')}',
      PowerState.off => '🔌 ${tr('Light is OFF')}',
      PowerState.unknown => '❔ ${tr('No recent reports')}',
    };
    final since = s.since == null
        ? ''
        : ' · ${trf('for {0}', [fmtDuration(DateTime.now().difference(s.since!))])}';
    final body = s.state == PowerState.off
        ? (l.restoreEta == null
              ? primary!.title
              : '${primary!.title} · ${trf('Back ~{0}', [fmtTime(l.restoreEta!)])}')
        : (l.next == null
              ? '${primary!.title} · ${tr('No cut expected soon')}'
              : '${primary!.title} · ${trf('Next cut ~{0}', [fmtTime(l.next!.start)])}');
    NotificationService.showStatus('$head$since', body);
  }

  // ---------------------------------------------------- guess game

  /// Guess when the light returns in the active area (only while it's off).
  Future<bool> makeGuess(DateTime at) async {
    final a = active;
    final s = activeLive?.status;
    if (a == null ||
        s == null ||
        s.state != PowerState.off ||
        s.since == null) {
      return false;
    }
    guess = Guess(a.id, s.since!, at, DateTime.now());
    guessesMade++;
    await _saveExtras();
    notifyListeners();
    return true;
  }

  /// Points by how close the guess was.
  static int guessPoints(int minutesOff) => minutesOff <= 10
      ? 30
      : minutesOff <= 20
      ? 20
      : minutesOff <= 45
      ? 10
      : 2;

  void _checkGuess(String id, AreaLive l) {
    final g = guess;
    if (g == null || g.areaId != id) return;
    final s = l.status;
    if (s.state == PowerState.on &&
        s.since != null &&
        s.since!.isAfter(g.outageStart)) {
      final actual = s.since!;
      // A guess made in the last 10 minutes before the light came back
      // doesn't count — no last-second guessing.
      final tooLate = actual.difference(g.madeAt).inMinutes < 10;
      final off = g.at.difference(actual).inMinutes.abs();
      final pts = tooLate ? 0 : guessPoints(off);
      guessResult = GuessResult(g.at, actual, pts, tooLate);
      guess = null;
      if (pts > 0) bonus += pts;
      if (!tooLate && off <= 20) {
        guessWins++;
        _bumpWeek(ChallengeKind.guessWins);
      }
      _saveExtras();
    } else if (DateTime.now().difference(g.outageStart) >
        const Duration(hours: 14)) {
      guess = null;
      _saveExtras();
    }
  }

  void clearGuessResult() {
    guessResult = null;
    notifyListeners();
  }

  // ---------------------------------------------------- weekly challenges

  void _rollWeek() {
    final k = weekKey(DateTime.now());
    if (k == _week) return;
    _week = k;
    weekCounts = {};
    weekDays = [];
  }

  int weekProgress(Challenge c) {
    _rollWeek();
    return c.kind == ChallengeKind.days
        ? weekDays.length
        : (weekCounts[c.kind.name] ?? 0);
  }

  bool isClaimed(Challenge c) => claimed.contains('$_week|${c.id}');

  void _bumpWeek(ChallengeKind kind, [int n = 1]) {
    _rollWeek();
    if (kind == ChallengeKind.days) {
      final today = _day(DateTime.now());
      if (!weekDays.contains(today)) weekDays = [...weekDays, today];
    } else {
      weekCounts[kind.name] = (weekCounts[kind.name] ?? 0) + n;
    }
    for (final c in challengesFor(DateTime.now())) {
      if (!isClaimed(c) && weekProgress(c) >= c.target) {
        claimed = [...claimed, '$_week|${c.id}'];
        if (claimed.length > 60) claimed = claimed.sublist(claimed.length - 60);
        bonus += c.reward;
        challengesDone++;
        justCompleted.add(c);
      }
    }
    _saveExtras();
  }

  // ------------------------------------------------------------ moods

  Future<void> setMood(String emoji) async {
    final a = active;
    if (a == null) return;
    if (myMoods[a.id] != emoji) _bumpWeek(ChallengeKind.moods);
    myMoods = {...myMoods, a.id: emoji};
    await _saveExtras();
    notifyListeners();
    try {
      await repo.setMood(a.id, emoji);
    } catch (e) {
      debugPrint('mood failed: $e');
    }
  }

  // --------------------------------------------------- invite friends

  /// Code a friend types to follow your area: your main area's geohash.
  String get inviteCode => primary?.id ?? '';

  Future<void> shareInvite() async {
    await ShareService.shareText(
      trf(
        'I check the light with Bijli Kab? ⚡ Follow my area with code {0} (More → Invite friends → Enter code).',
        [inviteCode],
      ),
    );
    invites++;
    _bumpWeek(ChallengeKind.shares);
    await _saveExtras();
    notifyListeners();
  }

  Future<FriendCodeResult> addFriendCode(String raw) async {
    final code = raw.trim().toLowerCase();
    if (code.length != kAreaPrecision || !isValidGeohash(code)) {
      return FriendCodeResult.invalid;
    }
    if (areas.any((a) => a.id == code)) {
      return FriendCodeResult.alreadyFollowing;
    }
    final box = geohashDecode(code);
    final a = await LocationService.areaAt(box.lat, box.lng, emoji: '🤝');
    await addArea(a, makeActive: false);
    if (!usedFriendCode) {
      usedFriendCode = true;
      bonus += 20;
      await _saveExtras();
    }
    notifyListeners();
    return FriendCodeResult.added;
  }

  // -------------------------------------------------------- complaints

  Future<void> addComplaint(String number, String note) async {
    complaints = [Complaint(DateTime.now(), number, note), ...complaints];
    await _saveExtras();
    notifyListeners();
  }

  Future<void> removeComplaint(Complaint c) async {
    complaints = complaints.where((x) => x != c).toList();
    await _saveExtras();
    notifyListeners();
  }

  Future<void> setHelpline(String number, String ref) async {
    helpline = number.trim();
    consumerRef = ref.trim();
    await _saveExtras();
    notifyListeners();
  }

  // ------------------------------------------------------- motor timer

  Future<void> startMotor(int minutes) async {
    tankMinutes = minutes;
    motorEndsAt = DateTime.now().add(Duration(minutes: minutes));
    await NotificationService.scheduleMotorDone(motorEndsAt!);
    await _saveExtras();
    notifyListeners();
  }

  Future<void> stopMotor() async {
    motorEndsAt = null;
    await NotificationService.cancelMotorDone();
    await _saveExtras();
    notifyListeners();
  }

  // ------------------------------------------------------- extra alerts

  Future<void> setExtras({
    bool? celebrate,
    String? sound,
    bool? ups,
    int? upsHours,
    bool? motor,
    bool? statusLine,
  }) async {
    if (celebrate != null) celebrateOn = celebrate;
    if (sound != null) {
      alertSound = sound;
      NotificationService.sound = sound;
      _scheduledSig = '';
    }
    if (ups != null) upsReminder = ups;
    if (upsHours != null) upsChargeHours = upsHours;
    if (motor != null) motorReminder = motor;
    if (statusLine != null) statusBar = statusLine;
    await _saveExtras();
    final pid = primary?.id;
    if (pid != null && live[pid] != null) {
      _updateStatusBar(live[pid]!);
      _schedule(live[pid]!);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------- app lock

  Future<void> setPin(String pin) async {
    _lockSalt = AppLock.newSalt();
    _lockHash = AppLock.hash(pin, _lockSalt);
    lockEnabled = true;
    await _saveExtras();
    notifyListeners();
  }

  bool checkPin(String pin) =>
      lockEnabled && AppLock.hash(pin, _lockSalt) == _lockHash;

  Future<void> disableLock() async {
    lockEnabled = false;
    lockBiometric = false;
    locked = false;
    _lockHash = _lockSalt = '';
    await _saveExtras();
    notifyListeners();
  }

  Future<void> setLockBiometric(bool v) async {
    lockBiometric = v;
    await _saveExtras();
    notifyListeners();
  }

  void lock() {
    if (lockEnabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  // ------------------------------------------------------ persistence

  void _loadExtras(Map<String, dynamic> j) {
    T get<T>(String k, T d) => j[k] is T ? j[k] as T : d;
    bonus = get('bonus', 0);
    final g = j['guess'];
    guess = g is Map<String, dynamic> ? Guess.fromJson(g) : null;
    guessResult = null;
    guessesMade = get('guessesMade', 0);
    guessWins = get('guessWins', 0);
    celebrateOn = get('celebrate', true);
    alertSound = get('sound', 'default');
    NotificationService.sound = alertSound;
    upsReminder = get('ups', false);
    upsChargeHours = get('upsHours', 6);
    motorReminder = get('motor', false);
    tankMinutes = get('tank', 30);
    final m = j['motorEnds'];
    motorEndsAt = m is int ? DateTime.fromMillisecondsSinceEpoch(m) : null;
    if (motorEndsAt != null && motorEndsAt!.isBefore(DateTime.now())) {
      motorEndsAt = null;
    }
    statusBar = get('statusBar', false);
    helpline = get('helpline', '118');
    consumerRef = get('ref', '');
    complaints = (j['complaints'] is List ? j['complaints'] as List : [])
        .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
        .toList();
    invites = get('invites', 0);
    usedFriendCode = get('friendCode', false);
    _week = get('week', '');
    weekCounts = (j['weekCounts'] is Map ? j['weekCounts'] as Map : {}).map(
      (k, v) => MapEntry('$k', (v as num).toInt()),
    );
    weekDays = (j['weekDays'] is List ? j['weekDays'] as List : [])
        .cast<String>();
    claimed = (j['claimed'] is List ? j['claimed'] as List : []).cast<String>();
    challengesDone = get('challengesDone', 0);
    myMoods = (j['moods'] is Map ? j['moods'] as Map : {}).map(
      (k, v) => MapEntry('$k', '$v'),
    );
    lockEnabled = get('lock', false);
    lockBiometric = get('lockBio', false);
    _lockHash = get('lockHash', '');
    _lockSalt = get('lockSalt', '');
    if (_lockHash.isEmpty) lockEnabled = false;
  }

  Future<void> _saveExtras() => _p.setString(
    'extras',
    jsonEncode({
      'bonus': bonus,
      if (guess != null) 'guess': guess!.toJson(),
      'guessesMade': guessesMade,
      'guessWins': guessWins,
      'celebrate': celebrateOn,
      'sound': alertSound,
      'ups': upsReminder,
      'upsHours': upsChargeHours,
      'motor': motorReminder,
      'tank': tankMinutes,
      if (motorEndsAt != null) 'motorEnds': motorEndsAt!.millisecondsSinceEpoch,
      'statusBar': statusBar,
      'helpline': helpline,
      'ref': consumerRef,
      'complaints': complaints.map((c) => c.toJson()).toList(),
      'invites': invites,
      'friendCode': usedFriendCode,
      'week': _week,
      'weekCounts': weekCounts,
      'weekDays': weekDays,
      'claimed': claimed,
      'challengesDone': challengesDone,
      'moods': myMoods,
      'lock': lockEnabled,
      'lockBio': lockBiometric,
      'lockHash': _lockHash,
      'lockSalt': _lockSalt,
    }),
  );

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
    _loadExtras({});
    locked = false;
    moods = {};
    NotificationService.hideStatus();
    notifyListeners();
  }
}

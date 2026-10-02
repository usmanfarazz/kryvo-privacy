import 'dart:async';
import 'dart:math';

import '../models/models.dart';
import 'geohash.dart';
import 'repository.dart';

/// Offline simulation of a busy neighbourhood.
///
/// Every area gets a deterministic load-shedding pattern (seeded from its
/// geohash) with a handful of simulated neighbours reporting it, including
/// the odd wrong tap. Your own reports are mixed in live.
class DemoRepository implements PowerRepository {
  @override
  bool get isLive => false;
  @override
  String get uid => 'me';

  final _mine = <String, List<PowerReport>>{};
  final _myMood = <String, String>{};
  final _changes = StreamController<String>.broadcast();
  String _name = 'You', _avatar = '😎', _city = '';
  int _points = 0, _reports = 0;

  @override
  Future<void> init() async {}

  static const _neighbours = [
    'Ali',
    'Ayesha',
    'Bilal',
    'Fatima',
    'Hamza',
    'Zainab',
    'Usman',
    'Sana',
  ];

  /// Daily outage windows for an area: list of (startMinute, duration).
  static List<(int, int)> _pattern(String areaId) {
    final rnd = Random(areaId.hashCode);
    final candidates = [
      2 * 60,
      6 * 60,
      9 * 60,
      12 * 60,
      14 * 60,
      17 * 60,
      20 * 60,
      23 * 60,
    ];
    candidates.shuffle(rnd);
    final n = 2 + rnd.nextInt(2);
    return [
      for (var i = 0; i < n; i++)
        (candidates[i] + rnd.nextInt(4) * 15, 60 + rnd.nextInt(3) * 30),
    ];
  }

  List<PowerReport> _simulated(String areaId, DateTime from, DateTime now) {
    final out = <PowerReport>[];
    final pattern = _pattern(areaId);
    var day = DateTime(from.year, from.month, from.day);
    while (!day.isAfter(now)) {
      final rnd = Random(
        areaId.hashCode ^ day.millisecondsSinceEpoch ~/ 86400000,
      );
      for (final (startMin, dur) in pattern) {
        if (rnd.nextDouble() < 0.12) continue; // a lucky day
        final jitter = rnd.nextInt(21) - 10;
        final start = day.add(Duration(minutes: startMin + jitter));
        final end = start.add(Duration(minutes: dur + rnd.nextInt(31) - 15));
        final people = 2 + rnd.nextInt(4);
        for (var p = 0; p < people; p++) {
          final who = _neighbours[(p + rnd.nextInt(3)) % _neighbours.length];
          out.add(
            PowerReport(
              uid: who,
              on: false,
              at: start.add(Duration(minutes: rnd.nextInt(6))),
              issue: p == 0 && rnd.nextDouble() < 0.25
                  ? PowerIssue.scheduled
                  : PowerIssue.none,
            ),
          );
          out.add(
            PowerReport(
              uid: who,
              on: true,
              at: end.add(Duration(minutes: rnd.nextInt(6))),
            ),
          );
        }
        // The occasional wrong tap, which the vote should ignore.
        if (rnd.nextDouble() < 0.2) {
          out.add(
            PowerReport(
              uid: 'troll',
              on: true,
              at: start.add(Duration(minutes: 20 + rnd.nextInt(10))),
            ),
          );
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return out
        .where((r) => !r.at.isBefore(from) && !r.at.isAfter(now))
        .toList();
  }

  List<PowerReport> _all(String areaId, Duration window) {
    final now = DateTime.now();
    final from = now.subtract(window);
    return [
      ..._simulated(areaId, from, now),
      ...?_mine[areaId]?.where((r) => !r.at.isBefore(from)),
    ];
  }

  @override
  Stream<List<PowerReport>> watchReports(String areaId, Duration window) {
    late StreamController<List<PowerReport>> c;
    Timer? tick;
    StreamSubscription<String>? sub;
    c = StreamController<List<PowerReport>>(
      onListen: () {
        c.add(_all(areaId, window));
        tick = Timer.periodic(
          const Duration(minutes: 1),
          (_) => c.add(_all(areaId, window)),
        );
        sub = _changes.stream
            .where((id) => id == areaId)
            .listen((_) => c.add(_all(areaId, window)));
      },
      onCancel: () {
        tick?.cancel();
        sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<void> submitReport({
    required SavedArea area,
    required bool on,
    required PowerIssue issue,
    required bool changesState,
    required int points,
  }) async {
    (_mine[area.id] ??= []).add(
      PowerReport(uid: uid, on: on, at: DateTime.now(), issue: issue),
    );
    _points += points;
    _reports++;
    _changes.add(area.id);
  }

  Map<String, int> _moods(String areaId) {
    final now = DateTime.now();
    final rnd = Random(
      areaId.hashCode ^ (now.millisecondsSinceEpoch ~/ 10800000),
    );
    final m = {for (final e in kMoods) e: rnd.nextInt(18)};
    final mine = _myMood[areaId];
    if (mine != null) m[mine] = m[mine]! + 1;
    return m;
  }

  @override
  Stream<Map<String, int>> watchMoods(String areaId) {
    late StreamController<Map<String, int>> c;
    StreamSubscription<String>? sub;
    c = StreamController<Map<String, int>>(
      onListen: () {
        c.add(_moods(areaId));
        sub = _changes.stream
            .where((id) => id == 'mood:$areaId')
            .listen((_) => c.add(_moods(areaId)));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Future<void> setMood(String areaId, String emoji) async {
    _myMood[areaId] = emoji;
    _changes.add('mood:$areaId');
  }

  @override
  Future<List<AreaSnapshot>> nearby(String prefix) async {
    final box = geohashDecode(prefix);
    final now = DateTime.now();
    final rnd = Random(prefix.hashCode);
    final names = [
      'Model Town',
      'Johar Town',
      'Gulberg',
      'Township',
      'Iqbal Town',
      'Faisal Town',
      'Garden Town',
      'Shadman',
      'Samanabad',
      'Wapda Town',
      'Cantt',
      'Allama Iqbal Town',
      'Sabzazar',
      'Valencia',
      'DHA Phase 5',
      'Bahria Town',
      'Ichra',
      'Mozang',
      'Anarkali',
      'Shad Bagh',
    ];
    final out = <AreaSnapshot>[];
    for (var i = 0; i < 18; i++) {
      final lat = box.latMin + rnd.nextDouble() * (box.latMax - box.latMin);
      final lng = box.lngMin + rnd.nextDouble() * (box.lngMax - box.lngMin);
      final id = geohashEncode(lat, lng);
      final segs = _simulated(id, now.subtract(const Duration(hours: 14)), now);
      segs.sort((a, b) => a.at.compareTo(b.at));
      final last = segs.isEmpty ? null : segs.last;
      final firstOfRun = segs.reversed
          .takeWhile((r) => last == null || r.on == last.on)
          .lastOrNull;
      out.add(
        AreaSnapshot(
          id: id,
          place: names[i % names.length],
          city: '',
          lat: lat,
          lng: lng,
          state: last == null
              ? PowerState.on
              : (last.on ? PowerState.on : PowerState.off),
          since: firstOfRun?.at,
          updated: last?.at ?? now,
          reports24h: segs.length,
        ),
      );
    }
    return out;
  }

  @override
  Future<List<LeaderEntry>> leaderboard({String? city}) async {
    final rnd = Random(7);
    final fake = [
      for (var i = 0; i < _neighbours.length; i++)
        LeaderEntry(
          uid: _neighbours[i],
          name: _neighbours[i],
          avatar: ['🦁', '🌸', '🚀', '🌙', '⚡', '🐯', '🎯', '🌟'][i],
          city: city ?? 'Lahore',
          points: 200 + rnd.nextInt(1800),
          reports: 20 + rnd.nextInt(150),
        ),
      LeaderEntry(
        uid: uid,
        name: _name,
        avatar: _avatar,
        city: _city,
        points: _points,
        reports: _reports,
      ),
    ]..sort((a, b) => b.points.compareTo(a.points));
    return fake;
  }

  @override
  Future<void> saveProfile({
    required String name,
    required String avatar,
    required String city,
  }) async {
    _name = name;
    _avatar = avatar;
    _city = city;
  }

  /// Lets the app seed the demo leaderboard with points earned earlier.
  void restorePoints(int points, int reports) {
    _points = points;
    _reports = reports;
  }
}

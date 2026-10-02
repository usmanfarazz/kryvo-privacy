import 'package:bijli_kab/models/models.dart';
import 'package:bijli_kab/services/demo_repository.dart';
import 'package:bijli_kab/services/geohash.dart';
import 'package:bijli_kab/services/status_engine.dart';
import 'package:flutter_test/flutter_test.dart';

PowerReport r(String uid, bool on, DateTime at) =>
    PowerReport(uid: uid, on: on, at: at);

void main() {
  final t0 = DateTime(2026, 10, 1, 12, 0);

  group('geohash', () {
    test('a point lies inside its own cell', () {
      // Lahore, Minar-e-Pakistan.
      final h = geohashEncode(31.5925, 74.3095);
      expect(h.length, kAreaPrecision);
      final box = geohashDecode(h);
      expect(31.5925, inInclusiveRange(box.latMin, box.latMax));
      expect(74.3095, inInclusiveRange(box.lngMin, box.lngMax));
    });

    test('matches the reference implementation', () {
      expect(geohashEncode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
      expect(geohashEncode(-25.382708, -49.265506, precision: 6), '6gkzwg');
    });

    test('validates', () {
      expect(isValidGeohash('ttsg'), isTrue);
      expect(isValidGeohash('abc!'), isFalse);
      expect(isValidGeohash(''), isFalse);
    });
  });

  group('segments', () {
    test('empty reports give no segments', () {
      expect(StatusEngine.segments([], t0), isEmpty);
    });

    test('off then on makes one outage', () {
      final reports = [
        r('a', true, t0),
        r('b', false, t0.add(const Duration(minutes: 30))),
        r('c', false, t0.add(const Duration(minutes: 32))),
        r('a', true, t0.add(const Duration(minutes: 90))),
      ];
      final segs = StatusEngine.segments(
        reports,
        t0.add(const Duration(hours: 2)),
      );
      final outs = StatusEngine.outages(segs);
      expect(outs, hasLength(1));
      expect(outs.single.start, t0.add(const Duration(minutes: 30)));
      expect(outs.single.end, t0.add(const Duration(minutes: 90)));
      expect(outs.single.reporters, 2);
      expect(segs.last.state, PowerState.on);
    });

    test('a single wrong tap is out-voted', () {
      final reports = [
        r('a', false, t0),
        r('b', false, t0.add(const Duration(minutes: 1))),
        r('troll', true, t0.add(const Duration(minutes: 10))),
        r('c', false, t0.add(const Duration(minutes: 12))),
        r('d', false, t0.add(const Duration(minutes: 14))),
      ];
      final segs = StatusEngine.segments(
        reports,
        t0.add(const Duration(minutes: 30)),
      );
      expect(segs, hasLength(1));
      expect(segs.single.state, PowerState.off);
    });

    test('a lone reporter can still flip the state', () {
      final reports = [
        r('a', true, t0),
        r('a', false, t0.add(const Duration(hours: 1))),
      ];
      final segs = StatusEngine.segments(
        reports,
        t0.add(const Duration(hours: 2)),
      );
      expect(segs.last.state, PowerState.off);
    });

    test('very long outage without news becomes unknown', () {
      final reports = [r('a', false, t0)];
      final now = t0.add(const Duration(hours: 20));
      final segs = StatusEngine.segments(reports, now);
      expect(segs.first.state, PowerState.off);
      expect(segs.first.duration, StatusEngine.maxOutage);
      expect(segs.last.state, PowerState.unknown);
      expect(
        StatusEngine.current(reports, segs, now).state,
        PowerState.unknown,
      );
    });

    test('future reports are ignored', () {
      final reports = [r('a', false, t0.add(const Duration(hours: 5)))];
      expect(StatusEngine.segments(reports, t0), isEmpty);
    });
  });

  group('current status', () {
    test('reports since, reporters and a fresh confidence', () {
      final reports = [
        r('a', false, t0),
        r('b', false, t0.add(const Duration(minutes: 2))),
        r('c', false, t0.add(const Duration(minutes: 3))),
      ];
      final now = t0.add(const Duration(minutes: 20));
      final segs = StatusEngine.segments(reports, now);
      final s = StatusEngine.current(reports, segs, now);
      expect(s.state, PowerState.off);
      expect(s.since, t0);
      expect(s.reporters, 3);
      expect(s.confidence, greaterThan(0.9));
    });

    test('confidence drops as reports get old', () {
      final reports = [r('a', true, t0)];
      final soon = t0.add(const Duration(minutes: 5));
      final fresh = StatusEngine.current(
        reports,
        StatusEngine.segments(reports, soon),
        soon,
      );
      final later = t0.add(const Duration(hours: 10));
      final old = StatusEngine.current(
        reports,
        StatusEngine.segments(reports, later),
        later,
      );
      expect(old.confidence, lessThan(fresh.confidence));
    });

    test('keeps the latest issue detail', () {
      final reports = [
        r('a', true, t0),
        PowerReport(
          uid: 'b',
          on: false,
          at: t0.add(const Duration(minutes: 5)),
          issue: PowerIssue.transformer,
        ),
      ];
      final now = t0.add(const Duration(minutes: 10));
      final s = StatusEngine.current(
        reports,
        StatusEngine.segments(reports, now),
        now,
      );
      expect(s.issue, PowerIssue.transformer);
    });
  });

  group('stats', () {
    final outs = [
      Segment(
        PowerState.off,
        DateTime(2026, 10, 1, 23),
        DateTime(2026, 10, 2, 1),
        2,
      ),
      Segment(
        PowerState.off,
        DateTime(2026, 10, 2, 14),
        DateTime(2026, 10, 2, 15, 30),
        3,
      ),
    ];

    test('offBetween clips to the window', () {
      final d = StatusEngine.offBetween(
        outs,
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
      );
      expect(d, const Duration(hours: 2, minutes: 30));
    });

    test('dailyOffHours splits across midnight', () {
      final v = StatusEngine.dailyOffHours(outs, DateTime(2026, 10, 2, 20), 2);
      expect(v, [1.0, 2.5]);
    });
  });

  group('prediction', () {
    // Seven days with a cut every day from 14:00 to 15:00.
    final now = DateTime(2026, 10, 8, 9, 0);
    final reports = <PowerReport>[];
    for (var d = 7; d >= 1; d--) {
      final day = DateTime(2026, 10, 8).subtract(Duration(days: d));
      reports
        ..add(r('a', true, day.add(const Duration(hours: 8))))
        ..add(r('a', false, day.add(const Duration(hours: 14))))
        ..add(r('b', false, day.add(const Duration(hours: 14, minutes: 2))))
        ..add(r('a', true, day.add(const Duration(hours: 15))));
    }
    reports.add(r('a', true, DateTime(2026, 10, 8, 8)));

    final segs = StatusEngine.segments(reports, now);
    final outs = StatusEngine.outages(segs);
    final first = reports
        .map((e) => e.at)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final matrix = StatusEngine.probabilityMatrix(outs, now, first);
    final status = StatusEngine.current(reports, segs, now);

    test('learns the daily 2 pm cut', () {
      final preds = StatusEngine.predict(
        matrix: matrix,
        now: now,
        schedule: const [],
        status: status,
        outages: outs,
      );
      expect(preds, isNotEmpty);
      expect(preds.first.start, DateTime(2026, 10, 8, 14));
      expect(preds.first.end, DateTime(2026, 10, 8, 15));
      expect(preds.first.probability, greaterThan(0.8));
    });

    test('official schedule wins over a clashing learned window', () {
      final preds = StatusEngine.predict(
        matrix: matrix,
        now: now,
        schedule: const [ScheduleSlot(127, 14 * 60 + 30, 60)],
        status: status,
        outages: outs,
      );
      final today = preds.where((p) => p.start.day == 8).toList();
      expect(today, hasLength(1));
      expect(today.single.fromSchedule, isTrue);
    });

    test('no data, no prediction', () {
      final m = StatusEngine.probabilityMatrix(const [], now, null);
      expect(
        StatusEngine.predict(
          matrix: m,
          now: now,
          schedule: const [],
          status: AreaStatus.unknown,
          outages: const [],
        ),
        isEmpty,
      );
      expect(StatusEngine.observedDays(now, null), 0);
    });

    test('restore estimate uses the typical outage length', () {
      final offNow = DateTime(2026, 10, 8, 14, 10);
      final rs = [...reports, r('c', false, DateTime(2026, 10, 8, 14))];
      final s2 = StatusEngine.segments(rs, offNow);
      final st = StatusEngine.current(rs, s2, offNow);
      expect(st.state, PowerState.off);
      final eta = StatusEngine.predictRestore(
        st,
        StatusEngine.outages(s2),
        matrix,
        offNow,
      );
      expect(eta, DateTime(2026, 10, 8, 15));
    });
  });

  group('demo repository', () {
    test('produces a believable history', () async {
      final repo = DemoRepository();
      final reports = await repo
          .watchReports('ttsgx8', const Duration(days: 14))
          .first;
      expect(reports, isNotEmpty);
      final now = DateTime.now();
      final outs = StatusEngine.outages(StatusEngine.segments(reports, now));
      expect(outs.length, greaterThan(10));
    });

    test('own reports show up', () async {
      final repo = DemoRepository();
      const area = SavedArea(
        id: 'ttsgx8',
        label: '',
        emoji: '🏠',
        place: 'X',
        city: 'Y',
        lat: 0,
        lng: 0,
      );
      final stream = repo.watchReports(area.id, const Duration(days: 1));
      final seen = <int>[];
      final sub = stream.listen(
        (l) => seen.add(l.where((r) => r.uid == 'me').length),
      );
      await Future<void>.delayed(Duration.zero);
      await repo.submitReport(
        area: area,
        on: false,
        issue: PowerIssue.none,
        changesState: true,
        points: 10,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.last, 1);
    });
  });
}

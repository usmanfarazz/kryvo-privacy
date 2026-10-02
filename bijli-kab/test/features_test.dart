import 'package:bijli_kab/services/app_lock.dart';
import 'package:bijli_kab/services/challenges.dart';
import 'package:bijli_kab/services/power_math.dart';
import 'package:bijli_kab/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guess game', () {
    test('closer guesses earn more', () {
      expect(AppState.guessPoints(0), 30);
      expect(AppState.guessPoints(10), 30);
      expect(AppState.guessPoints(15), 20);
      expect(AppState.guessPoints(40), 10);
      expect(AppState.guessPoints(200), 2);
    });
  });

  group('weekly challenges', () {
    test('three different kinds each week', () {
      for (var w = 0; w < 30; w++) {
        final list = challengesFor(
          DateTime(2026, 1, 5).add(Duration(days: 7 * w)),
        );
        expect(list, hasLength(3));
        expect(list.map((c) => c.kind).toSet(), hasLength(3));
      }
    });

    test('same challenges all week, different next week', () {
      final mon = DateTime(2026, 10, 5);
      final ids = challengesFor(mon).map((c) => c.id).toList();
      expect(
        challengesFor(
          mon.add(const Duration(days: 6, hours: 23)),
        ).map((c) => c.id),
        ids,
      );
      expect(weekKey(mon), weekKey(DateTime(2026, 10, 11, 22)));
      expect(weekKey(mon), isNot(weekKey(DateTime(2026, 10, 12))));
    });

    test('weeks start on Monday', () {
      expect(weekStart(DateTime(2026, 10, 8, 15)), DateTime(2026, 10, 5));
      expect(weekStart(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });
  });

  group('UPS maths', () {
    test('150 Ah 12 V lead-acid at 200 W', () {
      final h = upsBackupHours(
        ah: 150,
        volts: 12,
        lithium: false,
        health: 1,
        watts: 200,
      );
      expect(h, closeTo(150 * 12 * 0.5 * 0.85 / 200, 1e-9));
    });

    test('lithium lasts longer than lead-acid', () {
      double h(bool li) => upsBackupHours(
        ah: 100,
        volts: 12,
        lithium: li,
        health: 0.9,
        watts: 150,
      );
      expect(h(true), greaterThan(h(false)));
    });

    test('no load means no estimate', () {
      expect(
        upsBackupHours(ah: 100, volts: 12, lithium: true, health: 1, watts: 0),
        0,
      );
    });

    test('defaults are used when tools were never opened', () {
      expect(upsHoursFromPrefs({}), greaterThan(0));
    });
  });

  group('App Lock', () {
    test('PIN is salted and hashed', () {
      final a = AppLock.newSalt(), b = AppLock.newSalt();
      expect(a, isNot(b));
      expect(AppLock.hash('1234', a), AppLock.hash('1234', a));
      expect(AppLock.hash('1234', a), isNot(AppLock.hash('1234', b)));
      expect(AppLock.hash('1234', a), isNot(contains('1234')));
    });
  });
}

import 'dart:math';

import '../models/models.dart';

/// Turns raw neighbour reports into a timeline, a current status, stats and
/// predictions. Pure functions only, so all of it is unit tested.
class StatusEngine {
  /// Reports that land within this window of a state change are counted as
  /// votes on that change; a lone wrong tap is out-voted.
  static const voteWindow = Duration(minutes: 15);

  /// Nobody reports "light aayi" at 4 am. An outage longer than this with no
  /// further reports is treated as "don't know" after this point.
  static const maxOutage = Duration(hours: 12);

  /// Builds the state timeline from [reports] (any order) up to [now].
  static List<Segment> segments(List<PowerReport> reports, DateTime now) {
    final rs = [...reports]..sort((a, b) => a.at.compareTo(b.at));
    final out = <Segment>[];
    if (rs.isEmpty) return out;

    var state = PowerState.unknown;
    var start = rs.first.at;
    var confirmers = <String>{};

    void close(DateTime end) {
      if (end.isAfter(start)) {
        out.add(Segment(state, start, end, confirmers.length));
      }
    }

    for (var i = 0; i < rs.length; i++) {
      final r = rs[i];
      if (r.at.isAfter(now)) break;
      // An outage that ran past maxOutage without news becomes unknown.
      if (state == PowerState.off && r.at.difference(start) > maxOutage) {
        close(start.add(maxOutage));
        state = PowerState.unknown;
        start = start.add(maxOutage);
        confirmers = {};
      }
      final wanted = r.on ? PowerState.on : PowerState.off;
      if (wanted == state) {
        confirmers.add(r.uid);
        continue;
      }
      // Majority of distinct people (their latest vote) in the window.
      final latest = <String, bool>{};
      for (var j = i; j < rs.length; j++) {
        if (rs[j].at.difference(r.at) > voteWindow || rs[j].at.isAfter(now)) {
          break;
        }
        latest[rs[j].uid] = rs[j].on;
      }
      final yes = latest.values.where((v) => v == r.on).length;
      final no = latest.length - yes;
      if (yes >= no) {
        close(r.at);
        state = wanted;
        start = r.at;
        confirmers = {r.uid};
      }
    }
    if (state == PowerState.off && now.difference(start) > maxOutage) {
      close(start.add(maxOutage));
      state = PowerState.unknown;
      start = start.add(maxOutage);
      confirmers = {};
    }
    close(now);
    return out;
  }

  static List<Segment> outages(List<Segment> segs) =>
      segs.where((s) => s.state == PowerState.off).toList();

  /// What is happening right now.
  static AreaStatus current(
    List<PowerReport> reports,
    List<Segment> segs,
    DateTime now,
  ) {
    if (segs.isEmpty) return AreaStatus.unknown;
    final last = segs.last;
    final recent = reports.where((r) => !r.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final lastReport = recent.isEmpty ? null : recent.last.at;
    if (last.state == PowerState.unknown) {
      return AreaStatus(state: PowerState.unknown, lastReport: lastReport);
    }
    final ageH = lastReport == null
        ? 99.0
        : now.difference(lastReport).inMinutes / 60.0;
    final recency = ageH <= 1 ? 1.0 : max(0.3, 1 - (ageH - 1) / 16);
    final people = min(1.0, 0.45 + last.reporters * 0.2);
    final issue = recent.reversed
        .where((r) => !r.at.isBefore(last.start) && r.issue != PowerIssue.none)
        .map((r) => r.issue)
        .firstOrNull;
    return AreaStatus(
      state: last.state,
      since: last.start,
      confidence: (recency * people).clamp(0.0, 1.0),
      reporters: last.reporters,
      lastReport: lastReport,
      issue: issue ?? PowerIssue.none,
    );
  }

  // ---------------------------------------------------------------- stats

  /// Total outage time that falls inside [from, to).
  static Duration offBetween(
    List<Segment> outages,
    DateTime from,
    DateTime to,
  ) {
    var total = Duration.zero;
    for (final o in outages) {
      final s = o.start.isBefore(from) ? from : o.start;
      final e = o.end.isAfter(to) ? to : o.end;
      if (e.isAfter(s)) total += e.difference(s);
    }
    return total;
  }

  /// Hours without power for each of the last [days] days (oldest first).
  static List<double> dailyOffHours(
    List<Segment> outages,
    DateTime now,
    int days,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      final e = d.add(const Duration(days: 1));
      return offBetween(outages, d, e.isAfter(now) ? now : e).inMinutes / 60;
    });
  }

  /// Minutes without power per hour of day, averaged over [days].
  static List<double> hourOfDayProfile(
    List<Segment> outages,
    DateTime now,
    int days,
  ) {
    final res = List<double>.filled(24, 0);
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d < days; d++) {
      final day = today.subtract(Duration(days: d));
      for (var h = 0; h < 24; h++) {
        final s = day.add(Duration(hours: h));
        if (s.isAfter(now)) continue;
        res[h] += offBetween(
          outages,
          s,
          s.add(const Duration(hours: 1)),
        ).inMinutes;
      }
    }
    return res.map((m) => days == 0 ? 0.0 : m / days).toList();
  }

  // ----------------------------------------------------------- prediction

  static const _slotsPerDay = 96; // 15-minute slots
  static const _slot = Duration(minutes: 15);

  /// Probability (0..1) of an outage for every weekday × 15-minute slot,
  /// learned from the last [days] days. Index: [weekday-1][slot].
  static List<List<double>> probabilityMatrix(
    List<Segment> outages,
    DateTime now,
    DateTime? firstData, {
    int days = 28,
  }) {
    final daily = List<double>.filled(_slotsPerDay, 0);
    final weekly = List.generate(
      7,
      (_) => List<double>.filled(_slotsPerDay, 0),
    );
    final weekDays = List<int>.filled(7, 0);
    var observed = 0;
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 1; d <= days; d++) {
      final day = today.subtract(Duration(days: d));
      if (firstData == null ||
          day.add(const Duration(days: 1)).isBefore(firstData)) {
        continue;
      }
      observed++;
      weekDays[day.weekday - 1]++;
      for (var s = 0; s < _slotsPerDay; s++) {
        final from = day.add(_slot * s);
        final off = offBetween(outages, from, from.add(_slot));
        if (off.inMinutes >= 8) {
          daily[s]++;
          weekly[day.weekday - 1][s]++;
        }
      }
    }
    return List.generate(7, (w) {
      return List.generate(_slotsPerDay, (s) {
        if (observed == 0) return 0.0;
        final pd = daily[s] / observed;
        if (weekDays[w] < 2) return pd;
        final pw = weekly[w][s] / weekDays[w];
        return 0.5 * pd + 0.5 * pw;
      });
    });
  }

  /// Days of data behind the predictions.
  static int observedDays(DateTime now, DateTime? firstData, {int days = 28}) {
    if (firstData == null) return 0;
    final n = now.difference(firstData).inHours ~/ 24;
    return min(days, n);
  }

  /// Predicted outages in the next [horizon], merged with the user's
  /// official [schedule] (which wins where both exist).
  static List<PredictedOutage> predict({
    required List<List<double>> matrix,
    required DateTime now,
    required List<ScheduleSlot> schedule,
    required AreaStatus status,
    required List<Segment> outages,
    Duration horizon = const Duration(hours: 24),
    double threshold = 0.5,
  }) {
    final res = <PredictedOutage>[];

    // 1. Official schedule.
    final today = DateTime(now.year, now.month, now.day);
    for (var d = -1; d <= horizon.inDays + 1; d++) {
      final day = today.add(Duration(days: d));
      for (final s in schedule) {
        if (!s.appliesOn(day.weekday)) continue;
        final st = day.add(Duration(minutes: s.startMinute));
        final en = st.add(Duration(minutes: s.durationMinutes));
        if (en.isAfter(now) && st.isBefore(now.add(horizon))) {
          res.add(PredictedOutage(st, en, 0.9, fromSchedule: true));
        }
      }
    }

    // 2. Learned pattern, at 15-minute resolution.
    final slotNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - now.minute % 15,
    );
    DateTime? runStart;
    var runP = <double>[];
    final steps = horizon.inMinutes ~/ 15;
    for (var i = 0; i <= steps; i++) {
      final t = slotNow.add(_slot * i);
      final idx = (t.hour * 60 + t.minute) ~/ 15;
      final p = i == steps ? 0.0 : matrix[t.weekday - 1][idx];
      if (p >= threshold) {
        runStart ??= t;
        runP.add(p);
      } else if (runStart != null) {
        final st = runStart.isBefore(now) ? now : runStart;
        res.add(
          PredictedOutage(st, t, runP.reduce((a, b) => a + b) / runP.length),
        );
        runStart = null;
        runP = [];
      }
    }

    // If the light is already off, the window we're inside is not "next".
    final filtered = res.where((p) {
      if (status.state == PowerState.off && !p.start.isAfter(now)) return false;
      return true;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    // Drop learned windows that overlap a scheduled one.
    final out = <PredictedOutage>[];
    for (final p in filtered) {
      final clash = out.any(
        (q) => p.start.isBefore(q.end) && q.start.isBefore(p.end),
      );
      if (!clash) {
        out.add(p);
      } else if (p.fromSchedule) {
        out.removeWhere(
          (q) => p.start.isBefore(q.end) && q.start.isBefore(p.end),
        );
        out.add(p);
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// When the light is likely to return, if it is off now.
  static DateTime? predictRestore(
    AreaStatus status,
    List<Segment> outages,
    List<List<double>> matrix,
    DateTime now,
  ) {
    if (status.state != PowerState.off || status.since == null) return null;
    final closed =
        outages
            .where(
              (o) => o.end.isBefore(now.subtract(const Duration(minutes: 1))),
            )
            .map((o) => o.duration.inMinutes)
            .where((m) => m >= 10)
            .toList()
          ..sort();
    if (closed.length >= 3) {
      final median = closed[closed.length ~/ 2];
      final eta = status.since!.add(Duration(minutes: median));
      return eta.isAfter(now) ? eta : now.add(const Duration(minutes: 15));
    }
    // Fall back to the end of the learned window we're inside.
    var t = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - now.minute % 15,
    );
    for (var i = 0; i < 48; i++) {
      final idx = (t.hour * 60 + t.minute) ~/ 15;
      if (matrix[t.weekday - 1][idx] < 0.5) return i == 0 ? null : t;
      t = t.add(_slot);
    }
    return null;
  }
}

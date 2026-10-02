import 'package:flutter/material.dart';

import '../l10n/format.dart';
import '../models/models.dart';
import '../theme.dart';

/// A 24-hour strip for one day: green = light, red = cut, grey = no data,
/// striped = predicted cut. A marker shows "now".
class DayTimeline extends StatelessWidget {
  final DateTime day; // midnight
  final List<Segment> segments;
  final List<PredictedOutage> predictions;
  final double height;
  final bool showLabels;
  const DayTimeline({
    super.key,
    required this.day,
    required this.segments,
    this.predictions = const [],
    this.height = 26,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DayPainter(day, segments, predictions, DateTime.now()),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in [0, 6, 12, 18, 24])
                Text(
                  h == 24 ? '12a' : hourLabel(h),
                  style: TextStyle(color: BK.muted, fontSize: 10.5),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DayPainter extends CustomPainter {
  final DateTime day;
  final List<Segment> segs;
  final List<PredictedOutage> preds;
  final DateTime now;
  _DayPainter(this.day, this.segs, this.preds, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final end = day.add(const Duration(days: 1));
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = BK.panel2);

    double x(DateTime t) {
      final f = t.difference(day).inSeconds / 86400;
      return (f.clamp(0.0, 1.0)) * size.width;
    }

    for (final s in segs) {
      if (!s.end.isAfter(day) || !s.start.isBefore(end)) continue;
      final color = switch (s.state) {
        PowerState.on => BK.on.withValues(alpha: 0.75),
        PowerState.off => BK.off,
        PowerState.unknown => BK.line,
      };
      canvas.drawRect(
        Rect.fromLTRB(x(s.start), 0, x(s.end), size.height),
        Paint()..color = color,
      );
    }

    // Predicted cuts: diagonal stripes.
    final stripe = Paint()
      ..color = BK.off.withValues(alpha: 0.55)
      ..strokeWidth = 3;
    for (final p in preds) {
      if (!p.end.isAfter(day) || !p.start.isBefore(end)) continue;
      final l = x(p.start), r = x(p.end);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(l, 0, r, size.height));
      canvas.drawRect(
        Rect.fromLTRB(l, 0, r, size.height),
        Paint()..color = BK.off.withValues(alpha: 0.12),
      );
      for (var sx = l - size.height; sx < r; sx += 9) {
        canvas.drawLine(
          Offset(sx, size.height),
          Offset(sx + size.height, 0),
          stripe,
        );
      }
      canvas.restore();
    }
    canvas.restore();

    if (now.isAfter(day) && now.isBefore(end)) {
      final nx = x(now);
      canvas.drawLine(
        Offset(nx, -3),
        Offset(nx, size.height + 3),
        Paint()
          ..color = BK.txt
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter o) => true;
}

/// Weekday × hour heat map of outage probability.
class OutageHeatmap extends StatelessWidget {
  final List<List<double>> matrix; // [weekday-1][15-min slot]
  const OutageHeatmap({super.key, required this.matrix});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    return Column(
      children: [
        for (var w = 0; w < 7; w++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    dayShort(w + 1),
                    style: TextStyle(
                      color: w + 1 == today ? BK.accent : BK.muted,
                      fontSize: 11,
                      fontWeight: w + 1 == today
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var h = 0; h < 24; h++)
                        Expanded(
                          child: Container(
                            height: 18,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: _cell(_hourP(w, h)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 34),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final h in [0, 6, 12, 18, 23])
                    Text(
                      hourLabel(h),
                      style: TextStyle(color: BK.muted, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _hourP(int w, int h) {
    var s = 0.0;
    for (var q = 0; q < 4; q++) {
      s += matrix[w][h * 4 + q];
    }
    return s / 4;
  }

  Color _cell(double p) {
    if (p <= 0.02) return BK.panel2;
    return Color.lerp(
      BK.warn.withValues(alpha: 0.35),
      BK.off,
      p.clamp(0.0, 1.0),
    )!;
  }
}

/// Simple bar chart: hours without power per day.
class DailyBars extends StatelessWidget {
  final List<double> values; // oldest first
  final DateTime lastDay;
  final double height;
  const DailyBars({
    super.key,
    required this.values,
    required this.lastDay,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text(
                        fmtHours(values[i]),
                        style: TextStyle(
                          color: BK.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 3),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: values[i] / maxV),
                      duration: Duration(milliseconds: 500 + i * 40),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => Container(
                        height: (height - 16) * f + 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [BK.off, BK.warn],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayShort(
                        lastDay
                            .subtract(Duration(days: values.length - 1 - i))
                            .weekday,
                      ).substring(0, 1),
                      style: TextStyle(color: BK.muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

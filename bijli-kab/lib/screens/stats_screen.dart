import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/share_service.dart';
import '../services/status_engine.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/area_switcher.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _days = 7;
  final _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = app.activeLive;
    final area = app.active;
    final now = DateTime.now();
    final from = now.subtract(Duration(days: _days));
    final outages = (l?.outages ?? const <Segment>[])
        .where((o) => o.end.isAfter(from))
        .toList();
    final offH = StatusEngine.offBetween(outages, from, now).inMinutes / 60;
    final longest = outages.fold<Duration>(
      Duration.zero,
      (m, o) => o.duration > m ? o.duration : m,
    );
    final avg = outages.isEmpty
        ? Duration.zero
        : Duration(
            minutes:
                outages.fold<int>(0, (s, o) => s + o.duration.inMinutes) ~/
                outages.length,
          );
    final daily = StatusEngine.dailyOffHours(l?.outages ?? const [], now, 14);
    final profile = StatusEngine.hourOfDayProfile(
      l?.outages ?? const [],
      now,
      _days,
    );
    final pctOn = (100 - offH / (_days * 24) * 100).clamp(0, 100).round();

    return BScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Text(
              tr('Stats'),
              style: TextStyle(
                color: BK.txt,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const AreaSwitcher(),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(tr('7 days'))),
                ButtonSegment(value: 28, label: Text(tr('4 weeks'))),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: _shareKey,
              child: _ShareCard(
                areaName: area?.title ?? '',
                place: area?.subtitle ?? '',
                days: _days,
                offHours: offH,
                cuts: outages.length,
                longest: longest,
                pctOn: pctOn,
              ),
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: tr('Share my stats'),
              icon: Icons.share_rounded,
              onPressed: () async {
                final ok = await ShareService.shareWidget(
                  _shareKey,
                  trf(
                    '{0} hours without light in {1} days in {2} 😩⚡ #BijliKab',
                    [fmtHours(offH), _days, area?.title ?? ''],
                  ),
                );
                if (ok) app.countShare();
              },
            ),
            const SectionTitle('Numbers'),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: StatBlock(
                      fmtHours(offH),
                      tr('without light'),
                      color: BK.off,
                      emoji: '🕯️',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassCard(
                    child: StatBlock(
                      '${outages.length}',
                      tr('power cuts'),
                      emoji: '✂️',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: StatBlock(
                      fmtDurationShort(avg),
                      tr('average cut'),
                      emoji: '⏱️',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassCard(
                    child: StatBlock(
                      fmtDurationShort(longest),
                      tr('longest cut'),
                      color: BK.warn,
                      emoji: '🐢',
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('Last 14 days'),
            GlassCard(
              child: DailyBars(values: daily, lastDay: now),
            ),
            const SectionTitle('Worst hours of the day'),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(8, 20, 18, 10),
              child: SizedBox(height: 180, child: _HourChart(profile: profile)),
            ),
            const SectionTitle('Fun facts'),
            GlassCard(
              child: Column(
                children: [
                  _Fact(
                    '🏏',
                    trf('That\'s {0} full T20 matches', [
                      (offH / 3.5).toStringAsFixed(1),
                    ]),
                  ),
                  _Fact(
                    '🎬',
                    trf('or {0} movies in the dark', [
                      (offH / 2.5).toStringAsFixed(1),
                    ]),
                  ),
                  _Fact(
                    '📱',
                    trf('or charging your phone {0} times', [
                      (offH / 1.5).round(),
                    ]),
                  ),
                  _Fact('💡', trf('Light was on {0}% of the time', [pctOn])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String emoji, text;
  const _Fact(this.emoji, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: BK.txt, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ShareCard extends StatelessWidget {
  final String areaName, place;
  final int days, cuts, pctOn;
  final double offHours;
  final Duration longest;
  const _ShareCard({
    required this.areaName,
    required this.place,
    required this.days,
    required this.offHours,
    required this.cuts,
    required this.longest,
    required this.pctOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Color.lerp(BK.off, Colors.black, 0.25)!,
            const Color(0xFF1A0F2E),
            Color.lerp(BK.accent, Colors.black, 0.35)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFFFD60A),
                size: 26,
              ),
              const SizedBox(width: 4),
              const Text(
                'Bijli Kab?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trf('Last {0} days', [days]),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            fmtHours(offHours),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            tr('without light 😩'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            place.isEmpty ? areaName : place,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _mini('$cuts', tr('cuts')),
              _mini(fmtDurationShort(longest), tr('longest')),
              _mini('$pctOn%', tr('light on')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String v, String l) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    ),
  );
}

class _HourChart extends StatelessWidget {
  final List<double> profile; // minutes off per hour (average per day)
  const _HourChart({required this.profile});

  @override
  Widget build(BuildContext context) {
    final maxY = profile.fold<double>(10, (m, v) => v > m ? v : m) * 1.15;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: BK.line, strokeWidth: 0.8, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: maxY / 3,
              getTitlesWidget: (v, _) => Text(
                '${v.round()}m',
                style: TextStyle(color: BK.muted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  hourLabel(v.round()),
                  style: TextStyle(color: BK.muted, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => BK.panel2,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${hourLabel(s.x.round())}: ${s.y.round()}m',
                  TextStyle(color: BK.txt, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var h = 0; h < 24; h++) FlSpot(h.toDouble(), profile[h]),
            ],
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 3.5,
            gradient: LinearGradient(colors: [BK.warn, BK.off]),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  BK.off.withValues(alpha: 0.35),
                  BK.off.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

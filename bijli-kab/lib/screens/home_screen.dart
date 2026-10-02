import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/labels.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/gamification.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/area_switcher.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/home_extras.dart';
import '../widgets/power_orb.dart';
import '../widgets/report_sheet.dart';
import 'checklist_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onOpenTab;
  const HomeScreen({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final area = app.active;
    final l = app.activeLive;
    final status = l?.status ?? AreaStatus.unknown;
    final now = DateTime.now();

    return BScaffold(
      sparks: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => app.setActive(area?.id ?? ''),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              Row(
                children: [
                  const Expanded(child: AreaSwitcher()),
                  const SizedBox(width: 8),
                  _LevelChip(points: app.totalPoints),
                ],
              ),
              if (!app.repo.isLive) ...[
                const SizedBox(height: 10),
                Pill(
                  tr('Demo mode · simulated neighbours'),
                  color: BK.warn,
                  icon: Icons.science_rounded,
                ),
              ],
              const SizedBox(height: 8),
              _HeroCard(status: status, live: l),
              const SizedBox(height: 16),
              _ReportButtons(status: status),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  tr(
                    'Tap when the light goes or comes back — your whole street gets to know.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BK.muted, fontSize: 12.5),
                ),
              ),
              const GuessResultCard(),
              const GuessCard(),
              const MoodRow(),
              SectionTitle('Today', trailing: _Legend()),
              GlassCard(
                child: Column(
                  children: [
                    DayTimeline(
                      day: DateTime(now.year, now.month, now.day),
                      segments: l?.segments ?? const [],
                      predictions: l?.predictions ?? const [],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            fmtHours(
                              l == null
                                  ? 0
                                  : StatusEngineHelpers.todayOff(l, now),
                            ),
                            tr('without light today'),
                            color: BK.off,
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            '${l == null ? 0 : StatusEngineHelpers.todayCuts(l, now)}',
                            tr('cuts today'),
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            '${app.streak}🔥',
                            tr('day streak'),
                            color: BK.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (l != null && l.predictions.isNotEmpty) ...[
                SectionTitle(
                  'Coming up',
                  trailing: TextButton(
                    onPressed: () => onOpenTab(2),
                    child: Text(tr('See all')),
                  ),
                ),
                for (final p in l.predictions.take(3)) _PredictionTile(p: p),
              ],
              if (l != null &&
                  l.next != null &&
                  l.next!.start.difference(now).inHours < 4 &&
                  status.state == PowerState.on) ...[
                SectionTitle('Before the light goes'),
                GlassCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChecklistScreen()),
                  ),
                  child: Row(
                    children: [
                      const EmojiBox('📝'),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trf('{0} of {1} done', [
                                app.checklist.where((c) => c.done).length,
                                app.checklist.length,
                              ]),
                              style: TextStyle(
                                color: BK.txt,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.checklist
                                  .where((c) => !c.done)
                                  .take(2)
                                  .map((c) => tr(c.text))
                                  .join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: BK.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: BK.muted),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small helpers kept here so the home screen reads simply.
class StatusEngineHelpers {
  static double todayOff(AreaLive l, DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    var m = 0;
    for (final o in l.outages) {
      final s = o.start.isBefore(d) ? d : o.start;
      final e = o.end.isAfter(now) ? now : o.end;
      if (e.isAfter(s)) m += e.difference(s).inMinutes;
    }
    return m / 60;
  }

  static int todayCuts(AreaLive l, DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return l.outages.where((o) => o.end.isAfter(d)).length;
  }
}

class _LevelChip extends StatelessWidget {
  final int points;
  const _LevelChip({required this.points});
  @override
  Widget build(BuildContext context) {
    final lv = levelFor(points);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: BK.accentGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '${lv.emoji} $points',
        style: TextStyle(
          color: BK.onAccent,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AreaStatus status;
  final AreaLive? live;
  const _HeroCard({required this.status, required this.live});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = switch (status.state) {
      PowerState.on => BK.on,
      PowerState.off => BK.off,
      PowerState.unknown => BK.muted,
    };
    final headline = switch (status.state) {
      PowerState.on => tr('LIGHT HAI ⚡'),
      PowerState.off => tr('LIGHT NAHI HAI'),
      PowerState.unknown => tr('Pata nahi 🤔'),
    };
    return GlassCard(
      glow: color,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        children: [
          PowerOrb(state: status.state),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              headline,
              key: ValueKey(headline),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.since == null
                ? tr('No one has reported in the last few hours. Be the first!')
                : trf('for {0} · since {1}', [
                    fmtDuration(now.difference(status.since!)),
                    fmtTime(status.since!),
                  ]),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BK.txt,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (status.state != PowerState.unknown)
            _ConfidenceBar(status: status, color: color),
          if (status.issue != PowerIssue.none) ...[
            const SizedBox(height: 10),
            Pill(
              issueLabel(status.issue),
              color: BK.warn,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          const SizedBox(height: 14),
          _NextInfo(status: status, live: live),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final AreaStatus status;
  final Color color;
  const _ConfidenceBar({required this.status, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = status.confidence;
    final label = c > 0.75
        ? tr('Very sure')
        : c > 0.45
        ? tr('Fairly sure')
        : tr('Not sure yet');
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 16, color: BK.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                trf('{0} neighbours confirmed · {1}', [
                  status.reporters,
                  status.lastReport == null ? '' : fmtAgo(status.lastReport!),
                ]),
                style: TextStyle(color: BK.muted, fontSize: 12.5),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: c,
            minHeight: 7,
            backgroundColor: BK.panel2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _NextInfo extends StatelessWidget {
  final AreaStatus status;
  final AreaLive? live;
  const _NextInfo({required this.status, required this.live});

  @override
  Widget build(BuildContext context) {
    final l = live;
    String title, sub;
    IconData icon;
    Color color;
    if (status.state == PowerState.off) {
      icon = Icons.wb_incandescent_rounded;
      color = BK.on;
      if (l?.restoreEta != null) {
        title = trf('Light expected back ~{0}', [fmtTime(l!.restoreEta!)]);
        sub = fmtIn(l.restoreEta!);
      } else {
        title = tr('Back time unknown');
        sub = tr('We need a few more days of reports to guess.');
      }
    } else {
      icon = Icons.power_off_rounded;
      color = BK.off;
      final n = l?.next;
      if (n != null) {
        title = trf('Next cut ~{0}', [fmtTime(n.start)]);
        sub =
            '${fmtIn(n.start)} · ${trf('about {0}', [fmtDuration(n.duration)])} · '
            '${(n.probability * 100).round()}%';
      } else if ((l?.observedDays ?? 0) < 2) {
        title = tr('Learning your area…');
        sub = tr('Forecasts start after ~2 days of reports.');
      } else {
        title = tr('No cut expected in 24h 🎉');
        sub = tr('Based on the last 4 weeks.');
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BK.panel2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconBox(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: BK.txt,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: BK.muted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportButtons extends StatelessWidget {
  final AreaStatus status;
  const _ReportButtons({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            label: tr('Light Gayi'),
            emoji: '⚡❌',
            color: BK.off,
            highlighted: status.state != PowerState.off,
            onTap: () => _report(context, false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigButton(
            label: tr('Light Aayi'),
            emoji: '⚡✅',
            color: BK.on,
            highlighted: status.state != PowerState.on,
            onTap: () => _report(context, true),
          ),
        ),
      ],
    );
  }

  Future<void> _report(BuildContext context, bool on) async {
    final app = context.read<AppState>();
    if (app.haptics) HapticFeedback.mediumImpact();
    await showReportSheet(context, on);
  }
}

class _BigButton extends StatefulWidget {
  final String label;
  final String emoji;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;
  const _BigButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.highlighted,
    required this.onTap,
  });
  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: widget.highlighted
                ? LinearGradient(
                    colors: [c, Color.lerp(c, Colors.black, 0.25)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.highlighted ? null : BK.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: c.withValues(alpha: widget.highlighted ? 0 : 0.5),
            ),
            boxShadow: widget.highlighted
                ? [
                    BoxShadow(
                      color: c.withValues(alpha: 0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.highlighted ? Colors.white : c,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(tr(t), style: TextStyle(color: BK.muted, fontSize: 11)),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(BK.on, 'On'),
        dot(BK.off, 'Off'),
        dot(BK.off.withValues(alpha: 0.4), 'Expected'),
      ],
    );
  }
}

class _PredictionTile extends StatelessWidget {
  final PredictedOutage p;
  const _PredictionTile({required this.p});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: BK.off.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    fmtDay(p.start),
                    style: TextStyle(
                      color: BK.off,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    fmtTime(p.start).split(' ').first,
                    style: TextStyle(
                      color: BK.txt,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fmtTime(p.start)} – ${fmtTime(p.end)}',
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.fromSchedule
                        ? tr('From the official schedule')
                        : trf('{0} chance · learned from your area', [
                            '${(p.probability * 100).round()}%',
                          ]),
                    style: TextStyle(color: BK.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              fmtIn(p.start),
              style: TextStyle(
                color: BK.accent,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

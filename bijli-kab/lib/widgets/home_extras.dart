import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// "Andaza Lagao": guess when the light comes back (shown while it's off).
class GuessCard extends StatelessWidget {
  const GuessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.activeLive?.status;
    if (s == null || s.state != PowerState.off || s.since == null) {
      return const SizedBox.shrink();
    }
    final g = app.guess;
    final mine =
        g != null && g.areaId == app.active?.id && g.outageStart == s.since
        ? g
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        glow: const Color(0xFFA855F7),
        gradient: LinearGradient(
          colors: [const Color(0xFFA855F7).withValues(alpha: 0.22), BK.panel],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Andaza Lagao!'),
                        style: TextStyle(
                          color: BK.txt,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        mine == null
                            ? tr(
                                'Guess when the light comes back. Closer guess = more points!',
                              )
                            : trf(
                                'Your guess: {0}. Points when the light comes back.',
                                [fmtTime(mine.at)],
                              ),
                        style: TextStyle(color: BK.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in [30, 60, 90, 120, 180])
                  _chip(context, s.since!.add(Duration(minutes: m)), mine),
                ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(tr('Other time')),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        DateTime.now().add(const Duration(hours: 1)),
                      ),
                    );
                    if (t == null || !context.mounted) return;
                    final now = DateTime.now();
                    var at = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      t.hour,
                      t.minute,
                    );
                    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
                    await _guess(context, at);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, DateTime at, Guess? mine) {
    if (at.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      return const SizedBox.shrink();
    }
    final selected = mine != null && mine.at == at;
    return ChoiceChip(
      label: Text(fmtTime(at)),
      selected: selected,
      onSelected: (_) => _guess(context, at),
    );
  }

  Future<void> _guess(BuildContext context, DateTime at) async {
    final app = context.read<AppState>();
    if (app.haptics) HapticFeedback.selectionClick();
    if (await app.makeGuess(at) && context.mounted) {
      toast(context, trf('Guess saved: {0} 🎯', [fmtTime(at)]));
    }
  }
}

/// Result of the last guess, shown once.
class GuessResultCard extends StatelessWidget {
  const GuessResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = app.guessResult;
    if (r == null) return const SizedBox.shrink();
    final good = r.points >= 20;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        glow: good ? BK.on : BK.warn,
        child: Row(
          children: [
            Text(
              r.tooLate ? '⏱️' : (good ? '🏆' : '🎯'),
              style: const TextStyle(fontSize: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trf('Light came back at {0}', [fmtTime(r.actual)]),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.tooLate
                        ? tr(
                            'Your guess came too late to count (less than 10 min before).',
                          )
                        : r.minutesOff == 0
                        ? trf('Exactly right! +{0} points', [r.points])
                        : trf('You were {0} off. +{1} points', [
                            fmtDuration(Duration(minutes: r.minutesOff)),
                            r.points,
                          ]),
                    style: TextStyle(color: BK.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: BK.muted),
              onPressed: app.clearGuessResult,
            ),
          ],
        ),
      ),
    );
  }
}

/// "How is your area feeling?" — one emoji per person, counts for 3 hours.
class MoodRow extends StatelessWidget {
  const MoodRow({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mine = app.myMoods[app.active?.id];
    final total = app.moods.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Area mood'),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                Text(
                  trf('{0} people · last 3h', [total]),
                  style: TextStyle(color: BK.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final e in kMoods)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (app.haptics) HapticFeedback.lightImpact();
                        app.setMood(e);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: mine == e
                              ? BK.accent.withValues(alpha: 0.2)
                              : BK.panel2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: mine == e ? BK.accent : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            AnimatedScale(
                              scale: mine == e ? 1.25 : 1,
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${app.moods[e] ?? 0}',
                              style: TextStyle(
                                color: BK.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen confetti when the light comes back.
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const CelebrationOverlay({super.key, required this.onDone});
  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward().whenComplete(widget.onDone);
  final _bits = List.generate(90, (i) {
    final r = Random(i * 31 + 7);
    return (
      r.nextDouble(),
      r.nextDouble() * 0.4,
      0.6 + r.nextDouble() * 0.9,
      r.nextDouble() * 6.3,
      [
        const Color(0xFFFFD60A),
        const Color(0xFF22E58B),
        const Color(0xFFFF2E93),
        const Color(0xFF00D1C1),
        const Color(0xFFFF8A00),
        const Color(0xFFA78BFA),
      ][r.nextInt(6)],
    );
  });

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ConfettiPainter(t, _bits)),
                  ),
                  Center(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _c,
                        curve: const Interval(
                          0,
                          0.35,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 96)),
                          const SizedBox(height: 8),
                          Material(
                            type: MaterialType.transparency,
                            child: Text(
                              tr('Light aa gayi! 🎉'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF22E58B),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<(double, double, double, double, Color)> bits;
  _ConfettiPainter(this.t, this.bits);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, delay, speed, spin, color) in bits) {
      final p = ((t - delay) * speed * 1.6).clamp(0.0, 2.0);
      if (p <= 0) continue;
      final dx = x * size.width + sin(p * 6 + spin) * 30;
      final dy = -20 + p * size.height * 0.9;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(spin + p * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -3, 10, 6),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

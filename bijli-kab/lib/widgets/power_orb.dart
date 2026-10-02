import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// The big animated status light on the home screen.
///
/// ON: glowing core, rotating rays and pulse rings.
/// OFF: dim red core that slowly breathes, with a flicker.
/// UNKNOWN: calm grey.
class PowerOrb extends StatefulWidget {
  final PowerState state;
  final double size;
  const PowerOrb({super.key, required this.state, this.size = 210});

  @override
  State<PowerOrb> createState() => _PowerOrbState();
}

class _PowerOrbState extends State<PowerOrb> with TickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.state) {
    PowerState.on => BK.on,
    PowerState.off => BK.off,
    PowerState.unknown => BK.muted,
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (_, _) {
          final flicker = widget.state == PowerState.off
              ? (sin(_pulse.value * 2 * pi * 3) > 0.92 ? 0.6 : 1.0)
              : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(s, s),
                painter: _OrbPainter(
                  state: widget.state,
                  color: _color,
                  spin: _spin.value,
                  pulse: _pulse.value,
                  dark: BK.dark,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Opacity(
                  key: ValueKey(widget.state),
                  opacity: flicker,
                  child: Icon(
                    switch (widget.state) {
                      PowerState.on => Icons.lightbulb_rounded,
                      PowerState.off => Icons.power_off_rounded,
                      PowerState.unknown => Icons.question_mark_rounded,
                    },
                    size: s * 0.3,
                    color: widget.state == PowerState.on
                        ? const Color(0xFFFFF6C8)
                        : Colors.white.withValues(alpha: 0.9),
                    shadows: [Shadow(color: _color, blurRadius: 24)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final PowerState state;
  final Color color;
  final double spin, pulse;
  final bool dark;
  _OrbPainter({
    required this.state,
    required this.color,
    required this.spin,
    required this.pulse,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.28;
    final on = state == PowerState.on;

    // Pulse rings.
    final rings = on ? 3 : (state == PowerState.off ? 2 : 1);
    for (var i = 0; i < rings; i++) {
      final t = (pulse + i / rings) % 1.0;
      final rr = r + t * size.width * 0.22;
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = color.withValues(alpha: (1 - t) * (on ? 0.45 : 0.25)),
      );
    }

    // Rays.
    if (on) {
      final ray = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;
      for (var i = 0; i < 12; i++) {
        final a = spin * 2 * pi + i * pi / 6;
        final len = 10.0 + 8 * sin(pulse * 2 * pi + i);
        final p1 = c + Offset(cos(a), sin(a)) * (r + 16);
        final p2 = c + Offset(cos(a), sin(a)) * (r + 16 + len);
        ray.color = color.withValues(alpha: 0.55);
        canvas.drawLine(p1, p2, ray);
      }
    }

    // Glow.
    final breathe = state == PowerState.off
        ? 0.75 + 0.25 * sin(pulse * 2 * pi)
        : 1.0;
    canvas.drawCircle(
      c,
      r * 1.5,
      Paint()
        ..color = color.withValues(alpha: (on ? 0.35 : 0.22) * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
    );

    // Core.
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: on
              ? [
                  Color.lerp(color, Colors.white, 0.55)!,
                  color,
                  Color.lerp(color, Colors.black, 0.35)!,
                ]
              : [
                  Color.lerp(color, Colors.black, 0.15)!,
                  Color.lerp(color, Colors.black, 0.45)!,
                  Color.lerp(color, Colors.black, 0.7)!,
                ],
          stops: const [0, 0.6, 1],
          center: const Alignment(-0.3, -0.35),
        ).createShader(rect),
    );
    // Rim highlight.
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter o) => true;
}

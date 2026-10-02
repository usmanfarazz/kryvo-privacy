import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Rounded panel with a soft border and optional glow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double radius;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.glow,
    this.onTap,
    this.gradient,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? BK.panel : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glow?.withValues(alpha: 0.45) ?? BK.line),
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: BK.dark ? 0.22 : 0.18),
              blurRadius: 28,
              spreadRadius: -4,
            )
          else if (!BK.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: BK.accentGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr(text).toUpperCase(),
            style: TextStyle(
              color: BK.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Full-width button with the accent gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: BK.accentGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: BK.accent.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: busy ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: BK.onAccent,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: BK.onAccent),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BK.onAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Screen scaffold with the themed gradient and floating sparks.
class BScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floating;
  final bool sparks;
  const BScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floating,
    this.sparks = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: BK.backgroundGradient),
      child: Stack(
        children: [
          if (sparks) const Positioned.fill(child: SparkField()),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: title == null
                ? null
                : AppBar(title: Text(tr(title!)), actions: actions),
            body: body,
            floatingActionButton: floating,
          ),
        ],
      ),
    );
  }
}

/// Slowly drifting sparks in the background.
class SparkField extends StatefulWidget {
  const SparkField({super.key});
  @override
  State<SparkField> createState() => _SparkFieldState();
}

class _SparkFieldState extends State<SparkField>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();
  final _seeds = List.generate(
    22,
    (i) => (
      Random(i).nextDouble(),
      Random(i * 7 + 3).nextDouble(),
      Random(i * 13).nextDouble(),
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) =>
          CustomPaint(painter: _SparkPainter(_c.value, _seeds, BK.accent)),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  final double t;
  final List<(double, double, double)> seeds;
  final Color color;
  _SparkPainter(this.t, this.seeds, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, s) in seeds) {
      final dy = (y - t * (0.3 + s * 0.5)) % 1.0;
      final dx = x + sin((t * 2 * pi) + s * 10) * 0.02;
      final r = 1.0 + s * 2.2;
      final a = (0.08 + 0.18 * s) * (1 - (dy - 0.5).abs());
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        r,
        Paint()
          ..color = color.withValues(alpha: a.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.color != color;
}

/// Little icon in a tinted rounded square.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconBox(this.icon, {super.key, this.color, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final c = color ?? BK.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: c, size: size * 0.52),
    );
  }
}

class EmojiBox extends StatelessWidget {
  final String emoji;
  final double size;
  final Color? color;
  const EmojiBox(this.emoji, {super.key, this.size = 44, this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: (color ?? BK.accent).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

/// Settings-style row.
class BTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  const BTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        children: [
          IconBox(icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  style: TextStyle(
                    color: BK.txt,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: BK.muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: BK.muted),
        ],
      ),
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Big number with a label underneath.
class StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final String? emoji;
  const StatBlock(this.value, this.label, {super.key, this.color, this.emoji});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 20)),
      Text(
        value,
        style: TextStyle(
          color: color ?? BK.txt,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: BK.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

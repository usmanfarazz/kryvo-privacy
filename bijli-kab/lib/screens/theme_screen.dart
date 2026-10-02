import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Grid of theme previews.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return BScaffold(
      title: 'Themes',
      body: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
        children: [
          for (final p in BK.palettes)
            _ThemeCard(
              p: p,
              selected: app.themeId == p.id,
              onTap: () {
                if (app.haptics) HapticFeedback.selectionClick();
                app.setTheme(p.id);
              },
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final BPalette p;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard({
    required this.p,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? p.accent : BK.line,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.bg2, p.bg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini preview of the home screen.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: p.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.on,
                            boxShadow: [
                              BoxShadow(
                                color: p.on.withValues(alpha: 0.6),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lightbulb_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LIGHT HAI',
                          style: TextStyle(
                            color: p.on,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(p.off),
                            const SizedBox(width: 6),
                            _bar(p.on),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr(p.name),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.txt,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: p.accent,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final c in [p.accent, p.accent2, p.on, p.off])
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(Color c) => Container(
    width: 34,
    height: 14,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
  );
}

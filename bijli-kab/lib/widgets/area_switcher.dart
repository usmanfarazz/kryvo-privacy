import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../screens/area_picker_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// "🏠 Ghar · Gulberg ▾" — switch between followed areas.
class AreaSwitcher extends StatelessWidget {
  const AreaSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final a = app.active;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showAreaSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Text(a?.emoji ?? '📍', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          a?.title ?? tr('Choose area'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BK.txt,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: BK.muted),
                    ],
                  ),
                  if (a != null && a.subtitle.isNotEmpty)
                    Text(
                      a.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: BK.muted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAreaSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final app = ctx.watch<AppState>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Your areas'),
                style: TextStyle(
                  color: BK.txt,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final a in app.areas)
                _AreaRow(a: a, selected: a.id == app.active?.id),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final area = await Navigator.push<SavedArea>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AreaPickerScreen(),
                      ),
                    );
                    if (area != null && context.mounted) {
                      await context.read<AppState>().addArea(area);
                    }
                  },
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text(tr('Add another area')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AreaRow extends StatelessWidget {
  final SavedArea a;
  final bool selected;
  const _AreaRow({required this.a, required this.selected});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final isPrimary = app.primary?.id == a.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? BK.accent.withValues(alpha: 0.12) : BK.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? BK.accent : BK.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: () {
            app.setActive(a.id);
            Navigator.pop(context);
          },
          leading: Text(a.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(
            a.title,
            style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            isPrimary ? '${a.subtitle} · ${tr('Alerts & widget')}' : a.subtitle,
            style: TextStyle(color: BK.muted, fontSize: 12),
          ),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: BK.accent)
              : null,
        ),
      ),
    );
  }
}

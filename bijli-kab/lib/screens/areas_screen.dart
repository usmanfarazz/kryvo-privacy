import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'area_picker_screen.dart';

/// Followed areas: rename, make primary, remove, add.
class AreasScreen extends StatelessWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return BScaffold(
      title: 'My areas',
      floating: FloatingActionButton.extended(
        backgroundColor: BK.accent,
        foregroundColor: BK.onAccent,
        onPressed: () async {
          final a = await Navigator.push<SavedArea>(
            context,
            MaterialPageRoute(builder: (_) => const AreaPickerScreen()),
          );
          if (a != null) await app.addArea(a, makeActive: false);
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(tr('Add area')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Text(
            tr(
              'Follow your home, office, school or family. The first area (★) gets alerts and the home-screen widget.',
            ),
            style: TextStyle(color: BK.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final (i, a) in app.areas.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                glow: i == 0 ? BK.accent : null,
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    EmojiBox(a.emoji, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BK.txt,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (i == 0) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.star_rounded,
                                  color: BK.accent,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            a.subtitle,
                            style: TextStyle(color: BK.muted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          _StatusLine(id: a.id),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: BK.muted),
                      color: BK.panel,
                      onSelected: (v) async {
                        switch (v) {
                          case 'primary':
                            await app.makePrimary(a.id);
                          case 'rename':
                            if (context.mounted) await _rename(context, a);
                          case 'remove':
                            if (app.areas.length == 1) {
                              if (context.mounted) {
                                toast(
                                  context,
                                  tr('You need at least one area.'),
                                );
                              }
                            } else {
                              await app.removeArea(a.id);
                            }
                        }
                      },
                      itemBuilder: (_) => [
                        if (i != 0)
                          PopupMenuItem(
                            value: 'primary',
                            child: Text(tr('Make main area (★)')),
                          ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(tr('Rename')),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            tr('Remove'),
                            style: TextStyle(color: BK.off),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, SavedArea a) async {
    final c = TextEditingController(text: a.label);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Rename')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    c.dispose();
    if (name != null && context.mounted) {
      await context.read<AppState>().updateArea(a.copyWith(label: name));
    }
  }
}

class _StatusLine extends StatelessWidget {
  final String id;
  const _StatusLine({required this.id});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().live[id];
    if (l == null) {
      return Text(
        tr('Open it to see the status'),
        style: TextStyle(color: BK.muted, fontSize: 12),
      );
    }
    final s = l.status;
    final c = s.state == PowerState.on
        ? BK.on
        : s.state == PowerState.off
        ? BK.off
        : BK.muted;
    return Text(
      switch (s.state) {
            PowerState.on => tr('Light is ON'),
            PowerState.off => tr('Light is OFF'),
            PowerState.unknown => tr('No recent reports'),
          } +
          (s.since != null
              ? ' · ${trf('for {0}', [fmtDuration(DateTime.now().difference(s.since!))])}'
              : ''),
      style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12.5),
    );
  }
}

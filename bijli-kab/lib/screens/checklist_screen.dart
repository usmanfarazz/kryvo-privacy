import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Things to do before the light goes, with a reminder.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});
  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _new = TextEditingController();

  @override
  void dispose() {
    _new.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final done = app.checklist.where((c) => c.done).length;
    final total = app.checklist.length;
    final next = app.live[app.primary?.id]?.next;

    return BScaffold(
      title: 'Before the light goes',
      actions: [
        IconButton(
          tooltip: tr('Untick all'),
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: app.resetChecklist,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: done == total && total > 0 ? BK.on : null,
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        strokeWidth: 7,
                        backgroundColor: BK.panel2,
                        valueColor: AlwaysStoppedAnimation(BK.on),
                      ),
                      Text(
                        '$done/$total',
                        style: TextStyle(
                          color: BK.txt,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done == total && total > 0
                            ? tr('All set! Let it go 😎')
                            : tr('Get ready for the cut'),
                        style: TextStyle(
                          color: BK.txt,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next == null
                            ? tr('No cut expected soon')
                            : trf('Next cut ~{0} ({1})', [
                                fmtTime(next.start),
                                fmtIn(next.start),
                              ]),
                        style: TextStyle(color: BK.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr('Remind me 30 min before'),
                  style: TextStyle(color: BK.txt, fontWeight: FontWeight.w700),
                ),
                value: app.checklistReminder,
                onChanged: (v) => app.setAlerts(checklistReminder: v),
              ),
            ),
          ),
          const SectionTitle('Checklist'),
          for (final (i, c) in app.checklist.indexed)
            Dismissible(
              key: ValueKey('${c.text}$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: BK.off.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.delete_rounded, color: BK.off),
              ),
              onDismissed: (_) {
                app.checklist.removeAt(i);
                app.saveChecklist();
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  radius: 18,
                  child: Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      value: c.done,
                      activeColor: BK.on,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        if (app.haptics) HapticFeedback.selectionClick();
                        c.done = v ?? false;
                        app.saveChecklist();
                      },
                      title: Text(
                        tr(c.text),
                        style: TextStyle(
                          color: c.done ? BK.muted : BK.txt,
                          decoration: c.done
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _new,
                  decoration: InputDecoration(
                    hintText: tr('Add your own item…'),
                  ),
                  onSubmitted: (_) => _add(app),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _add(app),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _add(AppState app) {
    final t = _new.text.trim();
    if (t.isEmpty) return;
    app.checklist.add(ChecklistItem(t));
    app.saveChecklist();
    _new.clear();
  }
}

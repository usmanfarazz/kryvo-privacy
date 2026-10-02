import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/labels.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Confirm a report, optionally with a detail, then celebrate.
Future<void> showReportSheet(BuildContext context, bool on) async {
  final app = context.read<AppState>();
  final area = app.active;
  if (area == null) return;
  final outcome = await showModalBottomSheet<ReportOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(on: on, area: area),
  );
  if (outcome == null || !context.mounted) return;
  if (!outcome.ok) {
    if (outcome.wait != null) {
      toast(
        context,
        trf('Thanks! You can report again in {0}', [
          fmtDuration(outcome.wait!),
        ]),
      );
    }
    return;
  }
  if (app.haptics) HapticFeedback.heavyImpact();
  await showDialog(
    context: context,
    builder: (_) => _Celebration(outcome: outcome, on: on),
  );
}

class _ReportSheet extends StatefulWidget {
  final bool on;
  final SavedArea area;
  const _ReportSheet({required this.on, required this.area});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  PowerIssue _issue = PowerIssue.none;
  bool _busy = false;

  List<PowerIssue> get _options => widget.on
      ? [PowerIssue.none, PowerIssue.lowVoltage, PowerIssue.tripping]
      : [
          PowerIssue.none,
          PowerIssue.scheduled,
          PowerIssue.transformer,
          PowerIssue.wireFault,
          PowerIssue.tripping,
        ];

  @override
  Widget build(BuildContext context) {
    final c = widget.on ? BK.on : BK.off;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: BK.line,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.on ? '💡✅' : '💡❌',
              style: const TextStyle(fontSize: 44),
            ),
            const SizedBox(height: 8),
            Text(
              widget.on ? tr('Light is back?') : tr('Light gone?'),
              style: TextStyle(
                color: c,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trf('in {0}', ['${widget.area.emoji} ${widget.area.title}']),
              style: TextStyle(color: BK.muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                tr('Add a detail (optional, +5 points)'),
                style: TextStyle(
                  color: BK.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in _options)
                  ChoiceChip(
                    label: Text('${issueEmoji(i)}  ${issueLabel(i)}'),
                    selected: _issue == i,
                    onSelected: (_) => setState(() => _issue = i),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final r = await context.read<AppState>().report(
                          widget.on,
                          _issue,
                        );
                        if (context.mounted) Navigator.pop(context, r);
                      },
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.on
                            ? tr('Yes, light aayi!')
                            : tr('Yes, light gayi!'),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Cancel'), style: TextStyle(color: BK.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Celebration extends StatefulWidget {
  final ReportOutcome outcome;
  final bool on;
  const _Celebration({required this.outcome, required this.on});
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
              child: Text(
                o.first ? '📢' : '🙌',
                style: const TextStyle(fontSize: 64),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              o.first ? tr('Pehla Khabri!') : tr('Shukriya!'),
              style: TextStyle(
                color: BK.txt,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              o.first
                  ? tr(
                      'You were the first to tell your area. Neighbours are being updated.',
                    )
                  : tr('Your report makes the forecast better for everyone.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: BK.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _c,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: BK.accentGradient,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '+${o.points} ${tr('points')}',
                  style: TextStyle(
                    color: BK.onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (o.levelUp != null) ...[
              const SizedBox(height: 14),
              Text(
                trf('Level up! You are now {0} {1}', [
                  o.levelUp!.emoji,
                  tr(o.levelUp!.title),
                ]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BK.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
            for (final b in o.newAwards) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BK.panel2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('New badge!'),
                            style: TextStyle(
                              color: BK.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            tr(b.title),
                            style: TextStyle(
                              color: BK.txt,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

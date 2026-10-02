import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/area_switcher.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'checklist_screen.dart';

/// Predictions, the weekly pattern and the official schedule.
class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = app.activeLive;
    final area = app.active;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final preds = l?.predictions ?? const <PredictedOutage>[];

    return BScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Text(
              tr('Forecast'),
              style: TextStyle(
                color: BK.txt,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const AreaSwitcher(),
            const SizedBox(height: 8),
            GlassCard(
              gradient: LinearGradient(
                colors: [
                  BK.accent.withValues(alpha: 0.22),
                  BK.accent2.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              glow: BK.accent,
              child: Row(
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preds.isEmpty
                              ? ((l?.observedDays ?? 0) < 2
                                    ? tr('Learning your area…')
                                    : tr('No cut expected in 24h 🎉'))
                              : trf('{0} cuts expected in 24h', [preds.length]),
                          style: TextStyle(
                            color: BK.txt,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trf('Based on {0} days of neighbour reports', [
                                l?.observedDays ?? 0,
                              ]) +
                              (app.scheduleFor(area?.id ?? '').isNotEmpty
                                  ? ' + ${tr('official schedule')}'
                                  : ''),
                          style: TextStyle(color: BK.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('Next 24 hours'),
            if (preds.isEmpty)
              GlassCard(
                child: Text(
                  (l?.observedDays ?? 0) < 2
                      ? tr(
                          'Forecasts start after ~2 days of reports. Keep tapping Light Gayi / Light Aayi — or add the official schedule below.',
                        )
                      : tr(
                          'Nothing expected. Enjoy the light! (We will warn you if that changes.)',
                        ),
                  style: TextStyle(color: BK.muted, height: 1.4),
                ),
              )
            else
              for (final p in preds) _PredRow(p: p),
            const SectionTitle('Today & tomorrow'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Today'),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DayTimeline(
                    day: today,
                    segments: l?.segments ?? const [],
                    predictions: preds,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('Tomorrow'),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DayTimeline(
                    day: today.add(const Duration(days: 1)),
                    segments: const [],
                    predictions: preds,
                  ),
                ],
              ),
            ),
            const SectionTitle('When cuts usually happen'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l != null) OutageHeatmap(matrix: l.matrix),
                  const SizedBox(height: 10),
                  Text(
                    tr(
                      'Darker red = more likely. Learned from the last 4 weeks.',
                    ),
                    style: TextStyle(color: BK.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            SectionTitle(
              'Official schedule',
              trailing: TextButton.icon(
                onPressed: area == null
                    ? null
                    : () => _addSlot(context, area.id),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(tr('Add')),
              ),
            ),
            if (area != null && app.scheduleFor(area.id).isEmpty)
              GlassCard(
                child: Text(
                  tr(
                    'Got a loadshedding schedule from your electricity company? Add it here and it will be used in the forecast and alerts.',
                  ),
                  style: TextStyle(color: BK.muted, height: 1.4),
                ),
              ),
            if (area != null)
              for (final (i, s) in app.scheduleFor(area.id).indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const EmojiBox('🗓️', size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fmtMin(s.startMinute)} – ${_fmtMin(s.startMinute + s.durationMinutes)}',
                                style: TextStyle(
                                  color: BK.txt,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _days(s.weekdayMask),
                                style: TextStyle(color: BK.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: BK.off,
                          ),
                          onPressed: () {
                            final list = [...app.scheduleFor(area.id)]
                              ..removeAt(i);
                            app.setSchedule(area.id, list);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            const SectionTitle('Be ready'),
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
                          tr('Before-the-cut checklist'),
                          style: TextStyle(
                            color: BK.txt,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        Text(
                          tr('Get a reminder 30 min before the next cut'),
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
        ),
      ),
    );
  }

  static String _fmtMin(int m) {
    final t = DateTime(2000, 1, 1).add(Duration(minutes: m));
    return fmtTime(t);
  }

  static String _days(int mask) {
    if (mask == 127) return tr('Every day');
    return [
      for (var d = 1; d <= 7; d++)
        if (mask & (1 << (d - 1)) != 0) dayShort(d),
    ].join(', ');
  }

  Future<void> _addSlot(BuildContext context, String areaId) async {
    final slot = await showModalBottomSheet<ScheduleSlot>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SlotEditor(),
    );
    if (slot == null || !context.mounted) return;
    final app = context.read<AppState>();
    await app.setSchedule(areaId, [...app.scheduleFor(areaId), slot]);
  }
}

class _PredRow extends StatelessWidget {
  final PredictedOutage p;
  const _PredRow({required this.p});
  @override
  Widget build(BuildContext context) {
    final pct = (p.probability * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  fmtDay(p.start),
                  style: TextStyle(
                    color: BK.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fmtTime(p.start)} – ${fmtTime(p.end)}',
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Pill(
                  p.fromSchedule ? tr('Official') : '$pct%',
                  color: p.fromSchedule
                      ? BK.accent
                      : (pct >= 75 ? BK.off : BK.warn),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 15, color: BK.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trf('about {0}', [fmtDuration(p.duration)]),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: BK.muted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  fmtIn(p.start),
                  style: TextStyle(
                    color: BK.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

class _SlotEditor extends StatefulWidget {
  const _SlotEditor();
  @override
  State<_SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends State<_SlotEditor> {
  int _mask = 127;
  TimeOfDay _start = const TimeOfDay(hour: 14, minute: 0);
  int _duration = 60;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Add schedule slot'),
              style: TextStyle(
                color: BK.txt,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Days'),
              style: TextStyle(color: BK.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(dayShort(d)),
                    selected: _mask & (1 << (d - 1)) != 0,
                    onSelected: (v) => setState(() {
                      _mask = v
                          ? _mask | (1 << (d - 1))
                          : _mask & ~(1 << (d - 1));
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            BTile(
              icon: Icons.schedule_rounded,
              title: 'Starts at',
              subtitle: fmtTime(
                DateTime(2000, 1, 1, _start.hour, _start.minute),
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _start,
                );
                if (t != null) setState(() => _start = t);
              },
            ),
            const SizedBox(height: 8),
            Text(
              trf('Lasts {0}', [fmtDuration(Duration(minutes: _duration))]),
              style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
            ),
            Slider(
              value: _duration.toDouble(),
              min: 30,
              max: 360,
              divisions: 11,
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _mask == 0
                    ? null
                    : () => Navigator.pop(
                        context,
                        ScheduleSlot(
                          _mask,
                          _start.hour * 60 + _start.minute,
                          _duration,
                        ),
                      ),
                child: Text(tr('Save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

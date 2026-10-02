import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class Appliance {
  final String id, name, emoji;
  final int watts;
  const Appliance(this.id, this.name, this.emoji, this.watts);
}

const kAppliances = [
  Appliance('fan', 'Ceiling fan', '🌀', 75),
  Appliance('led', 'LED bulb', '💡', 12),
  Appliance('tube', 'Tube light', '🔦', 20),
  Appliance('router', 'WiFi router', '📶', 12),
  Appliance('phone', 'Phone charger', '📱', 10),
  Appliance('laptop', 'Laptop', '💻', 65),
  Appliance('tv', 'LED TV', '📺', 80),
  Appliance('fridge', 'Fridge', '🧊', 150),
  Appliance('pc', 'Desktop PC', '🖥️', 200),
  Appliance('motor', 'Water pump', '🚰', 750),
  Appliance('iron', 'Iron', '👔', 1000),
  Appliance('ac', 'Inverter AC (1 ton)', '❄️', 1100),
];

/// UPS backup · Solar planner · Bill estimate.
class ToolsScreen extends StatefulWidget {
  final int initialTab;
  const ToolsScreen({super.key, this.initialTab = 0});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: BScaffold(
        title: 'Power tools',
        body: Column(
          children: [
            TabBar(
              labelColor: BK.accent,
              unselectedLabelColor: BK.muted,
              indicatorColor: BK.accent,
              dividerColor: BK.line,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: '🔋 ${tr('UPS')}'),
                Tab(text: '☀️ ${tr('Solar')}'),
                Tab(text: '🧾 ${tr('Bill')}'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_UpsTool(), _SolarTool(), _BillTool()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared appliance picker: counts per appliance.
class _LoadPicker extends StatelessWidget {
  final Map<String, int> counts;
  final ValueChanged<Map<String, int>> onChanged;
  const _LoadPicker({required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final a in kAppliances)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(a.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(a.name),
                        style: TextStyle(
                          color: BK.txt,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${a.watts} W',
                        style: TextStyle(color: BK.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _Stepper(
                  value: counts[a.id] ?? 0,
                  onChanged: (v) => onChanged({...counts, a.id: v}),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: BK.panel2,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.remove_rounded, color: BK.muted, size: 18),
          onPressed: value == 0 ? null : () => onChanged(value - 1),
        ),
        SizedBox(
          width: 20,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: value > 0 ? BK.accent : BK.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.add_rounded, color: BK.accent, size: 18),
          onPressed: value >= 20 ? null : () => onChanged(value + 1),
        ),
      ],
    ),
  );
}

int _watts(Map<String, int> counts) =>
    kAppliances.fold(0, (s, a) => s + a.watts * (counts[a.id] ?? 0));

Map<String, int> _readCounts(AppState app, String key, Map<String, int> def) {
  final raw = app.toolPrefs[key];
  if (raw is Map) return raw.map((k, v) => MapEntry('$k', (v as num).toInt()));
  return def;
}

// ------------------------------------------------------------------- UPS

class _UpsTool extends StatefulWidget {
  const _UpsTool();
  @override
  State<_UpsTool> createState() => _UpsToolState();
}

class _UpsToolState extends State<_UpsTool> {
  late final AppState app = context.read<AppState>();
  late Map<String, int> _counts = _readCounts(app, 'upsLoad', {
    'fan': 2,
    'led': 3,
    'router': 1,
    'phone': 2,
  });
  late double _ah = (app.toolPrefs['upsAh'] as num?)?.toDouble() ?? 150;
  late int _volts = (app.toolPrefs['upsV'] as num?)?.toInt() ?? 12;
  late bool _lithium = app.toolPrefs['upsLi'] == true;
  late double _health =
      (app.toolPrefs['upsHealth'] as num?)?.toDouble() ?? 0.85;

  void _save() => app.saveTools({
    'upsLoad': _counts,
    'upsAh': _ah,
    'upsV': _volts,
    'upsLi': _lithium,
    'upsHealth': _health,
  });

  @override
  Widget build(BuildContext context) {
    final watts = _watts(_counts);
    // Usable energy: capacity × voltage × depth of discharge × health × inverter.
    final dod = _lithium ? 0.9 : 0.5;
    final wh = _ah * _volts * dod * _health * 0.85;
    final hours = watts == 0 ? 0.0 : wh / watts;
    final live = context.watch<AppState>().activeLive;
    final cut =
        live?.next?.duration ??
        (live?.restoreEta != null && live?.status.since != null
            ? live!.restoreEta!.difference(live.status.since!)
            : null);
    final enough = cut == null ? null : hours * 60 >= cut.inMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        GlassCard(
          glow: watts == 0 ? null : (enough == false ? BK.off : BK.on),
          child: Column(
            children: [
              Text(
                tr('Your UPS will run for'),
                style: TextStyle(color: BK.muted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                watts == 0
                    ? '—'
                    : fmtDurationShort(Duration(minutes: (hours * 60).round())),
                style: TextStyle(
                  color: BK.txt,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                trf('with {0} W load', [watts]),
                style: TextStyle(color: BK.muted),
              ),
              if (enough != null && watts > 0) ...[
                const SizedBox(height: 12),
                Pill(
                  enough
                      ? trf('Enough for the next cut (~{0}) ✅', [
                          fmtDuration(cut!),
                        ])
                      : trf(
                          'Not enough for the next cut (~{0}) — switch something off',
                          [fmtDuration(cut!)],
                        ),
                  color: enough ? BK.on : BK.off,
                ),
              ],
            ],
          ),
        ),
        const SectionTitle('Battery'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trf('Capacity: {0} Ah', [_ah.round()]),
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: _ah,
                min: 50,
                max: 300,
                divisions: 25,
                onChanged: (v) => setState(() => _ah = v),
                onChangeEnd: (_) => _save(),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(tr('System'), style: TextStyle(color: BK.muted)),
                  const SizedBox(width: 12),
                  for (final v in [12, 24, 48])
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: ChoiceChip(
                        label: Text('${v}V'),
                        selected: _volts == v,
                        onSelected: (_) {
                          setState(() => _volts = v);
                          _save();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 0,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(tr('Type'), style: TextStyle(color: BK.muted)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(tr('Lead-acid')),
                    selected: !_lithium,
                    onSelected: (_) {
                      setState(() => _lithium = false);
                      _save();
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(tr('Lithium')),
                    selected: _lithium,
                    onSelected: (_) {
                      setState(() => _lithium = true);
                      _save();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trf('Battery health: {0}%', [(_health * 100).round()]),
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: _health,
                min: 0.4,
                max: 1,
                divisions: 12,
                onChanged: (v) => setState(() => _health = v),
                onChangeEnd: (_) => _save(),
              ),
            ],
          ),
        ),
        const SectionTitle('What will you run?'),
        GlassCard(
          child: _LoadPicker(
            counts: _counts,
            onChanged: (c) {
              setState(() => _counts = c);
              _save();
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            'Estimate only. Real backup depends on battery age, temperature and UPS efficiency.',
          ),
          style: TextStyle(color: BK.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Solar

class _SolarTool extends StatefulWidget {
  const _SolarTool();
  @override
  State<_SolarTool> createState() => _SolarToolState();
}

class _SolarToolState extends State<_SolarTool> {
  late final AppState app = context.read<AppState>();
  late Map<String, int> _counts = _readCounts(app, 'solarLoad', {
    'fan': 3,
    'led': 6,
    'fridge': 1,
    'tv': 1,
  });
  late double _hoursPerDay =
      (app.toolPrefs['solarHours'] as num?)?.toDouble() ?? 8;
  late int _panelW = (app.toolPrefs['solarPanel'] as num?)?.toInt() ?? 585;
  late double _sun = (app.toolPrefs['solarSun'] as num?)?.toDouble() ?? 5;
  late double _backupH =
      (app.toolPrefs['solarBackup'] as num?)?.toDouble() ?? 4;

  void _save() => app.saveTools({
    'solarLoad': _counts,
    'solarHours': _hoursPerDay,
    'solarPanel': _panelW,
    'solarSun': _sun,
    'solarBackup': _backupH,
  });

  @override
  Widget build(BuildContext context) {
    final watts = _watts(_counts);
    final dailyWh = watts * _hoursPerDay;
    // Panels: daily energy / (sun hours × 75% system efficiency).
    final arrayW = dailyWh / (_sun * 0.75);
    final panels = watts == 0 ? 0 : max(1, (arrayW / _panelW).ceil());
    final inverterKw = watts == 0 ? 0.0 : (watts * 1.3 / 1000);
    final inverter = inverterKw <= 0 ? 0 : max(1, inverterKw.ceil());
    // Lithium 48 V bank for the backup hours.
    final batteryKwh = watts * _backupH / 0.9 / 1000;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        GlassCard(
          glow: BK.warn,
          child: Column(
            children: [
              Text(
                tr('You need about'),
                style: TextStyle(color: BK.muted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      '$panels',
                      trf('panels × {0} W', [_panelW]),
                      emoji: '☀️',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      '$inverter kW',
                      tr('inverter'),
                      emoji: '⚙️',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      '${batteryKwh.toStringAsFixed(1)} kWh',
                      tr('battery'),
                      emoji: '🔋',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trf('Daily use ≈ {0} units (kWh)', [
                  (dailyWh / 1000).toStringAsFixed(1),
                ]),
                style: TextStyle(color: BK.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SectionTitle('Settings'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trf('Hours of use per day: {0}', [_hoursPerDay.round()]),
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: _hoursPerDay,
                min: 1,
                max: 24,
                divisions: 23,
                onChanged: (v) => setState(() => _hoursPerDay = v),
                onChangeEnd: (_) => _save(),
              ),
              Text(
                trf('Sun hours: {0}', [_sun.toStringAsFixed(1)]),
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: _sun,
                min: 3,
                max: 7,
                divisions: 8,
                onChanged: (v) => setState(() => _sun = v),
                onChangeEnd: (_) => _save(),
              ),
              Text(
                trf('Battery backup at night: {0}h', [_backupH.round()]),
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: _backupH,
                min: 0,
                max: 12,
                divisions: 12,
                onChanged: (v) => setState(() => _backupH = v),
                onChangeEnd: (_) => _save(),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final w in [450, 550, 585, 650])
                    ChoiceChip(
                      label: Text('$w W'),
                      selected: _panelW == w,
                      onSelected: (_) {
                        setState(() => _panelW = w);
                        _save();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Load'),
        GlassCard(
          child: _LoadPicker(
            counts: _counts,
            onChanged: (c) {
              setState(() => _counts = c);
              _save();
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            'Rough guide only — get a site survey from an installer before buying.',
          ),
          style: TextStyle(color: BK.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Bill

class _BillTool extends StatefulWidget {
  const _BillTool();
  @override
  State<_BillTool> createState() => _BillToolState();
}

class _BillToolState extends State<_BillTool> {
  late final AppState app = context.read<AppState>();
  late final _units = TextEditingController(
    text: '${app.toolPrefs['billUnits'] ?? 250}',
  );
  late final _rate = TextEditingController(
    text: '${app.toolPrefs['billRate'] ?? 45}',
  );
  late final _fixed = TextEditingController(
    text: '${app.toolPrefs['billFixed'] ?? 0}',
  );
  late double _tax = (app.toolPrefs['billTax'] as num?)?.toDouble() ?? 18;

  @override
  void dispose() {
    _units.dispose();
    _rate.dispose();
    _fixed.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  void _save() => app.saveTools({
    'billUnits': _n(_units).round(),
    'billRate': _n(_rate),
    'billFixed': _n(_fixed),
    'billTax': _tax,
  });

  @override
  Widget build(BuildContext context) {
    final energy = _n(_units) * _n(_rate);
    final fixed = _n(_fixed);
    final tax = (energy + fixed) * _tax / 100;
    final total = energy + fixed + tax;
    String money(double v) => v.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        GlassCard(
          glow: BK.accent,
          child: Column(
            children: [
              Text(
                tr('Estimated bill'),
                style: TextStyle(color: BK.muted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                money(total),
                style: TextStyle(
                  color: BK.txt,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _line(tr('Energy'), money(energy)),
              _line(tr('Fixed charges'), money(fixed)),
              _line(trf('Taxes ({0}%)', [_tax.round()]), money(tax)),
            ],
          ),
        ),
        const SectionTitle('Your numbers'),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: _units,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Units used (kWh)')),
                onChanged: (_) {
                  setState(() {});
                  _save();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr('Price per unit (from your bill)'),
                ),
                onChanged: (_) {
                  setState(() {});
                  _save();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fixed,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('Fixed charges / meter rent'),
                ),
                onChanged: (_) {
                  setState(() {});
                  _save();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    trf('Taxes: {0}%', [_tax.round()]),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _tax,
                      min: 0,
                      max: 40,
                      divisions: 40,
                      onChanged: (v) => setState(() => _tax = v),
                      onChangeEnd: (_) => _save(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            'Tariffs change often — copy the per-unit price and taxes from your latest bill for an accurate estimate.',
          ),
          style: TextStyle(color: BK.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _line(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(a, style: TextStyle(color: BK.muted)),
        const Spacer(),
        Text(
          b,
          style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

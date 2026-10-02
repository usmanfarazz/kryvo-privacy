import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/geohash.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_tiles.dart';

/// Live map of nearby areas, coloured by power state.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  List<AreaSnapshot> _areas = [];
  String? _loadedPrefix;
  bool _loading = false;
  PowerState? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = context.read<AppState>().active;
      if (a != null) _load(a.id.substring(0, kNearbyPrecision));
    });
  }

  Future<void> _load(String prefix, {bool force = false}) async {
    if (!force && prefix == _loadedPrefix) return;
    setState(() => _loading = true);
    try {
      final list = await context.read<AppState>().repo.nearby(prefix);
      if (!mounted) return;
      setState(() {
        _areas = list;
        _loadedPrefix = prefix;
      });
    } catch (_) {
      if (mounted) {
        toast(context, tr('Could not load the map. Check your internet.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _color(PowerState s) => switch (s) {
    PowerState.on => BK.on,
    PowerState.off => BK.off,
    PowerState.unknown => BK.muted,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.active;
    final myLive = app.activeLive;

    // My own area always uses the freshest computed status.
    final shown = <AreaSnapshot>[
      for (final a in _areas)
        if (a.id != active?.id) a,
      if (active != null)
        AreaSnapshot(
          id: active.id,
          place: active.title,
          city: active.city,
          lat: active.lat,
          lng: active.lng,
          state: myLive?.status.state ?? PowerState.unknown,
          since: myLive?.status.since,
          updated: myLive?.status.lastReport ?? DateTime.now(),
        ),
    ];
    final counts = {
      for (final s in PowerState.values)
        s: shown.where((a) => a.freshState == s).length,
    };
    final visible = _filter == null
        ? shown
        : shown.where((a) => a.freshState == _filter).toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: active == null
                  ? const LatLng(31.5204, 74.3587)
                  : LatLng(active.lat, active.lng),
              initialZoom: 13.5,
              onMapEvent: (e) {
                if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) {
                  final c = _map.camera.center;
                  _load(
                    geohashEncode(
                      c.latitude,
                      c.longitude,
                      precision: kNearbyPrecision,
                    ),
                  );
                }
              },
            ),
            children: [
              ...baseMapLayers(),
              MarkerLayer(
                markers: [
                  for (final a in visible)
                    Marker(
                      point: LatLng(a.lat, a.lng),
                      width: a.id == active?.id ? 64 : 46,
                      height: a.id == active?.id ? 64 : 46,
                      child: GestureDetector(
                        onTap: () => _details(a),
                        child: _Dot(
                          color: _color(a.freshState),
                          mine: a.id == active?.id,
                          emoji: a.id == active?.id ? active!.emoji : null,
                        ),
                      ),
                    ),
                ],
              ),
              mapAttribution(),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded, color: BK.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('Live map'),
                            style: TextStyle(
                              color: BK.txt,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (_loading)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BK.accent,
                            ),
                          )
                        else
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.refresh_rounded, color: BK.muted),
                            onPressed: () {
                              final c = _map.camera.center;
                              _load(
                                geohashEncode(
                                  c.latitude,
                                  c.longitude,
                                  precision: kNearbyPrecision,
                                ),
                                force: true,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: trf('All {0}', [shown.length]),
                          color: BK.accent,
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        _FilterChip(
                          label: trf('💡 On {0}', [counts[PowerState.on]!]),
                          color: BK.on,
                          selected: _filter == PowerState.on,
                          onTap: () => setState(() => _filter = PowerState.on),
                        ),
                        _FilterChip(
                          label: trf('❌ Off {0}', [counts[PowerState.off]!]),
                          color: BK.off,
                          selected: _filter == PowerState.off,
                          onTap: () => setState(() => _filter = PowerState.off),
                        ),
                        _FilterChip(
                          label: trf('❔ Unknown {0}', [
                            counts[PowerState.unknown]!,
                          ]),
                          color: BK.muted,
                          selected: _filter == PowerState.unknown,
                          onTap: () =>
                              setState(() => _filter = PowerState.unknown),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 30,
            child: FloatingActionButton(
              heroTag: 'mapHome',
              backgroundColor: BK.accent,
              foregroundColor: BK.onAccent,
              onPressed: () {
                if (active != null) {
                  _map.move(LatLng(active.lat, active.lng), 14.5);
                }
              },
              child: const Icon(Icons.home_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _details(AreaSnapshot a) {
    final app = context.read<AppState>();
    final following = app.areas.any((x) => x.id == a.id);
    final s = a.freshState;
    final c = _color(s);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s == PowerState.on
                          ? Icons.lightbulb_rounded
                          : s == PowerState.off
                          ? Icons.power_off_rounded
                          : Icons.question_mark_rounded,
                      color: c,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.place.isEmpty ? tr('Nearby area') : a.place,
                          style: TextStyle(
                            color: BK.txt,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          switch (s) {
                                PowerState.on => tr('Light is ON'),
                                PowerState.off => tr('Light is OFF'),
                                PowerState.unknown => tr('No recent reports'),
                              } +
                              (a.since != null && s != PowerState.unknown
                                  ? ' · ${trf('for {0}', [fmtDuration(DateTime.now().difference(a.since!))])}'
                                  : ''),
                          style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (a.updated != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    trf('Last report {0}', [fmtAgo(a.updated!)]),
                    style: TextStyle(color: BK.muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              if (!following)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final area = await LocationService.areaAt(
                        a.lat,
                        a.lng,
                        emoji: '📍',
                      );
                      await app.addArea(area, makeActive: false);
                      if (mounted) toast(context, tr('Added to your areas'));
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Follow this area')),
                  ),
                )
              else
                Pill(
                  tr('You follow this area'),
                  color: BK.accent,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final bool mine;
  final String? emoji;
  const _Dot({required this.color, required this.mine, this.emoji});
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.22),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14),
            ],
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.55,
          heightFactor: 0.55,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: mine ? 3 : 2),
            ),
            child: emoji == null
                ? null
                : Text(emoji!, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : BK.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : BK.line),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (color.computeLuminance() > 0.45
                      ? Colors.black
                      : Colors.white)
                : BK.txt,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

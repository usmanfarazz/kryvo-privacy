import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/geohash.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_tiles.dart';

const kAreaEmojis = [
  '🏠',
  '🏢',
  '🏫',
  '🏥',
  '🕌',
  '🏪',
  '👵',
  '❤️',
  '🏭',
  '🌳',
];

/// Pick an area with GPS or by dragging the map, then name it.
class AreaPickerScreen extends StatefulWidget {
  final String defaultLabel;
  final bool embedded; // inside onboarding: no app bar
  final ValueChanged<SavedArea>? onDone;
  const AreaPickerScreen({
    super.key,
    this.defaultLabel = '',
    this.embedded = false,
    this.onDone,
  });

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  final _map = MapController();
  final _label = TextEditingController();
  // Lahore as a starting point until GPS answers.
  LatLng _center = const LatLng(31.5204, 74.3587);
  String _emoji = kAreaEmojis.first;
  SavedArea? _area;
  bool _locating = false;
  bool _naming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label.text = widget.defaultLabel;
    WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final r = await LocationService.detect(label: _label.text, emoji: _emoji);
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (r.area != null) {
        _area = r.area;
        _center = LatLng(r.area!.lat, r.area!.lng);
        _map.move(_center, 15);
      } else {
        _error = tr(r.error ?? 'Could not get your location.');
      }
    });
  }

  Future<void> _resolveCenter() async {
    setState(() => _naming = true);
    final a = await LocationService.areaAt(_center.latitude, _center.longitude);
    if (!mounted) return;
    setState(() {
      _area = a;
      _naming = false;
    });
  }

  void _finish() {
    final a = _area;
    if (a == null) return;
    final done = SavedArea(
      id: a.id,
      label: _label.text.trim(),
      emoji: _emoji,
      place: a.place,
      city: a.city,
      lat: a.lat,
      lng: a.lng,
    );
    if (widget.onDone != null) {
      widget.onDone!(done);
    } else {
      Navigator.pop(context, done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = geohashDecode(
      geohashEncode(_center.latitude, _center.longitude),
    );
    final body = Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 14,
                  onPositionChanged: (camera, gesture) {
                    if (gesture) setState(() => _center = camera.center);
                  },
                  onMapEvent: (e) {
                    if (e is MapEventMoveEnd ||
                        e is MapEventFlingAnimationEnd) {
                      _resolveCenter();
                    }
                  },
                ),
                children: [
                  ...baseMapLayers(),
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: [
                          LatLng(cell.latMin, cell.lngMin),
                          LatLng(cell.latMin, cell.lngMax),
                          LatLng(cell.latMax, cell.lngMax),
                          LatLng(cell.latMax, cell.lngMin),
                        ],
                        color: BK.accent.withValues(alpha: 0.18),
                        borderColor: BK.accent,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  mapAttribution(),
                ],
              ),
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: BK.accent,
                      shadows: const [
                        Shadow(blurRadius: 12, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: FloatingActionButton(
                  heroTag: 'gps',
                  backgroundColor: BK.panel,
                  foregroundColor: BK.accent,
                  onPressed: _locating ? null : _useGps,
                  child: _locating
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: BK.accent,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
              Positioned(
                left: 14,
                right: 80,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: BK.panel.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tr(
                      'Drag the map so the pin is on your home. The box is your area (~1 km).',
                    ),
                    style: TextStyle(color: BK.txt, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: BK.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.place_rounded, color: BK.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _naming
                          ? Text(
                              tr('Finding the area name…'),
                              style: TextStyle(color: BK.muted),
                            )
                          : Text(
                              _area?.subtitle ??
                                  _error ??
                                  tr('Finding your location…'),
                              style: TextStyle(
                                color: _error != null && _area == null
                                    ? BK.off
                                    : BK.txt,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _label,
                  decoration: InputDecoration(
                    labelText: tr('Name (e.g. Ghar, Office, Ammi ka ghar)'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in kAreaEmojis)
                        GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: Container(
                            width: 46,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _emoji == e
                                  ? BK.accent.withValues(alpha: 0.2)
                                  : BK.panel2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _emoji == e ? BK.accent : BK.line,
                              ),
                            ),
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: tr('Save this area'),
                  icon: Icons.check_rounded,
                  onPressed: _area == null || _naming ? null : _finish,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return BScaffold(title: 'Choose your area', body: body);
  }
}

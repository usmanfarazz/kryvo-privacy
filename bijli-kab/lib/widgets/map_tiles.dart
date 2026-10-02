import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme.dart';

/// OpenStreetMap tiles, darkened on dark themes. For a large audience switch
/// [kTileUrl] to a commercial provider (MapTiler, Stadia, …) — see README.
const kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

List<Widget> baseMapLayers() => [
  TileLayer(
    urlTemplate: kTileUrl,
    userAgentPackageName: 'com.farazlabs.bijli_kab',
    tileBuilder: BK.dark ? darkModeTileBuilder : null,
  ),
];

Widget mapAttribution() => const SimpleAttributionWidget(
  source: Text('OpenStreetMap contributors'),
  backgroundColor: Color(0x99000000),
);

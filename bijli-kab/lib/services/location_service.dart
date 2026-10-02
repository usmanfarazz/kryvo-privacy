import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import 'geohash.dart';

class LocationResult {
  final SavedArea? area;
  final String? error; // translated by the caller
  const LocationResult(this.area, [this.error]);
}

class LocationService {
  /// Finds the phone's location and turns it into an area.
  static Future<LocationResult> detect({
    String label = '',
    String emoji = '🏠',
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
          null,
          'Turn on location (GPS) and try again',
        );
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const LocationResult(
          null,
          'Location permission denied. You can pick your area on the map instead.',
        );
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        return const LocationResult(
          null,
          'Could not get your location. Try again outside or pick on the map.',
        );
      }
      return LocationResult(
        await areaAt(pos.latitude, pos.longitude, label: label, emoji: emoji),
      );
    } catch (_) {
      return const LocationResult(
        null,
        'Could not get your location. Try again outside or pick on the map.',
      );
    }
  }

  /// Builds an area for a point, naming it via the phone's geocoder.
  static Future<SavedArea> areaAt(
    double lat,
    double lng, {
    String label = '',
    String emoji = '🏠',
  }) async {
    var place = '', city = '';
    try {
      final marks = await Geocoding(
        locale: const Locale('en'),
      ).placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 8));
      if (marks.isNotEmpty) {
        final m = marks.first;
        place =
            [m.subLocality, m.thoroughfare, m.name]
                .firstWhere(
                  (s) => s != null && s.trim().isNotEmpty,
                  orElse: () => '',
                )
                ?.trim() ??
            '';
        city = (m.locality?.trim().isNotEmpty ?? false)
            ? m.locality!.trim()
            : (m.administrativeArea ?? '').trim();
      }
    } catch (_) {
      // Offline or no geocoder: the user can still name the area.
    }
    final id = geohashEncode(lat, lng);
    if (place.isEmpty) place = city.isNotEmpty ? city : 'Area $id';
    return SavedArea(
      id: id,
      label: label,
      emoji: emoji,
      place: place,
      city: city,
      lat: lat,
      lng: lng,
    );
  }
}

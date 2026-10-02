/// Minimal geohash encoder/decoder.
///
/// An "area" in Bijli Kab? is a geohash cell. Precision 6 is roughly
/// 1.2 km × 0.6 km — about one neighbourhood / feeder — so neighbours who
/// report end up in the same cell without anyone maintaining an area list.
library;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

const int kAreaPrecision = 6;

/// Prefix length used to fetch the cells around the user for the map.
const int kNearbyPrecision = 4;

String geohashEncode(double lat, double lng, {int precision = kAreaPrecision}) {
  var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
  final out = StringBuffer();
  var bit = 0, ch = 0;
  var even = true;
  while (out.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

class GeoBox {
  final double latMin, latMax, lngMin, lngMax;
  const GeoBox(this.latMin, this.latMax, this.lngMin, this.lngMax);
  double get lat => (latMin + latMax) / 2;
  double get lng => (lngMin + lngMax) / 2;
}

GeoBox geohashDecode(String hash) {
  var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
  var even = true;
  for (final c in hash.split('')) {
    final cd = _base32.indexOf(c);
    if (cd < 0) throw FormatException('Invalid geohash', hash);
    for (var mask = 16; mask > 0; mask >>= 1) {
      if (even) {
        final mid = (lngMin + lngMax) / 2;
        if (cd & mask != 0) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (cd & mask != 0) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      even = !even;
    }
  }
  return GeoBox(latMin, latMax, lngMin, lngMax);
}

bool isValidGeohash(String s) =>
    s.isNotEmpty && s.split('').every((c) => _base32.contains(c));

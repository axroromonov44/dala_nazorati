import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A single slippy-map (XYZ) tile coordinate.
class TileCoord {
  const TileCoord(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;
}

/// Pure tile-grid math, kept separate so both the live [TileLayer] rendering
/// and the offline region pre-downloader compute the exact same URLs —
/// otherwise pre-downloaded tiles would land under a different cache key
/// than the one the map actually requests while browsing.
class TileMath {
  const TileMath._();

  static int lonToTileX(double lonDeg, int z) {
    final n = 1 << z;
    return (((lonDeg + 180.0) / 360.0) * n).floor().clamp(0, n - 1);
  }

  static int latToTileY(double latDeg, int z) {
    final n = 1 << z;
    final latRad = latDeg * pi / 180.0;
    final y = (1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / pi)) / 2.0 * n;
    return y.floor().clamp(0, n - 1);
  }

  /// All tiles covering a square region of [radiusMeters] around [center],
  /// for every zoom level in `minZoom..maxZoom` (inclusive).
  static List<TileCoord> tilesForRegion({
    required LatLng center,
    required double radiusMeters,
    required int minZoom,
    required int maxZoom,
  }) {
    final latDelta = radiusMeters / 111320.0;
    final lngDelta =
        radiusMeters / (111320.0 * cos(center.latitude * pi / 180));
    final north = (center.latitude + latDelta).clamp(-85.05112878, 85.05112878);
    final south = (center.latitude - latDelta).clamp(-85.05112878, 85.05112878);
    final east = center.longitude + lngDelta;
    final west = center.longitude - lngDelta;

    final tiles = <TileCoord>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = lonToTileX(west, z);
      final xMax = lonToTileX(east, z);
      final yMin = latToTileY(north, z);
      final yMax = latToTileY(south, z);
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          tiles.add(TileCoord(x, y, z));
        }
      }
    }
    return tiles;
  }

  /// A square [LatLngBounds] of [radiusMeters] around [center] — used to fit
  /// the map camera to the same area a [tilesForRegion] download covers.
  static LatLngBounds boundsFor(LatLng center, double radiusMeters) {
    final latDelta = radiusMeters / 111320.0;
    final lngDelta = radiusMeters / (111320.0 * cos(center.latitude * pi / 180));
    return LatLngBounds(
      LatLng(center.latitude - latDelta, center.longitude - lngDelta),
      LatLng(center.latitude + latDelta, center.longitude + lngDelta),
    );
  }

  /// Builds the concrete tile URL exactly the way flutter_map's [TileLayer]
  /// would (see `base_tile_provider.dart#generateReplacementMap`), so
  /// pre-downloaded tiles are cached under the same key that live rendering
  /// will later request.
  static String buildTileUrl({
    required String urlTemplate,
    required List<String> subdomains,
    required TileCoord coord,
    required bool retina,
  }) {
    final s = subdomains.isEmpty
        ? ''
        : subdomains[(coord.x + coord.y) % subdomains.length];
    return urlTemplate
        .replaceAll('{s}', s)
        .replaceAll('{z}', coord.z.toString())
        .replaceAll('{x}', coord.x.toString())
        .replaceAll('{y}', coord.y.toString())
        .replaceAll('{r}', retina ? '@2x' : '');
  }
}

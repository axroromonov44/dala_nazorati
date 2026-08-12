import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TileCoord {
  const TileCoord(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;
}

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

  static List<TileCoord> tilesForRegion({
    required LatLng center,
    required double radiusMeters,
    required int minZoom,
    required int maxZoom,
  }) => tilesForBounds(
    bounds: boundsFor(center, radiusMeters),
    minZoom: minZoom,
    maxZoom: maxZoom,
  );

  static List<TileCoord> tilesForBounds({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) {
    final tiles = <TileCoord>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = lonToTileX(bounds.west, z);
      final xMax = lonToTileX(bounds.east, z);
      final yMin = latToTileY(bounds.north, z);
      final yMax = latToTileY(bounds.south, z);
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          tiles.add(TileCoord(x, y, z));
        }
      }
    }
    return tiles;
  }

  static LatLngBounds boundsFor(LatLng center, double radiusMeters) =>
      padBounds(LatLngBounds(center, center), radiusMeters);

  static LatLngBounds padBounds(LatLngBounds bounds, double marginMeters) {
    final midLat = (bounds.north + bounds.south) / 2;
    final latDelta = marginMeters / 111320.0;
    final lngDelta = marginMeters / (111320.0 * cos(midLat * pi / 180));
    return LatLngBounds(
      LatLng(
        (bounds.south - latDelta).clamp(-85.05112878, 85.05112878),
        bounds.west - lngDelta,
      ),
      LatLng(
        (bounds.north + latDelta).clamp(-85.05112878, 85.05112878),
        bounds.east + lngDelta,
      ),
    );
  }

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

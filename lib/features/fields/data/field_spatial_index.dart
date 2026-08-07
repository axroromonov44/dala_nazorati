import 'package:flutter_map/flutter_map.dart';
import '../../../core/map/tile_math.dart';
import '../domain/entities/field_summary.dart';

/// In-memory grid index over all cached [FieldSummary] records, so a map
/// viewport query is O(cells in view) instead of O(all fields). Fields are
/// lightweight (no photos/description), so keeping every one of them in RAM
/// is cheap — that split is the whole point of [FieldSummary] vs
/// `FieldDetail`.
///
/// Reuses the existing slippy-map tile math (`TileMath`) purely as a
/// bucketing key at a fixed zoom — this has nothing to do with rendering
/// zoom, it's just a convenient, already-tested lat/lng -> grid-cell
/// conversion.
class FieldSpatialIndex {
  static const _gridZoom = 12;

  final Map<String, List<FieldSummary>> _cells = {};
  final Map<String, FieldSummary> _byId = {};

  /// Replaces the entire index — used once at startup after loading the
  /// persisted index box.
  void rebuild(Iterable<FieldSummary> fields) {
    _cells.clear();
    _byId.clear();
    for (final field in fields) {
      _insert(field);
    }
  }

  /// Adds or replaces a single field — used after a delta sync so the whole
  /// index doesn't need rebuilding for a handful of changed records.
  void upsert(FieldSummary field) {
    final existing = _byId[field.id];
    if (existing != null) _removeFromCell(existing);
    _insert(field);
  }

  void remove(String id) {
    final existing = _byId.remove(id);
    if (existing != null) _removeFromCell(existing);
  }

  List<FieldSummary> query(LatLngBounds bounds) {
    final xMin = TileMath.lonToTileX(bounds.west, _gridZoom);
    final xMax = TileMath.lonToTileX(bounds.east, _gridZoom);
    final yMin = TileMath.latToTileY(bounds.north, _gridZoom);
    final yMax = TileMath.latToTileY(bounds.south, _gridZoom);

    final result = <FieldSummary>[];
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        final bucket = _cells['${x}_$y'];
        if (bucket != null) result.addAll(bucket);
      }
    }
    return result;
  }

  void _insert(FieldSummary field) {
    _byId[field.id] = field;
    _cells.putIfAbsent(_cellKeyFor(field), () => []).add(field);
  }

  void _removeFromCell(FieldSummary field) {
    _cells[_cellKeyFor(field)]?.removeWhere((f) => f.id == field.id);
  }

  String _cellKeyFor(FieldSummary field) {
    final x = TileMath.lonToTileX(field.centroid.longitude, _gridZoom);
    final y = TileMath.latToTileY(field.centroid.latitude, _gridZoom);
    return '${x}_$y';
  }
}

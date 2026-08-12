import 'package:flutter_map/flutter_map.dart';
import '../../../core/map/tile_math.dart';
import '../domain/entities/field_summary.dart';

class FieldSpatialIndex {
  static const _gridZoom = 12;

  final Map<String, List<FieldSummary>> _cells = {};
  final Map<String, FieldSummary> _byId = {};

  void rebuild(Iterable<FieldSummary> fields) {
    _cells.clear();
    _byId.clear();
    for (final field in fields) {
      _insert(field);
    }
  }

  void upsert(FieldSummary field) {
    final existing = _byId[field.id];
    if (existing != null) _removeFromCell(existing);
    _insert(field);
  }

  void remove(String id) {
    final existing = _byId.remove(id);
    if (existing != null) _removeFromCell(existing);
  }

  Iterable<FieldSummary> get all => _byId.values;

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

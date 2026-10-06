import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/map/tile_math.dart';
import '../../../core/storage/map_object_store.dart';
import '../domain/entities/field_summary.dart';

/// An in-memory window onto the stored objects, not the store itself.
///
/// It holds the grid cells that have been on screen recently and drops the
/// oldest ones, so memory follows where the inspector has looked rather than
/// how much was downloaded. A province-sized download stays on disk; only the
/// handful of cells under the viewport is ever decoded.
class FieldSpatialIndex {
  static const _gridZoom = MapObjectStore.gridZoom;

  /// Enough cells for a long pan without reloading, few enough that the heap
  /// stays flat. At zoom 12 a cell is roughly ten kilometres across.
  static const _maxCachedCells = 64;

  final Map<String, List<FieldSummary>> _cells = {};
  final Map<String, FieldSummary> _byId = {};

  /// Insertion order is the eviction order, which is what [LinkedHashMap]
  /// gives for free - a cell touched again is moved back to the end.
  final List<String> _cellOrder = [];

  void rebuild(Iterable<FieldSummary> fields) {
    _cells.clear();
    _byId.clear();
    _cellOrder.clear();
    for (final field in fields) {
      _insert(field);
    }
  }

  /// Replaces one cell wholesale with what the store returned for it. Marking
  /// the cell present matters even when it is empty, otherwise an area with no
  /// fields would be re-queried on every pan across it.
  void putCell(String key, Iterable<FieldSummary> fields) {
    final existing = _cells[key];
    if (existing != null) {
      for (final field in existing) {
        _byId.remove(field.id);
      }
    }
    _cells[key] = [...fields];
    for (final field in fields) {
      _byId[field.id] = field;
    }
    _touch(key);
    _evictIfNeeded();
  }

  bool hasCell(String key) => _cells.containsKey(key);

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

  FieldSummary? byId(String id) => _byId[id];

  List<FieldSummary> cell(String key) => _cells[key] ?? const [];

  /// The grid is also the storage layout: the store keeps one row per object
  /// keyed by cell, so a viewport asks for a handful of cells rather than
  /// scanning everything. The zoom is part of the key, so changing it
  /// invalidates old entries instead of silently mixing two grids.
  static String cellKey(LatLng point) {
    final x = TileMath.lonToTileX(point.longitude, _gridZoom);
    final y = TileMath.latToTileY(point.latitude, _gridZoom);
    return 'z$_gridZoom/${x}_$y';
  }

  static String cellKeyOf(FieldSummary field) => cellKey(field.centroid);

  /// Every cell a viewport touches, as both the cache key and the packed
  /// integer the store indexes on.
  static List<({String key, int packed})> cellsFor(LatLngBounds bounds) {
    final xMin = TileMath.lonToTileX(bounds.west, _gridZoom);
    final xMax = TileMath.lonToTileX(bounds.east, _gridZoom);
    final yMin = TileMath.latToTileY(bounds.north, _gridZoom);
    final yMax = TileMath.latToTileY(bounds.south, _gridZoom);

    return [
      for (var x = xMin; x <= xMax; x++)
        for (var y = yMin; y <= yMax; y++)
          (key: 'z$_gridZoom/${x}_$y', packed: MapObjectStore.packCell(x, y)),
    ];
  }

  List<FieldSummary> query(LatLngBounds bounds) {
    final result = <FieldSummary>[];
    for (final cell in cellsFor(bounds)) {
      final bucket = _cells[cell.key];
      if (bucket == null) continue;
      _touch(cell.key);
      result.addAll(bucket);
    }
    return result;
  }

  void _insert(FieldSummary field) {
    final key = cellKeyOf(field);
    _byId[field.id] = field;
    _cells.putIfAbsent(key, () => []).add(field);
    _touch(key);
  }

  void _removeFromCell(FieldSummary field) {
    _cells[cellKeyOf(field)]?.removeWhere((f) => f.id == field.id);
  }

  void _touch(String key) {
    _cellOrder
      ..remove(key)
      ..add(key);
  }

  void _evictIfNeeded() {
    while (_cellOrder.length > _maxCachedCells) {
      final oldest = _cellOrder.removeAt(0);
      for (final field in _cells.remove(oldest) ?? const <FieldSummary>[]) {
        _byId.remove(field.id);
      }
    }
  }
}

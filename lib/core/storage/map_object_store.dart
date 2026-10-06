import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../map/tile_math.dart';

/// What a stored object is. Persisted as an integer, so the values must never
/// be renumbered - an old database would start reading poultry farms as
/// pharmacies.
enum MapObjectKind {
  field(0),
  vetPharmacy(1),
  poultryFarm(2),
  slaughterhouse(3);

  const MapObjectKind(this.code);

  final int code;

  static MapObjectKind fromCode(int code) =>
      values.firstWhere((k) => k.code == code, orElse: () => field);
}

class StoredMapObject {
  const StoredMapObject({
    required this.id,
    required this.kind,
    required this.points,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.updatedAt,
    this.attributes,
    this.isMock = false,
  });

  final String id;
  final MapObjectKind kind;
  final List<LatLng> points;
  final String name;
  final String subtitle;
  final String status;
  final DateTime updatedAt;

  /// Whatever is specific to one kind and not worth a column - a pharmacy's
  /// licence number, a slaughterhouse's capacity. The map itself never reads it.
  final Map<String, dynamic>? attributes;

  /// Invented data, seeded so the map can be worked on before the backend
  /// serves anything. It is a column rather than a naming convention, so
  /// removing it is one indexed statement that cannot misfire on a real object
  /// whose id happens to look similar.
  final bool isMock;
}

/// Map objects live in SQLite rather than Hive because Hive has no partial
/// read: it is all in memory or nothing. A province-sized download is tens of
/// thousands of objects, and holding every polygon in the Dart heap would cost
/// a hundred megabytes and freeze the first frame while it decoded.
///
/// SQLite answers "what is on this screen" instead, so memory follows the
/// viewport rather than the download. Tokens, FCM registration and settings
/// stay in Hive, where a handful of small values is exactly what it is good at.
class MapObjectStore {
  MapObjectStore(this._db);

  final Database _db;

  static const _table = 'map_objects';

  /// The grid the cell column is built on. It has to match
  /// `FieldSpatialIndex`, so both sides bucket an object identically.
  static const gridZoom = 12;

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        id         TEXT    NOT NULL PRIMARY KEY,
        kind       INTEGER NOT NULL,
        cell       INTEGER NOT NULL,
        name       TEXT    NOT NULL,
        subtitle   TEXT    NOT NULL,
        status     TEXT    NOT NULL,
        geometry   BLOB    NOT NULL,
        min_lat    REAL    NOT NULL,
        min_lng    REAL    NOT NULL,
        max_lat    REAL    NOT NULL,
        max_lng    REAL    NOT NULL,
        attributes TEXT,
        is_mock    INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Every map query is "these cells, these kinds", so the index covers both.
    // Without it a pan is a full scan of the province.
    await db.execute(
      'CREATE INDEX idx_${_table}_cell_kind ON $_table (cell, kind)',
    );

    // Partial: it indexes only the seeded rows, so it costs nothing once real
    // data has replaced them and stays nothing in production, where no row
    // ever has the flag set.
    await db.execute(
      'CREATE INDEX idx_${_table}_mock ON $_table (is_mock) WHERE is_mock = 1',
    );
  }

  /// Packs a grid cell into one integer. Tile indices at zoom 12 fit in 12
  /// bits, so a 16-bit shift leaves room without ever colliding.
  static int packCell(int x, int y) => (x << 16) | y;

  Future<void> upsertAll(Iterable<StoredMapObject> objects) async {
    final batch = _db.batch();
    for (final object in objects) {
      batch.insert(
        _table,
        _toRow(object),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteIds(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_table, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Reads only the cells a viewport touches. This is the whole reason for
  /// SQLite being here, so callers must never widen it into "read everything".
  Future<List<StoredMapObject>> inCells(
    Iterable<int> cells, {
    Set<MapObjectKind>? kinds,
  }) async {
    final cellList = cells.toList(growable: false);
    if (cellList.isEmpty) return const [];

    final cellSlots = List.filled(cellList.length, '?').join(',');
    final args = <Object?>[...cellList];

    var where = 'cell IN ($cellSlots)';
    if (kinds != null && kinds.isNotEmpty) {
      where += ' AND kind IN (${List.filled(kinds.length, '?').join(',')})';
      args.addAll([for (final kind in kinds) kind.code]);
    }

    final rows = await _db.query(_table, where: where, whereArgs: args);
    return [for (final row in rows) _fromRow(row)];
  }

  /// The extent of everything stored, for sizing the offline tile download.
  /// Computed in SQL: loading every polygon just to take a min and a max is
  /// exactly the full read this store exists to avoid.
  Future<LatLngBounds?> boundsOfAll({Set<MapObjectKind>? kinds}) async {
    var where = '';
    final args = <Object?>[];
    if (kinds != null && kinds.isNotEmpty) {
      where = ' WHERE kind IN (${List.filled(kinds.length, '?').join(',')})';
      args.addAll([for (final kind in kinds) kind.code]);
    }

    final rows = await _db.rawQuery(
      'SELECT MIN(min_lat) AS s, MIN(min_lng) AS w, '
      'MAX(max_lat) AS n, MAX(max_lng) AS e FROM $_table$where',
      args,
    );
    final row = rows.isEmpty ? null : rows.first;
    final south = row?['s'] as double?;
    final west = row?['w'] as double?;
    final north = row?['n'] as double?;
    final east = row?['e'] as double?;
    if (south == null || west == null || north == null || east == null) {
      return null;
    }
    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM $_table'),
      ) ??
      0;

  /// Drops every seeded object in one statement. Called the moment real data
  /// arrives and again on logout, so invented polygons can never outlive the
  /// session that created them.
  Future<int> deleteMockObjects() => _db.delete(_table, where: 'is_mock = 1');

  Future<int> countMockObjects() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM $_table WHERE is_mock = 1'),
      ) ??
      0;

  Future<void> clear() => _db.delete(_table);

  Map<String, Object?> _toRow(StoredMapObject object) => {
    'id': object.id,
    'kind': object.kind.code,
    'cell': _cellOf(object.points),
    'name': object.name,
    'subtitle': object.subtitle,
    'status': object.status,
    'geometry': _encodeGeometry(object.points),
    ..._boundsColumns(object.points),
    'attributes': object.attributes == null
        ? null
        : jsonEncode(object.attributes),
    'is_mock': object.isMock ? 1 : 0,
    'updated_at': object.updatedAt.toUtc().millisecondsSinceEpoch,
  };

  StoredMapObject _fromRow(Map<String, Object?> row) {
    final rawAttributes = row['attributes'] as String?;
    return StoredMapObject(
      id: row['id']! as String,
      kind: MapObjectKind.fromCode(row['kind']! as int),
      points: _decodeGeometry(row['geometry']! as Uint8List),
      name: row['name']! as String,
      subtitle: row['subtitle']! as String,
      status: row['status']! as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
      attributes: rawAttributes == null
          ? null
          : jsonDecode(rawAttributes) as Map<String, dynamic>,
      isMock: (row['is_mock'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> _boundsColumns(List<LatLng> points) {
    if (points.isEmpty) {
      return const {
        'min_lat': 0.0,
        'min_lng': 0.0,
        'max_lat': 0.0,
        'max_lng': 0.0,
      };
    }
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return {
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
    };
  }

  int _cellOf(List<LatLng> points) {
    if (points.isEmpty) return packCell(0, 0);
    var lat = 0.0;
    var lng = 0.0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return packCell(
      TileMath.lonToTileX(lng / points.length, gridZoom),
      TileMath.latToTileY(lat / points.length, gridZoom),
    );
  }

  /// Coordinates go in as raw doubles, not JSON. A polygon is a few hundred
  /// bytes either way, but a blob needs no parsing at all - `Float64List.view`
  /// is a cast - and across a province that is the difference between a pan
  /// that stutters and one that does not.
  ///
  /// Byte order is the machine's own. That is safe only because this file never
  /// leaves the device; it is a cache, not an exchange format.
  Uint8List _encodeGeometry(List<LatLng> points) {
    final values = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      values[i * 2] = points[i].latitude;
      values[i * 2 + 1] = points[i].longitude;
    }
    return values.buffer.asUint8List();
  }

  List<LatLng> _decodeGeometry(Uint8List bytes) {
    // Copied, because a row's bytes are not guaranteed to start on an
    // eight-byte boundary and asFloat64List demands that they do.
    final values = Uint8List.fromList(bytes).buffer.asFloat64List();
    return [
      for (var i = 0; i + 1 < values.length; i += 2)
        LatLng(values[i], values[i + 1]),
    ];
  }
}

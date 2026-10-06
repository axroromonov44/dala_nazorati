import 'package:dala_nazorati/core/map/tile_math.dart';
import 'package:dala_nazorati/core/storage/map_object_store.dart';
import 'package:dala_nazorati/features/fields/data/field_mock_seeder.dart';
import 'package:dala_nazorati/features/fields/data/field_object_mapper.dart';
import 'package:dala_nazorati/features/fields/data/field_spatial_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Panning the map offline has to keep revealing objects without ever reading
/// the whole download into memory. These guard both halves of that: the store
/// answers by cell, and the index caches only what has been looked at.
void main() {
  const center = LatLng(41.311081, 69.240562); // Tashkent

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late MapObjectStore store;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => MapObjectStore.createSchema(db),
      ),
    );
    store = MapObjectStore(db);
    await store.upsertAll([
      for (final field in FieldMockSeeder.around(center))
        FieldObjectMapper.toStored(field, isMock: true),
    ]);
  });

  tearDown(() => db.close());

  group('map object store', () {
    test('reads only the cells asked for, not the whole table', () async {
      final cells = FieldSpatialIndex.cellsFor(TileMath.boundsFor(center, 600));

      final here = await store.inCells([for (final c in cells) c.packed]);

      expect(await store.count(), 140);
      expect(here, isNotEmpty);
      expect(here.length, lessThan(140));
    });

    test('survives a round trip through the geometry blob', () async {
      final original = FieldMockSeeder.around(center).first;
      final cells = FieldSpatialIndex.cellsFor(
        TileMath.boundsFor(original.centroid, 300),
      );

      final stored = await store.inCells([for (final c in cells) c.packed]);
      final match = stored.firstWhere((o) => o.id == original.id);

      expect(match.points, hasLength(original.points.length));
      expect(
        match.points.first.latitude,
        closeTo(original.points.first.latitude, 1e-12),
      );
      expect(
        match.points.first.longitude,
        closeTo(original.points.first.longitude, 1e-12),
      );
      expect(match.kind, MapObjectKind.field);
    });

    test('bounds come from SQL rather than loading every polygon', () async {
      final bounds = await store.boundsOfAll();

      expect(bounds, isNotNull);
      expect(bounds!.contains(center), isTrue);
    });

    test('dropping mock data leaves real objects untouched', () async {
      await store.upsertAll([
        FieldObjectMapper.toStored(
          FieldMockSeeder.around(center).first,
          isMock: true,
        ).copyAsReal(),
      ]);

      final removed = await store.deleteMockObjects();

      expect(removed, 140);
      expect(await store.count(), 1);
      expect(await store.countMockObjects(), 0);
    });

    test('an empty cell list reads nothing at all', () async {
      expect(await store.inCells(const []), isEmpty);
    });
  });

  group('viewport cache', () {
    test('keeps a cell that holds no objects, so it is not re-read', () {
      final index = FieldSpatialIndex()..putCell('z12/0_0', const []);

      expect(index.hasCell('z12/0_0'), isTrue);
      expect(index.cell('z12/0_0'), isEmpty);
    });

    test('drops the least recently used cells instead of growing', () {
      final index = FieldSpatialIndex();
      final fields = FieldMockSeeder.around(center);

      // Far more cells than the cache is allowed to hold.
      for (var i = 0; i < 200; i++) {
        index.putCell('z12/${i}_0', [fields[i % fields.length]]);
      }

      expect(index.hasCell('z12/0_0'), isFalse);
      expect(index.hasCell('z12/199_0'), isTrue);
    });
  });

  group('mock fields', () {
    test('are spread beyond a single viewport', () {
      final fields = FieldMockSeeder.around(center);
      final index = FieldSpatialIndex()..rebuild(fields);

      expect(fields, hasLength(140));
      expect(
        index.query(TileMath.boundsFor(center, 600)).length,
        lessThan(fields.length),
      );
    });

    test('are stable across runs, so cached tiles keep matching them', () {
      expect(
        [for (final f in FieldMockSeeder.around(center)) f.centroid.latitude],
        [for (final f in FieldMockSeeder.around(center)) f.centroid.latitude],
      );
    });

    test('are recognisable in a database dump, not only by their flag', () {
      // The is_mock column is what deletes them; the prefix is so that anyone
      // reading rows by hand can tell at a glance what they are looking at.
      expect(
        FieldMockSeeder.around(
          center,
        ).every((f) => f.id.startsWith(FieldMockSeeder.idPrefix)),
        isTrue,
      );
    });

    test(
      'are stored with the flag that logout and the first sync delete on',
      () {
        expect(
          FieldObjectMapper.toStored(
            FieldMockSeeder.around(center).first,
            isMock: true,
          ).isMock,
          isTrue,
        );
        expect(
          FieldObjectMapper.toStored(
            FieldMockSeeder.around(center).first,
          ).isMock,
          isFalse,
        );
      },
    );
  });
}

extension on StoredMapObject {
  /// A copy that dropping mock data must leave alone.
  StoredMapObject copyAsReal() => StoredMapObject(
    id: 'real-0001',
    isMock: false,
    kind: kind,
    points: points,
    name: name,
    subtitle: subtitle,
    status: status,
    updatedAt: updatedAt,
  );
}

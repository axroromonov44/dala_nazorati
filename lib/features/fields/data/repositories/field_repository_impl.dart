import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/storage/map_object_store.dart';
import '../../domain/entities/field_detail.dart';
import '../../domain/entities/field_summary.dart';
import '../../domain/repositories/field_repository.dart';
import '../datasources/field_remote_datasource.dart';
import '../field_mock_seeder.dart';
import '../field_object_mapper.dart';
import '../field_spatial_index.dart';
import '../models/field_detail_model.dart';

class FieldRepositoryImpl implements FieldRepository {
  FieldRepositoryImpl(
    this._remote,
    this._hiveService,
    this._spatialIndex,
    this._store,
  );

  final FieldRemoteDataSource _remote;
  final HiveService _hiveService;
  final FieldSpatialIndex _spatialIndex;
  final MapObjectStore _store;

  static const _kinds = {MapObjectKind.field};

  @override
  Future<void> syncIndex() async {
    final cursor = _hiveService.userBox.get(StorageKeys.fieldsIndexSyncCursor);
    final page = await _remote.fetchIndex(
      updatedAfter: cursor is String ? DateTime.tryParse(cursor) : null,
    );

    // The server never deletes invented fields, so without this they would
    // survive forever next to real ones.
    if (page.items.isNotEmpty) await _store.deleteMockObjects();

    await _store.upsertAll([
      for (final item in page.items) FieldObjectMapper.toStored(item),
    ]);
    await _store.deleteIds(page.deletedIds);

    // Cheaper than reconciling the cache cell by cell, and a sync is rare
    // enough that re-reading the visible cells costs nothing noticeable.
    _spatialIndex.rebuild(const []);

    await _hiveService.userBox.put(
      StorageKeys.fieldsIndexSyncCursor,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Fills the store with invented fields around [center] when it is empty.
  ///
  /// Gated on [kSeedMockFields] rather than on [kDebugMode] directly, because
  /// it is currently shipping in release builds on purpose. When that flag goes
  /// back to false this also removes what it seeded before, so turning it off
  /// is one edit and not a support request about stale polygons.
  @override
  Future<void> seedMockFieldsIfEmpty(LatLng center) async {
    if (!kSeedMockFields) {
      if (await _store.countMockObjects() > 0) {
        await _store.deleteMockObjects();
        _spatialIndex.rebuild(const []);
      }
      return;
    }
    if (await _store.count() > 0) return;

    await _store.upsertAll([
      for (final field in FieldMockSeeder.around(center))
        FieldObjectMapper.toStored(field, isMock: true),
    ]);
    _spatialIndex.rebuild(const []);
  }

  /// Loads the cells under [bounds] that are not cached yet, then answers from
  /// the cache. Only the missing cells are read, so panning across a province
  /// costs a few rows at a time rather than the whole download.
  @override
  Future<List<FieldSummary>> fieldsInBounds(LatLngBounds bounds) async {
    final cells = FieldSpatialIndex.cellsFor(bounds);
    final missing = [
      for (final cell in cells)
        if (!_spatialIndex.hasCell(cell.key)) cell,
    ];

    if (missing.isNotEmpty) {
      final stored = await _store.inCells([
        for (final cell in missing) cell.packed,
      ], kinds: _kinds);

      final grouped = <String, List<FieldSummary>>{
        for (final cell in missing) cell.key: [],
      };
      for (final object in stored) {
        final field = FieldObjectMapper.fromStored(object);
        grouped[FieldSpatialIndex.cellKeyOf(field)]?.add(field);
      }
      grouped.forEach(_spatialIndex.putCell);
    }

    return _spatialIndex.query(bounds);
  }

  @override
  Future<LatLngBounds?> allFieldsBounds() => _store.boundsOfAll(kinds: _kinds);

  @override
  Future<FieldDetail> getFieldDetail(String id) async {
    final cached = _hiveService.fieldDetailBox.get(id);
    try {
      final json = await _remote.fetchDetail(id);
      await _hiveService.fieldDetailBox.put(id, json);
      return FieldDetailModel.fromJson(json);
    } catch (_) {
      // A detail opened once stays readable in the field, where a request is
      // as likely to fail as to succeed.
      if (cached is Map) {
        return FieldDetailModel.fromJson(Map<String, dynamic>.from(cached));
      }
      rethrow;
    }
  }

  @override
  Future<void> clearLocalData() async {
    await _store.clear();
    await _hiveService.fieldDetailBox.clear();
    await _hiveService.userBox.delete(StorageKeys.fieldsIndexSyncCursor);
    _spatialIndex.rebuild(const []);
  }
}

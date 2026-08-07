import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/field_detail.dart';
import '../../domain/entities/field_summary.dart';
import '../../domain/repositories/field_repository.dart';
import '../datasources/field_remote_datasource.dart';
import '../field_spatial_index.dart';
import '../models/field_detail_model.dart';
import '../models/field_summary_model.dart';

class FieldRepositoryImpl implements FieldRepository {
  FieldRepositoryImpl(this._remote, this._hiveService, this._spatialIndex);

  final FieldRemoteDataSource _remote;
  final HiveService _hiveService;
  final FieldSpatialIndex _spatialIndex;

  /// Loads whatever was persisted from a previous session into the
  /// in-memory spatial index. Must run once at startup, before the map's
  /// first viewport query — the index would otherwise look empty until the
  /// first `syncIndex()` completes.
  void loadCachedIndex() {
    final fields = [
      for (final raw in _hiveService.fieldsIndexBox.values)
        FieldSummaryModel.fromJson(
          jsonDecode(raw as String) as Map<String, dynamic>,
        ),
    ];
    _spatialIndex.rebuild(fields);
  }

  @override
  Future<void> syncIndex() async {
    final cursorMs =
        _hiveService.userBox.get(StorageKeys.fieldsIndexSyncCursor) as int?;
    final cursor =
        cursorMs != null ? DateTime.fromMillisecondsSinceEpoch(cursorMs) : null;

    final page = await _remote.fetchIndex(updatedAfter: cursor);

    var newest = cursor;
    for (final item in page.items) {
      final existingRaw = _hiveService.fieldsIndexBox.get(item.id) as String?;
      if (existingRaw != null) {
        final existing = FieldSummaryModel.fromJson(
          jsonDecode(existingRaw) as Map<String, dynamic>,
        );
        // Backend may not support server-side filtering yet (see
        // FieldRemoteDataSource) and return the full list every time — this
        // check is what makes the sync a no-op for anything that hasn't
        // actually changed, rather than trusting the request param alone.
        if (!item.updatedAt.isAfter(existing.updatedAt)) continue;
      }
      await _hiveService.fieldsIndexBox.put(item.id, jsonEncode(item.toJson()));
      _spatialIndex.upsert(item);
      if (newest == null || item.updatedAt.isAfter(newest)) {
        newest = item.updatedAt;
      }
    }

    for (final id in page.deletedIds) {
      await _hiveService.fieldsIndexBox.delete(id);
      _spatialIndex.remove(id);
    }

    if (newest != null) {
      await _hiveService.userBox.put(
        StorageKeys.fieldsIndexSyncCursor,
        newest.millisecondsSinceEpoch,
      );
    }
  }

  @override
  List<FieldSummary> fieldsInBounds(LatLngBounds bounds) =>
      _spatialIndex.query(bounds);

  @override
  Future<FieldDetail> getFieldDetail(String id) async {
    final cachedRaw = _hiveService.fieldDetailBox.get(id) as String?;
    try {
      final json = await _remote.fetchDetail(id);
      final detail = FieldDetailModel.fromJson(json);
      await _hiveService.fieldDetailBox.put(id, jsonEncode(detail.toJson()));
      return detail;
    } catch (_) {
      if (cachedRaw != null) {
        return FieldDetailModel.fromJson(
          jsonDecode(cachedRaw) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }
}

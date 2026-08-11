import 'package:flutter_map/flutter_map.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/field_detail.dart';
import '../../domain/entities/field_summary.dart';
import '../../domain/repositories/field_repository.dart';
import '../datasources/field_remote_datasource.dart';
import '../field_spatial_index.dart';
import '../models/field_detail_model.dart';

class FieldRepositoryImpl implements FieldRepository {
  FieldRepositoryImpl(this._remote, this._hiveService, this._spatialIndex);

  final FieldRemoteDataSource _remote;
  final HiveService _hiveService;
  final FieldSpatialIndex _spatialIndex;

  void loadCachedIndex() {
    _spatialIndex.rebuild(const []);
  }

  @override
  Future<void> syncIndex() async {
    final page = await _remote.fetchIndex();

    for (final item in page.items) {
      _spatialIndex.upsert(item);
    }
    for (final id in page.deletedIds) {
      _spatialIndex.remove(id);
    }
  }

  @override
  List<FieldSummary> fieldsInBounds(LatLngBounds bounds) =>
      _spatialIndex.query(bounds);

  @override
  LatLngBounds? allFieldsBounds() {
    final points = [for (final field in _spatialIndex.all) ...field.points];
    return points.isEmpty ? null : LatLngBounds.fromPoints(points);
  }

  @override
  Future<FieldDetail> getFieldDetail(String id) async {
    final json = await _remote.fetchDetail(id);
    return FieldDetailModel.fromJson(json);
  }

  @override
  Future<void> clearLocalData() async {
    await _hiveService.fieldsIndexBox.clear();
    await _hiveService.fieldDetailBox.clear();
    await _hiveService.userBox.delete(StorageKeys.fieldsIndexSyncCursor);
    _spatialIndex.rebuild(const []);
  }
}

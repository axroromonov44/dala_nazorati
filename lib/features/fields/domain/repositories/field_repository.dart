import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../entities/field_detail.dart';
import '../entities/field_summary.dart';

abstract class FieldRepository {
  Future<void> syncIndex();

  /// Debug-only: invented fields around [center] when the index is empty, so
  /// the map can be worked on before the backend serves any.
  Future<void> seedMockFieldsIfEmpty(LatLng center);

  Future<List<FieldSummary>> fieldsInBounds(LatLngBounds bounds);

  Future<LatLngBounds?> allFieldsBounds();

  Future<FieldDetail> getFieldDetail(String id);

  Future<void> clearLocalData();
}

import 'package:flutter_map/flutter_map.dart';
import '../entities/field_detail.dart';
import '../entities/field_summary.dart';

abstract class FieldRepository {
  Future<void> syncIndex();

  List<FieldSummary> fieldsInBounds(LatLngBounds bounds);

  LatLngBounds? allFieldsBounds();

  Future<FieldDetail> getFieldDetail(String id);

  Future<void> clearLocalData();
}

import '../../../core/storage/map_object_store.dart';
import '../domain/entities/field_summary.dart';
import 'models/field_summary_model.dart';

/// Fields are one kind of map object among several - pharmacies, poultry farms
/// and slaughterhouses share the same table, because the map asks for all of
/// them with one viewport query.
abstract final class FieldObjectMapper {
  static StoredMapObject toStored(FieldSummary field, {bool isMock = false}) =>
      StoredMapObject(
        id: field.id,
        kind: MapObjectKind.field,
        points: field.points,
        name: field.name,
        subtitle: field.cropType,
        status: field.status,
        updatedAt: field.updatedAt,
        isMock: isMock,
      );

  static FieldSummaryModel fromStored(StoredMapObject object) =>
      FieldSummaryModel(
        id: object.id,
        points: object.points,
        name: object.name,
        cropType: object.subtitle,
        status: object.status,
        updatedAt: object.updatedAt,
      );
}

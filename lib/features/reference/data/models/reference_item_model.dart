import '../../domain/entities/reference_item.dart';

class ReferenceItemModel extends ReferenceItem {
  const ReferenceItemModel({
    required super.id,
    required super.name,
    required super.code,
    super.uniqueId,
  });

  factory ReferenceItemModel.fromJson(Map<String, dynamic> json) =>
      ReferenceItemModel(
        id: json['id'] as int,
        uniqueId: json['unique_id'] as int?,
        name: json['name'] as String,
        code: json['code'] as String,
      );

  Map<String, dynamic> toJson() => toJsonOf(this);

  /// Shared by [PlantModel]/[PestModel] to serialize their nested
  /// `type`/`propagation_type`/`distribution_zone` fields, which are typed
  /// as the plain [ReferenceItem] entity rather than this model.
  static Map<String, dynamic> toJsonOf(ReferenceItem item) => {
    'id': item.id,
    if (item.uniqueId != null) 'unique_id': item.uniqueId,
    'name': item.name,
    'code': item.code,
  };
}

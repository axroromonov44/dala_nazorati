import '../../domain/entities/plant.dart';
import '../../domain/entities/reference_item.dart';
import 'reference_item_model.dart';

/// Wire/cache format for [Plant]. The same `toJson`/`fromJson` pair parses
/// the `/reference/plants/` response and round-trips through
/// `HiveService.referenceDataBox` (stored as `jsonEncode(list of toJson)`),
/// so keep both in sync when the shape changes.
class PlantModel extends Plant {
  const PlantModel({
    required super.id,
    required super.uniqueId,
    required super.name,
    required super.code,
    required super.type,
    required super.cropTypes,
    required super.propagationType,
    required super.description,
    required super.infoLink,
    required super.images,
    required super.isActive,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as Map<String, dynamic>?;
    final rawPropagationType =
        json['propagation_type'] as Map<String, dynamic>?;
    final rawCropTypes = json['crop_types'] as List<dynamic>? ?? const [];
    final rawImages = json['images'] as List<dynamic>? ?? const [];

    return PlantModel(
      id: json['id'] as int,
      uniqueId: json['unique_id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      type: rawType == null ? null : ReferenceItemModel.fromJson(rawType),
      cropTypes: <ReferenceItem>[
        for (final item in rawCropTypes)
          ReferenceItemModel.fromJson(item as Map<String, dynamic>),
      ],
      propagationType: rawPropagationType == null
          ? null
          : ReferenceItemModel.fromJson(rawPropagationType),
      description: json['description'] as String? ?? '',
      infoLink: json['info_link'] as String?,
      images: <String>[for (final image in rawImages) image as String],
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'unique_id': uniqueId,
    'name': name,
    'code': code,
    'type': type == null ? null : ReferenceItemModel.toJsonOf(type!),
    'crop_types': [
      for (final cropType in cropTypes) ReferenceItemModel.toJsonOf(cropType),
    ],
    'propagation_type': propagationType == null
        ? null
        : ReferenceItemModel.toJsonOf(propagationType!),
    'description': description,
    'info_link': infoLink,
    'images': images,
    'is_active': isActive,
  };
}

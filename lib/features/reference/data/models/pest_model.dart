import '../../domain/entities/pest.dart';
import 'reference_item_model.dart';

/// Wire/cache format for [Pest]. The same `toJson`/`fromJson` pair parses
/// the `/reference/pests/` response and round-trips through
/// `HiveService.referenceDataBox` (stored as `jsonEncode(list of toJson)`),
/// so keep both in sync when the shape changes.
class PestModel extends Pest {
  const PestModel({
    required super.id,
    required super.uniqueId,
    required super.name,
    required super.type,
    required super.distributionZone,
    required super.description,
    required super.generation,
    required super.infoLink,
    required super.images,
    required super.havePhenology,
  });

  factory PestModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as Map<String, dynamic>?;
    final rawZone = json['distribution_zone'] as Map<String, dynamic>?;
    final rawImages = json['images'] as List<dynamic>? ?? const [];

    return PestModel(
      id: json['id'] as int,
      uniqueId: json['unique_id'] as int,
      name: json['name'] as String,
      type: rawType == null ? null : ReferenceItemModel.fromJson(rawType),
      distributionZone: rawZone == null
          ? null
          : ReferenceItemModel.fromJson(rawZone),
      description: json['description'] as String? ?? '',
      generation: json['generation'] as String? ?? '',
      infoLink: json['info_link'] as String?,
      images: <String>[
        for (final image in rawImages)
          (image as Map<String, dynamic>)['url'] as String,
      ],
      havePhenology: json['have_phenology'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'unique_id': uniqueId,
    'name': name,
    'type': type == null ? null : ReferenceItemModel.toJsonOf(type!),
    'distribution_zone': distributionZone == null
        ? null
        : ReferenceItemModel.toJsonOf(distributionZone!),
    'description': description,
    'generation': generation,
    'info_link': infoLink,
    'images': [
      for (final url in images) {'url': url},
    ],
    'have_phenology': havePhenology,
  };
}

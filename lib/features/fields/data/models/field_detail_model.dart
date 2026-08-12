import '../../domain/entities/field_detail.dart';
import 'field_summary_model.dart';

class FieldDetailModel extends FieldDetail {
  const FieldDetailModel({
    required super.summary,
    required super.description,
    required super.plantInfo,
    required super.photos,
  });

  factory FieldDetailModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? const [];
    return FieldDetailModel(
      summary: FieldSummaryModel.fromJson(json),
      description: json['description'] as String? ?? '',
      plantInfo: json['plant_info'] as String? ?? '',
      photos: [
        for (final p in rawPhotos)
          FieldPhoto(
            id: p['id'].toString(),
            remoteUrl: p['url'] as String,
            thumbUrl: p['thumb_url'] as String?,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    ...FieldSummaryModel.fromEntity(summary).toJson(),
    'description': description,
    'plant_info': plantInfo,
    'photos': [
      for (final p in photos)
        {'id': p.id, 'url': p.remoteUrl, 'thumb_url': p.thumbUrl},
    ],
  };
}

import 'package:latlong2/latlong.dart';
import '../../domain/entities/field_summary.dart';

class FieldSummaryModel extends FieldSummary {
  FieldSummaryModel({
    required super.id,
    required super.points,
    required super.name,
    required super.cropType,
    required super.status,
    required super.updatedAt,
  });

  factory FieldSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return FieldSummaryModel(
      id: json['id'].toString(),
      points: [
        for (final p in rawPoints)
          LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      name: json['name'] as String? ?? '',
      cropType: json['crop_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory FieldSummaryModel.fromEntity(FieldSummary entity) =>
      FieldSummaryModel(
        id: entity.id,
        points: entity.points,
        name: entity.name,
        cropType: entity.cropType,
        status: entity.status,
        updatedAt: entity.updatedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final p in points) [p.latitude, p.longitude],
    ],
    'name': name,
    'crop_type': cropType,
    'status': status,
    'updated_at': updatedAt.toIso8601String(),
  };
}

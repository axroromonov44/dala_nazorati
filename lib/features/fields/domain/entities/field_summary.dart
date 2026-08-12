import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class FieldSummary extends Equatable {
  FieldSummary({
    required this.id,
    required this.points,
    required this.name,
    required this.cropType,
    required this.status,
    required this.updatedAt,
  }) : centroid = _centroidOf(points);

  final String id;
  final List<LatLng> points;
  final String name;
  final String cropType;
  final String status;
  final DateTime updatedAt;

  final LatLng centroid;

  static LatLng _centroidOf(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    var lat = 0.0;
    var lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  @override
  List<Object?> get props => [id, points, name, cropType, status, updatedAt];
}

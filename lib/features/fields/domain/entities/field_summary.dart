import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// The lightweight "index" record for a single field ("dala") — just enough
/// to draw its polygon and a label on the map. Cached for every field,
/// unlike [FieldDetail] which carries the heavy stuff (photos, description)
/// and is only fetched on demand.
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

  /// Precomputed once at construction time — used as the bucketing key by
  /// `FieldSpatialIndex`, so it isn't recomputed on every viewport query.
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

import 'package:equatable/equatable.dart';

class LocationPoint extends Equatable {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.timestamp,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? timestamp;
  final bool isMocked;

  @override
  List<Object?> get props => [latitude, longitude, accuracy, timestamp, isMocked];
}

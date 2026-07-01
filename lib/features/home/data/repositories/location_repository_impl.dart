import 'dart:io';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  @override
  Future<LocationPoint> getCurrentLocation() async {
    await _ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Joylashuv aniqlanmadi (timeout)'),
    );
    return _fromPosition(position);
  }

  @override
  Stream<LocationPoint> watchLocation() async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(_fromPosition);
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Joylashuv xizmati o\'chiq');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Joylashuv ruxsati rad etilgan');
    }
  }

  LocationPoint _fromPosition(Position p) => LocationPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        timestamp: p.timestamp,
        isMocked: Platform.isAndroid && p.isMocked,
      );
}

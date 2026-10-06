import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/repositories/location_repository.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationRepositoryImpl implements LocationRepository {
  static const _timeout = Duration(seconds: 30);

  LocationSettings _locationSettings({
    int distanceFilter = 0,
    Duration interval = const Duration(seconds: 2),
  }) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        distanceFilter: distanceFilter,
        // Emit on a fixed interval (not only on movement) so mock-location
        // toggling is detected almost immediately, even when standing still.
        intervalDuration: interval,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<LocationPoint> getCurrentLocation() async {
    await _ensurePermission();
    final position =
        await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings(),
        ).timeout(
          _timeout,
          onTimeout: () => throw LocationException('locationTimeoutError'.tr()),
        );
    return _fromPosition(position);
  }

  @override
  Stream<LocationPoint> watchLocation() async* {
    await _ensurePermission();
    // distanceFilter: 0 + interval → continuous updates, so fake GPS appears the
    // moment it is enabled and the map returns the moment it is turned off.
    yield* Geolocator.getPositionStream(
      locationSettings: _locationSettings(distanceFilter: 0),
    ).map(_fromPosition);
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('locationServiceDisabledError'.tr());
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationException('locationPermissionDeniedError'.tr());
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

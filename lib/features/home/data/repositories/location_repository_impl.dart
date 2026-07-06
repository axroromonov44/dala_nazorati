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
  // A raw GPS fix without A-GPS assistance data (no internet) takes longer
  // to lock than a network-aided one, so this is more generous than the
  // 15s used previously.
  static const _timeout = Duration(seconds: 30);

  /// On Android, [AndroidSettings.forceLocationManager] bypasses Google's
  /// FusedLocationProviderClient (which blends in network/Wi-Fi based
  /// positioning and can silently return a stale or coarse fix when there is
  /// no internet) and talks to the GPS chip directly via the legacy
  /// LocationManager, so we still get a genuine satellite fix while offline.
  LocationSettings _locationSettings({int distanceFilter = 0}) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        distanceFilter: distanceFilter,
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
    final position = await Geolocator.getCurrentPosition(
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
    yield* Geolocator.getPositionStream(
      locationSettings: _locationSettings(distanceFilter: 10),
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

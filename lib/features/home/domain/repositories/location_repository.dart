import '../entities/location_point.dart';

/// Why the app cannot read a position, when it cannot. The map reacts
/// differently to each: a disabled service is one tap away from fixed, a
/// permanently denied permission needs the system settings, and a plain
/// failure is worth retrying.
enum LocationBlock { serviceDisabled, permissionDenied, permissionForever }

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.reason, this.message);

  final LocationBlock reason;
  final String message;

  @override
  String toString() => message;
}

abstract class LocationRepository {
  Future<LocationPoint> getCurrentLocation();

  Stream<LocationPoint> watchLocation();

  /// The last fix the platform still remembers, with no waiting and no radio.
  /// It is what lets the map draw immediately in a field with no signal, before
  /// a fresh fix arrives - or instead of one, if none ever does.
  Future<LocationPoint?> lastKnownLocation();

  Future<bool> isServiceEnabled();

  /// Emits whenever the device's location switch is flipped, so the map can
  /// recover by itself instead of asking the inspector to restart the app.
  Stream<bool> watchServiceEnabled();

  /// True when the inspector granted only approximate location, which Android
  /// 12 and newer let them do. Accuracy is then kilometres, not metres, which
  /// is useless for standing in a particular field.
  Future<bool> hasOnlyApproximateAccuracy();

  Future<void> openDeviceLocationSettings();

  Future<void> openAppSettings();
}

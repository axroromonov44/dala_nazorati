import '../entities/location_point.dart';

abstract class LocationRepository {
  Future<LocationPoint> getCurrentLocation();
  Stream<LocationPoint> watchLocation();
}

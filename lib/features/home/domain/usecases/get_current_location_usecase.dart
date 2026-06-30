import '../entities/location_point.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocationUseCase {
  const GetCurrentLocationUseCase(this._repository);

  final LocationRepository _repository;

  Future<LocationPoint> call() => _repository.getCurrentLocation();
}

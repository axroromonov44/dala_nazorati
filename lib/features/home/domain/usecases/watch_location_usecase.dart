import '../entities/location_point.dart';
import '../repositories/location_repository.dart';

class WatchLocationUseCase {
  const WatchLocationUseCase(this._repository);

  final LocationRepository _repository;

  Stream<LocationPoint> call() => _repository.watchLocation();
}

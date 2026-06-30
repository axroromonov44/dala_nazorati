part of 'map_bloc.dart';

sealed class MapEvent extends Equatable {
  const MapEvent();
}

final class MapLocationStarted extends MapEvent {
  const MapLocationStarted();

  @override
  List<Object> get props => [];
}

final class MapLocationUpdated extends MapEvent {
  const MapLocationUpdated(this.location);

  final LocationPoint location;

  @override
  List<Object> get props => [location];
}

final class MapLocationError extends MapEvent {
  const MapLocationError(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

part of 'map_bloc.dart';

sealed class MapState extends Equatable {
  const MapState();
}

final class MapInitial extends MapState {
  const MapInitial();

  @override
  List<Object> get props => [];
}

final class MapLocationLoading extends MapState {
  const MapLocationLoading();

  @override
  List<Object> get props => [];
}

final class MapLocationLoaded extends MapState {
  const MapLocationLoaded(this.location);

  final LocationPoint location;

  @override
  List<Object> get props => [location];
}

final class MapLocationFailure extends MapState {
  const MapLocationFailure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

final class MapFakeGpsDetected extends MapState {
  const MapFakeGpsDetected();

  @override
  List<Object> get props => [];
}

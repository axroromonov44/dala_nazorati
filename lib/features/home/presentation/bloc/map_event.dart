part of 'map_bloc.dart';

sealed class MapEvent extends Equatable {
  const MapEvent();
}

final class MapLocationStarted extends MapEvent {
  const MapLocationStarted();

  @override
  List<Object?> get props => [];
}

final class MapLocationUpdated extends MapEvent {
  const MapLocationUpdated(this.location);

  final LocationPoint location;

  @override
  List<Object?> get props => [location];
}

final class MapLocationError extends MapEvent {
  const MapLocationError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The device's location switch was flipped while the map was open.
final class MapServiceStatusChanged extends MapEvent {
  const MapServiceStatusChanged({required this.enabled});

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// The inspector asked to try again - from the banner, or after returning from
/// the system settings.
final class MapLocationRetried extends MapEvent {
  const MapLocationRetried();

  @override
  List<Object?> get props => [];
}

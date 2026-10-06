part of 'map_bloc.dart';

sealed class MapState extends Equatable {
  const MapState();
}

final class MapInitial extends MapState {
  const MapInitial();

  @override
  List<Object?> get props => [];
}

final class MapLocationLoading extends MapState {
  const MapLocationLoading();

  @override
  List<Object?> get props => [];
}

final class MapLocationLoaded extends MapState {
  const MapLocationLoaded(this.location, {this.isStale = false});

  final LocationPoint location;

  /// A remembered fix rather than a live one. The map draws the same either
  /// way; the marker tells the inspector not to trust it as their position.
  final bool isStale;

  @override
  List<Object?> get props => [location, isStale];
}

/// Something fixable is in the way. [lastKnown] lets the map still draw, so an
/// inspector with the location switch off sees their fields and a way to turn
/// it on rather than an empty error page.
final class MapLocationBlocked extends MapState {
  const MapLocationBlocked({
    required this.reason,
    required this.message,
    this.lastKnown,
  });

  final LocationBlock reason;
  final String message;
  final LocationPoint? lastKnown;

  @override
  List<Object?> get props => [reason, message, lastKnown];
}

final class MapLocationFailure extends MapState {
  const MapLocationFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class MapFakeGpsDetected extends MapState {
  const MapFakeGpsDetected();

  @override
  List<Object?> get props => [];
}

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/get_current_location_usecase.dart';
import '../../domain/usecases/watch_location_usecase.dart';

part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc(
    this._getCurrentLocationUseCase,
    this._watchLocationUseCase,
    this._locationRepository,
  ) : super(const MapInitial()) {
    on<MapLocationStarted>(_onLocationStarted);
    on<MapLocationRetried>(_onLocationStarted);
    on<MapLocationUpdated>(_onLocationUpdated);
    on<MapLocationError>(_onLocationError);
    on<MapServiceStatusChanged>(_onServiceStatusChanged);
  }

  final GetCurrentLocationUseCase _getCurrentLocationUseCase;
  final WatchLocationUseCase _watchLocationUseCase;
  final LocationRepository _locationRepository;

  StreamSubscription<LocationPoint>? _locationSubscription;
  StreamSubscription<bool>? _serviceSubscription;

  Future<void> _onLocationStarted(
    MapEvent event,
    Emitter<MapState> emit,
  ) async {
    // Watching the switch is what lets the map heal by itself. Subscribing once
    // and keeping it is deliberate: it has to survive the failure below, which
    // is the case it exists for.
    _serviceSubscription ??= _locationRepository.watchServiceEnabled().listen(
      (enabled) => add(MapServiceStatusChanged(enabled: enabled)),
    );

    // A remembered fix draws the map now, instead of after a cold GPS lock that
    // can take a minute in the open and never arrive indoors.
    final remembered = await _locationRepository.lastKnownLocation();
    if (remembered != null && state is! MapLocationLoaded) {
      emit(MapLocationLoaded(remembered, isStale: true));
    } else if (remembered == null) {
      emit(const MapLocationLoading());
    }

    try {
      final location = await _getCurrentLocationUseCase();
      emit(
        location.isMocked
            ? const MapFakeGpsDetected()
            : MapLocationLoaded(location),
      );

      await _locationSubscription?.cancel();
      _locationSubscription = _watchLocationUseCase().listen(
        (loc) => add(MapLocationUpdated(loc)),
        onError: (Object e) => add(MapLocationError(e.toString())),
      );
    } on LocationUnavailable catch (e) {
      emit(
        MapLocationBlocked(
          reason: e.reason,
          message: e.message,
          lastKnown: remembered,
        ),
      );
    } catch (e) {
      emit(MapLocationFailure(e.toString()));
    }
  }

  void _onLocationUpdated(MapLocationUpdated event, Emitter<MapState> emit) =>
      emit(
        event.location.isMocked
            ? const MapFakeGpsDetected()
            : MapLocationLoaded(event.location),
      );

  void _onLocationError(MapLocationError event, Emitter<MapState> emit) =>
      emit(MapLocationFailure(event.message));

  Future<void> _onServiceStatusChanged(
    MapServiceStatusChanged event,
    Emitter<MapState> emit,
  ) async {
    if (event.enabled) {
      add(const MapLocationRetried());
      return;
    }

    // Keep whatever position is on screen. Losing the map because the switch
    // was flipped would throw away the fields an offline inspector is reading.
    final current = state;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    emit(
      MapLocationBlocked(
        reason: LocationBlock.serviceDisabled,
        message: 'locationServiceDisabledError',
        lastKnown: switch (current) {
          MapLocationLoaded(:final location) => location,
          MapLocationBlocked(:final lastKnown) => lastKnown,
          _ => null,
        },
      ),
    );
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _serviceSubscription?.cancel();
    return super.close();
  }
}

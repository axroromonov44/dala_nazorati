import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/usecases/get_current_location_usecase.dart';
import '../../domain/usecases/watch_location_usecase.dart';

part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc(
    this._getCurrentLocationUseCase,
    this._watchLocationUseCase,
  ) : super(const MapInitial()) {
    on<MapLocationStarted>(_onLocationStarted);
    on<MapLocationUpdated>(_onLocationUpdated);
    on<MapLocationError>(_onLocationError);
  }

  final GetCurrentLocationUseCase _getCurrentLocationUseCase;
  final WatchLocationUseCase _watchLocationUseCase;
  StreamSubscription<LocationPoint>? _locationSubscription;

  Future<void> _onLocationStarted(
    MapLocationStarted event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLocationLoading());
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
        onError: (e) => add(MapLocationError(e.toString())),
      );
    } catch (e) {
      emit(MapLocationFailure(e.toString()));
    }
  }

  void _onLocationUpdated(
    MapLocationUpdated event,
    Emitter<MapState> emit,
  ) =>
      emit(
        event.location.isMocked
            ? const MapFakeGpsDetected()
            : MapLocationLoaded(event.location),
      );

  void _onLocationError(
    MapLocationError event,
    Emitter<MapState> emit,
  ) =>
      emit(MapLocationFailure(event.message));

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}

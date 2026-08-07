import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../domain/entities/field_summary.dart';
import '../../domain/repositories/field_repository.dart';

part 'fields_event.dart';
part 'fields_state.dart';

/// Fields only render once the user has zoomed in this far — mirrors the
/// `_fieldMinZoom` threshold `location_map.dart` already uses for the
/// field-level tile cache, so both "detail becomes available" cues line up.
const kFieldsMinVisibleZoom = 14.0;

/// Drives the map's field-polygon layer from viewport changes. Querying the
/// repository is a synchronous in-memory lookup (`FieldSpatialIndex`), so
/// this bloc does no I/O of its own — callers are expected to debounce
/// rapid `FieldsViewportChanged` events themselves (map pan/zoom fires far
/// more often than the polygon list actually needs to change).
class FieldsBloc extends Bloc<FieldsEvent, FieldsState> {
  FieldsBloc(this._repository) : super(const FieldsState([])) {
    on<FieldsViewportChanged>(_onViewportChanged);
  }

  final FieldRepository _repository;

  void _onViewportChanged(
    FieldsViewportChanged event,
    Emitter<FieldsState> emit,
  ) {
    if (event.zoom < kFieldsMinVisibleZoom) {
      emit(const FieldsState([]));
      return;
    }
    emit(FieldsState(_repository.fieldsInBounds(event.bounds)));
  }
}

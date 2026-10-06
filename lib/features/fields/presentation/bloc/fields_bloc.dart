import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../domain/entities/field_summary.dart';
import '../../domain/repositories/field_repository.dart';

part 'fields_event.dart';
part 'fields_state.dart';

const kFieldsMinVisibleZoom = 14.0;

class FieldsBloc extends Bloc<FieldsEvent, FieldsState> {
  FieldsBloc(this._repository) : super(const FieldsState([])) {
    // Panning emits continuously; restartable drops the queries the inspector
    // has already scrolled past instead of replaying every one of them.
    on<FieldsViewportChanged>(_onViewportChanged, transformer: restartable());
  }

  final FieldRepository _repository;

  Future<void> _onViewportChanged(
    FieldsViewportChanged event,
    Emitter<FieldsState> emit,
  ) async {
    if (event.zoom < kFieldsMinVisibleZoom) {
      emit(const FieldsState([]));
      return;
    }
    final fields = await _repository.fieldsInBounds(event.bounds);
    if (emit.isDone) return;
    emit(FieldsState(fields));
  }
}

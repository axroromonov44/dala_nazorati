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

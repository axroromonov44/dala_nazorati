part of 'fields_bloc.dart';

sealed class FieldsEvent extends Equatable {
  const FieldsEvent();
}

final class FieldsViewportChanged extends FieldsEvent {
  const FieldsViewportChanged({required this.bounds, required this.zoom});

  final LatLngBounds bounds;
  final double zoom;

  @override
  List<Object?> get props => [bounds, zoom];
}

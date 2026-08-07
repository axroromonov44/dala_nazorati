part of 'fields_bloc.dart';

class FieldsState extends Equatable {
  const FieldsState(this.fields);

  final List<FieldSummary> fields;

  @override
  List<Object?> get props => [fields];
}

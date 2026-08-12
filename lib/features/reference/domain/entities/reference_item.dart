import 'package:equatable/equatable.dart';

class ReferenceItem extends Equatable {
  const ReferenceItem({
    required this.id,
    required this.name,
    required this.code,
    this.uniqueId,
  });

  final int id;
  final int? uniqueId;
  final String name;
  final String code;

  @override
  List<Object?> get props => [id, uniqueId, name, code];
}

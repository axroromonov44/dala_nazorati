import 'package:equatable/equatable.dart';

import 'reference_item.dart';

class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.code,
    required this.type,
    required this.cropTypes,
    required this.propagationType,
    required this.description,
    required this.infoLink,
    required this.images,
    required this.isActive,
  });

  final int id;
  final int uniqueId;
  final String name;
  final String code;
  final ReferenceItem? type;
  final List<ReferenceItem> cropTypes;
  final ReferenceItem? propagationType;
  final String description;
  final String? infoLink;
  final List<String> images;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    uniqueId,
    name,
    code,
    type,
    cropTypes,
    propagationType,
    description,
    infoLink,
    images,
    isActive,
  ];
}

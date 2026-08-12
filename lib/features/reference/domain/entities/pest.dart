import 'package:equatable/equatable.dart';

import 'reference_item.dart';

class Pest extends Equatable {
  const Pest({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.type,
    required this.distributionZone,
    required this.description,
    required this.generation,
    required this.infoLink,
    required this.images,
    required this.havePhenology,
  });

  final int id;
  final int uniqueId;
  final String name;
  final ReferenceItem? type;
  final ReferenceItem? distributionZone;
  final String description;

  final String generation;
  final String? infoLink;
  final List<String> images;
  final bool havePhenology;

  @override
  List<Object?> get props => [
    id,
    uniqueId,
    name,
    type,
    distributionZone,
    description,
    generation,
    infoLink,
    images,
    havePhenology,
  ];
}

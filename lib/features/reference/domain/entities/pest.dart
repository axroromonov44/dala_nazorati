import 'package:equatable/equatable.dart';

import 'reference_item.dart';

/// A single row from `/reference/pests/` — the unified catalog covering
/// pests, weeds, diseases, nematodes and "unknown" entries (distinguished by
/// [type]), used for offline zararkunanda/kasallik identification.
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

  /// Free-form on the backend — seen as digits (`"5"`), a dash (`"-"`) or
  /// empty, so this is kept as a string rather than parsed to `int`.
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

import 'package:equatable/equatable.dart';

/// A single lookup row from the karantin.uz reference API (crop types,
/// plant types, propagation types, pest types, ...) — every list returned
/// by that API shares this `id`/`name`/`code` shape. `unique_id` is present
/// on most of these lists but not all (e.g. pest-distribution-zones omits
/// it), hence nullable.
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

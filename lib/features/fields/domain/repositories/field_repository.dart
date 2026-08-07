import 'package:flutter_map/flutter_map.dart';
import '../entities/field_detail.dart';
import '../entities/field_summary.dart';

abstract class FieldRepository {
  /// Pulls index changes since the last sync (delta if the backend supports
  /// it, full-list diff otherwise) and upserts them into the local cache.
  Future<void> syncIndex();

  /// Fields whose polygon intersects [bounds] — served entirely from the
  /// in-memory spatial index, no I/O.
  List<FieldSummary> fieldsInBounds(LatLngBounds bounds);

  /// Full detail (description, crop info, photo metadata) for one field.
  /// Serves from the local cache when offline or already fetched; otherwise
  /// fetches and caches it.
  Future<FieldDetail> getFieldDetail(String id);
}

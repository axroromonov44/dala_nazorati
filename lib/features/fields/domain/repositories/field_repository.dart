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

  /// Bounding box covering every locally-known field (from prior syncs),
  /// regardless of the current map viewport — used to size the offline
  /// tile download to the fields actually assigned to this employee (their
  /// working area/tuman), rather than an arbitrary radius around wherever
  /// they happen to be standing. `null` if no fields have been synced yet.
  LatLngBounds? allFieldsBounds();

  /// Full detail (description, crop info, photo metadata) for one field.
  /// Serves from the local cache when offline or already fetched; otherwise
  /// fetches and caches it.
  Future<FieldDetail> getFieldDetail(String id);

  /// Wipes every locally-cached field (index + detail + sync cursor) and
  /// resets the in-memory spatial index — called on logout so the next
  /// person to use this device doesn't see the previous employee's fields,
  /// and so [syncIndex] pulls everything fresh (no cursor) on next login.
  Future<void> clearLocalData();
}

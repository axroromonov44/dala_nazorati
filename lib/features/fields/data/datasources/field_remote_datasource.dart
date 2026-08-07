import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_service.dart';
import '../models/field_summary_model.dart';

/// One page/batch of index results. [deletedIds] is populated only if the
/// backend response includes a `deleted_ids` array — see the TBD note below.
class FieldIndexPage {
  const FieldIndexPage({required this.items, required this.deletedIds});

  final List<FieldSummaryModel> items;
  final List<String> deletedIds;
}

/// All network calls for the fields feature go through here — kept to two
/// methods so the (currently unconfirmed) backend contract only needs
/// updating in one place.
///
/// ASSUMPTIONS pending backend confirmation:
/// - Delta query param is `updated_after` (ISO8601). If the backend ignores
///   it and always returns the full list, `FieldRepositoryImpl.syncIndex`
///   still behaves correctly (just less bandwidth-efficient) because it
///   diffs by `updatedAt` per id rather than trusting the server filtered.
/// - Deletions are signaled via a `deleted_ids` array in the same response;
///   if the backend doesn't send one, deleted fields simply never get
///   purged locally until that's added.
/// - The list is not paginated. If the real field count needs pagination,
///   only `fetchIndex` needs a page/cursor loop — callers are unaffected.
class FieldRemoteDataSource {
  const FieldRemoteDataSource(this._dioService);

  final DioService _dioService;

  Future<FieldIndexPage> fetchIndex({DateTime? updatedAfter}) async {
    final response = await _dioService.get<Map<String, dynamic>>(
      ApiEndpoints.fields,
      queryParameters: {
        if (updatedAfter != null)
          'updated_after': updatedAfter.toIso8601String(),
      },
    );
    final data = response.data ?? const {};
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final rawDeleted = data['deleted_ids'] as List<dynamic>? ?? const [];
    return FieldIndexPage(
      items: [
        for (final item in rawItems)
          FieldSummaryModel.fromJson(item as Map<String, dynamic>),
      ],
      deletedIds: [for (final id in rawDeleted) id.toString()],
    );
  }

  Future<Map<String, dynamic>> fetchDetail(String id) async {
    final response = await _dioService.get<Map<String, dynamic>>(
      ApiEndpoints.fieldDetail(id),
    );
    return response.data!;
  }
}

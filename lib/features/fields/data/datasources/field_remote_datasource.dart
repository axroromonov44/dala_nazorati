import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_service.dart';
import '../models/field_summary_model.dart';

class FieldIndexPage {
  const FieldIndexPage({required this.items, required this.deletedIds});

  final List<FieldSummaryModel> items;
  final List<String> deletedIds;
}

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

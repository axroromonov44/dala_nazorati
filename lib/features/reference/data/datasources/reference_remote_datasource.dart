import 'package:dio/dio.dart';

import '../../../../core/constants/reference_endpoints.dart';
import '../../../../core/network/dio_debug_logger.dart';
import '../models/pest_model.dart';
import '../models/plant_model.dart';
import '../models/reference_item_model.dart';

/// Talks to the open karantin.uz reference API directly — it's public (no
/// auth token, different host than [ApiEndpoints]), so this uses its own
/// plain `Dio` instead of the app's authenticated [DioService] — including
/// its own debug logger (see [attachDebugLogger]), since without it these
/// requests are invisible in the console.
class ReferenceRemoteDataSource {
  ReferenceRemoteDataSource()
    : _dio = Dio(BaseOptions(baseUrl: ReferenceEndpoints.baseUrl)) {
    attachDebugLogger(_dio);
  }

  final Dio _dio;

  Future<List<ReferenceItemModel>> fetchCropTypes() =>
      _fetchList(ReferenceEndpoints.cropTypes);

  Future<List<ReferenceItemModel>> fetchPlantTypes() =>
      _fetchList(ReferenceEndpoints.plantTypes);

  Future<List<ReferenceItemModel>> fetchPropagationTypes() =>
      _fetchList(ReferenceEndpoints.propagationTypes);

  Future<List<ReferenceItemModel>> fetchPestTypes() =>
      _fetchList(ReferenceEndpoints.pestTypes);

  Future<List<ReferenceItemModel>> fetchPestDistributionZones() =>
      _fetchList(ReferenceEndpoints.pestDistributionZones);

  /// `/pests/` is the unified pest/weed/disease/nematode catalog — unlike
  /// `/plants/` it isn't paginated, so this is a single plain-array fetch.
  Future<List<PestModel>> fetchPests() async {
    final response = await _dio.get<List<dynamic>>(ReferenceEndpoints.pests);
    final items = response.data ?? const [];
    return [
      for (final item in items)
        PestModel.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// `/plants/` is paginated (DRF-style `count`/`next`/`results`) — this
  /// follows `next` until it's null, accumulating every page's `results`,
  /// so callers always get the full list in one call.
  Future<List<PlantModel>> fetchPlants() async {
    final items = <PlantModel>[];
    String? path = ReferenceEndpoints.plants;
    while (path != null) {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data ?? const {};
      final results = data['results'] as List<dynamic>? ?? const [];
      items.addAll([
        for (final item in results)
          PlantModel.fromJson(item as Map<String, dynamic>),
      ]);
      path = data['next'] as String?;
    }
    return items;
  }

  Future<List<ReferenceItemModel>> _fetchList(String path) async {
    final response = await _dio.get<List<dynamic>>(path);
    final items = response.data ?? const [];
    return [
      for (final item in items)
        ReferenceItemModel.fromJson(item as Map<String, dynamic>),
    ];
  }
}

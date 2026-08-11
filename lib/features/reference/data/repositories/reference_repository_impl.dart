import 'dart:convert';

import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/pest.dart';
import '../../domain/entities/plant.dart';
import '../../domain/entities/reference_item.dart';
import '../../domain/entities/reference_sync_progress.dart';
import '../../domain/repositories/reference_repository.dart';
import '../datasources/reference_remote_datasource.dart';
import '../models/pest_model.dart';
import '../models/plant_model.dart';
import '../models/reference_item_model.dart';

/// Cache-first: the karantin.uz reference catalog is stable, public data
/// (not user data, not the shaky dev field API), so every category is
/// persisted to `HiveService.referenceDataBox` as a single `jsonEncode`d
/// list and served from there until [forceRefresh] is requested — keeping
/// the pest/plant encyclopedia usable offline in the field. Only URLs are
/// cached, never image bytes.
class ReferenceRepositoryImpl implements ReferenceRepository {
  ReferenceRepositoryImpl(this._remote, this._hiveService);

  final ReferenceRemoteDataSource _remote;
  final HiveService _hiveService;

  @override
  Future<List<ReferenceItem>> getCropTypes({bool forceRefresh = false}) =>
      _cached<ReferenceItemModel>(
        'crop_types',
        _remote.fetchCropTypes,
        ReferenceItemModel.fromJson,
        (item) => item.toJson(),
        forceRefresh: forceRefresh,
      );

  @override
  Future<List<ReferenceItem>> getPlantTypes({bool forceRefresh = false}) =>
      _cached<ReferenceItemModel>(
        'plant_types',
        _remote.fetchPlantTypes,
        ReferenceItemModel.fromJson,
        (item) => item.toJson(),
        forceRefresh: forceRefresh,
      );

  @override
  Future<List<ReferenceItem>> getPropagationTypes({
    bool forceRefresh = false,
  }) => _cached<ReferenceItemModel>(
    'propagation_types',
    _remote.fetchPropagationTypes,
    ReferenceItemModel.fromJson,
    (item) => item.toJson(),
    forceRefresh: forceRefresh,
  );

  @override
  Future<List<ReferenceItem>> getPestTypes({bool forceRefresh = false}) =>
      _cached<ReferenceItemModel>(
        'pest_types',
        _remote.fetchPestTypes,
        ReferenceItemModel.fromJson,
        (item) => item.toJson(),
        forceRefresh: forceRefresh,
      );

  @override
  Future<List<ReferenceItem>> getPestDistributionZones({
    bool forceRefresh = false,
  }) => _cached<ReferenceItemModel>(
    'pest_distribution_zones',
    _remote.fetchPestDistributionZones,
    ReferenceItemModel.fromJson,
    (item) => item.toJson(),
    forceRefresh: forceRefresh,
  );

  @override
  Future<List<Plant>> getPlants({bool forceRefresh = false}) =>
      _cached<PlantModel>(
        'plants',
        _remote.fetchPlants,
        PlantModel.fromJson,
        (item) => item.toJson(),
        forceRefresh: forceRefresh,
      );

  @override
  Future<List<Pest>> getPests({bool forceRefresh = false}) =>
      _cached<PestModel>(
        'pests',
        _remote.fetchPests,
        PestModel.fromJson,
        (item) => item.toJson(),
        forceRefresh: forceRefresh,
      );

  /// Order the post-login sync dialog walks through, and the source of
  /// truth for the cache keys used by [_cached] above.
  static const List<String> _catalogKeys = [
    'crop_types',
    'plant_types',
    'propagation_types',
    'pest_types',
    'pest_distribution_zones',
    'plants',
    'pests',
  ];

  @override
  bool isCatalogCached() =>
      _catalogKeys.every(_hiveService.referenceDataBox.containsKey);

  @override
  Stream<ReferenceSyncProgress> syncCatalog({
    bool forceRefresh = false,
  }) async* {
    final statuses = {
      for (final key in _catalogKeys) key: ReferenceSyncStepStatus.pending,
    };
    for (final key in _catalogKeys) {
      statuses[key] = ReferenceSyncStepStatus.running;
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
      try {
        await _runCatalogStep(key, forceRefresh);
        statuses[key] = ReferenceSyncStepStatus.success;
      } catch (_) {
        statuses[key] = ReferenceSyncStepStatus.error;
      }
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
    }
    yield ReferenceSyncProgress(statuses: Map.of(statuses), done: true);
  }

  Future<void> _runCatalogStep(String key, bool forceRefresh) {
    switch (key) {
      case 'crop_types':
        return getCropTypes(forceRefresh: forceRefresh);
      case 'plant_types':
        return getPlantTypes(forceRefresh: forceRefresh);
      case 'propagation_types':
        return getPropagationTypes(forceRefresh: forceRefresh);
      case 'pest_types':
        return getPestTypes(forceRefresh: forceRefresh);
      case 'pest_distribution_zones':
        return getPestDistributionZones(forceRefresh: forceRefresh);
      case 'plants':
        return getPlants(forceRefresh: forceRefresh);
      case 'pests':
        return getPests(forceRefresh: forceRefresh);
      default:
        throw StateError('Unknown reference catalog key: $key');
    }
  }

  Future<List<M>> _cached<M>(
    String key,
    Future<List<M>> Function() fetch,
    M Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(M) toJson, {
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = _hiveService.referenceDataBox.get(key) as String?;
      if (cachedRaw != null) {
        final rawList = jsonDecode(cachedRaw) as List<dynamic>;
        return [
          for (final item in rawList) fromJson(item as Map<String, dynamic>),
        ];
      }
    }
    final items = await fetch();
    await _hiveService.referenceDataBox.put(
      key,
      jsonEncode([for (final item in items) toJson(item)]),
    );
    return items;
  }
}

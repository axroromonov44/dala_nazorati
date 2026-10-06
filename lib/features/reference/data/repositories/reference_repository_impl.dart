import 'dart:async';
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
import '../reference_image_cache.dart';

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

  /// The five small lookup lists. They do not depend on each other, so they are
  /// fetched together instead of one round trip after another.
  static const List<String> _lookupKeys = [
    'crop_types',
    'plant_types',
    'propagation_types',
    'pest_types',
    'pest_distribution_zones',
  ];

  /// Everything after the lookups has to stay in order: the image URLs only
  /// exist once plants and pests have been fetched.
  static const List<String> _sequentialKeys = ['plants', 'pests', 'images'];

  static const List<String> _catalogKeys = [..._lookupKeys, ..._sequentialKeys];

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
    // The lookups still go out all at once, but they are reported one at a
    // time and in order, so the dialog shows a single spinner walking down the
    // list instead of five rows spinning together. This costs no time: the
    // requests are already in flight, and a lookup that answered early simply
    // ticks over the moment the row above it does.
    final lookupResults = {
      for (final key in _lookupKeys)
        key: _runCatalogStep(key, forceRefresh).drain<void>().then(
          (_) => ReferenceSyncStepStatus.success,
          onError: (_) => ReferenceSyncStepStatus.error,
        ),
    };
    for (final key in _lookupKeys) {
      statuses[key] = ReferenceSyncStepStatus.running;
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
      statuses[key] = await lookupResults[key]!;
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
    }

    for (final key in _sequentialKeys) {
      statuses[key] = ReferenceSyncStepStatus.running;
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
      try {
        await for (final fraction in _runCatalogStep(key, forceRefresh)) {
          yield ReferenceSyncProgress(
            statuses: Map.of(statuses),
            done: false,
            activeFraction: fraction,
          );
        }
        statuses[key] = ReferenceSyncStepStatus.success;
      } catch (_) {
        statuses[key] = ReferenceSyncStepStatus.error;
      }
      yield ReferenceSyncProgress(statuses: Map.of(statuses), done: false);
    }
    yield ReferenceSyncProgress(statuses: Map.of(statuses), done: true);
  }

  /// Runs one catalog step, reporting 0..1 along the way where the step is long
  /// enough for that to mean anything (only the images are).
  Stream<double> _runCatalogStep(String key, bool forceRefresh) {
    if (key == 'images') return _downloadImages(forceRefresh: forceRefresh);
    return Stream.fromFuture(switch (key) {
      'crop_types' => getCropTypes(forceRefresh: forceRefresh),
      'plant_types' => getPlantTypes(forceRefresh: forceRefresh),
      'propagation_types' => getPropagationTypes(forceRefresh: forceRefresh),
      'pest_types' => getPestTypes(forceRefresh: forceRefresh),
      'pest_distribution_zones' => getPestDistributionZones(
        forceRefresh: forceRefresh,
      ),
      'plants' => getPlants(forceRefresh: forceRefresh),
      'pests' => getPests(forceRefresh: forceRefresh),
      _ => throw StateError('Unknown reference catalog key: $key'),
    }).map((_) => 1);
  }

  Stream<double> _downloadImages({bool forceRefresh = false}) async* {
    if (!forceRefresh && _hiveService.referenceDataBox.containsKey('images')) {
      return;
    }
    final plants = await getPlants(forceRefresh: forceRefresh);
    final pests = await getPests(forceRefresh: forceRefresh);
    final urls = {
      for (final plant in plants) ...plant.images,
      for (final pest in pests) ...pest.images,
    };

    // Bridge the cache's callback into this stream. Thousands of images would
    // otherwise rebuild the dialog thousands of times, so only whole percent
    // changes are forwarded.
    final ticks = StreamController<double>();
    var lastPercent = -1;
    final download = ReferenceImageCache.downloadAll(
      urls,
      onProgress: (done, total) {
        if (total == 0 || ticks.isClosed) return;
        final percent = (done * 100 / total).floor();
        if (percent == lastPercent) return;
        lastPercent = percent;
        ticks.add(done / total);
      },
    ).whenComplete(ticks.close);

    yield* ticks.stream;
    // Rethrows when images are still missing, so the step is marked as failed
    // and 'images' is not recorded as complete.
    await download;

    await _hiveService.referenceDataBox.put('images', 'done');
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

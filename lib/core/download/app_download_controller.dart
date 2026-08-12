import 'dart:async';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../features/reference/domain/entities/reference_sync_progress.dart';
import '../../features/reference/domain/repositories/reference_repository.dart';
import '../di/injection.dart';
import '../map/tile_cache_service.dart';
import '../notifications/app_notification.dart';
import '../notifications/notification_center.dart';

class PendingMapDownload {
  const PendingMapDownload({
    required this.jobs,
    required this.title,
    required this.body,
    required this.urlTemplate,
    required this.subdomains,
    required this.retina,
  });

  final List<TileDownloadJob> jobs;
  final String title;
  final String body;
  final String urlTemplate;
  final List<String> subdomains;
  final bool retina;
}

const mapStepKey = '__map__';

const stepLabelKeys = {
  'crop_types': 'referenceSyncCropTypes',
  'plant_types': 'referenceSyncPlantTypes',
  'propagation_types': 'referenceSyncPropagationTypes',
  'pest_types': 'referenceSyncPestTypes',
  'pest_distribution_zones': 'referenceSyncPestZones',
  'plants': 'referenceSyncPlants',
  'pests': 'referenceSyncPests',
  'images': 'referenceSyncImages',
  mapStepKey: 'referenceSyncMapStep',
};

class AppDownloadController extends ChangeNotifier {
  bool includeCatalog = false;
  PendingMapDownload? mapDownload;
  List<String> orderedKeys = [];
  Map<String, ReferenceSyncStepStatus> statuses = {};
  TileDownloadProgress? mapProgress;

  bool running = false;
  bool allDone = false;
  bool minimized = false;

  StreamSubscription<ReferenceSyncProgress>? _catalogSub;
  StreamSubscription<TileDownloadProgress>? _mapSub;
  CancelToken? _mapCancelToken;

  bool get isActive => running;

  bool get mapRunning =>
      statuses[mapStepKey] == ReferenceSyncStepStatus.running;

  bool get hasFailures =>
      statuses.values.any((status) => status == ReferenceSyncStepStatus.error);

  double get fraction {
    if (orderedKeys.isEmpty) return 1;
    final finished = statuses.values.where(
      (status) =>
          status == ReferenceSyncStepStatus.success ||
          status == ReferenceSyncStepStatus.error,
    );
    return finished.length / orderedKeys.length;
  }

  void start({required bool includeCatalog, PendingMapDownload? mapDownload}) {
    if (running) return;
    this.includeCatalog = includeCatalog;
    this.mapDownload = mapDownload;
    orderedKeys = [
      if (includeCatalog) ...stepLabelKeys.keys.where((k) => k != mapStepKey),
      if (mapDownload != null) mapStepKey,
    ];
    statuses = {
      for (final key in orderedKeys) key: ReferenceSyncStepStatus.pending,
    };
    mapProgress = null;
    allDone = false;
    minimized = false;
    running = true;
    WakelockPlus.enable();
    notifyListeners();

    if (includeCatalog) {
      _catalogSub = getIt<ReferenceRepository>().syncCatalog().listen((
        progress,
      ) {
        statuses.addAll(progress.statuses);
        notifyListeners();
        if (progress.done) _startMapPhaseIfNeeded();
      });
    } else {
      _startMapPhaseIfNeeded();
    }
  }

  void _startMapPhaseIfNeeded() {
    final map = mapDownload;
    if (map == null) {
      _finish();
      return;
    }
    statuses[mapStepKey] = ReferenceSyncStepStatus.running;
    notifyListeners();
    _mapCancelToken = CancelToken();
    _mapSub =
        TileCacheService.downloadJobs(
          jobs: map.jobs,
          urlTemplate: map.urlTemplate,
          subdomains: map.subdomains,
          retina: map.retina,
          cancelToken: _mapCancelToken,
        ).listen(
          (progress) {
            mapProgress = progress;
            notifyListeners();
          },
          onDone: () {
            statuses[mapStepKey] = ReferenceSyncStepStatus.success;
            _finish();
          },
          onError: (Object error) {
            if (error is DioException &&
                error.type == DioExceptionType.cancel) {
              return;
            }
            statuses[mapStepKey] = ReferenceSyncStepStatus.error;
            _finish();
          },
        );
  }

  void _finish() {
    allDone = true;
    WakelockPlus.disable();
    notifyListeners();
  }

  void cancelMapDownload() {
    final map = mapDownload;
    if (map == null) return;
    _mapCancelToken?.cancel();
    for (final job in map.jobs) {
      TileCacheService.markRegionDeclined(job.regionId);
    }
    NotificationCenter.add(
      OfflineDownloadNotification(
        jobs: map.jobs,
        title: map.title,
        body: map.body,
        urlTemplate: map.urlTemplate,
        subdomains: map.subdomains,
        retina: map.retina,
      ),
    );
    running = false;
    minimized = false;
    WakelockPlus.disable();
    notifyListeners();
  }

  void acknowledge() {
    running = false;
    minimized = false;
    notifyListeners();
  }

  void minimize() {
    minimized = true;
    notifyListeners();
  }

  void restore() {
    minimized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_catalogSub?.cancel());
    unawaited(_mapSub?.cancel());
    if (_mapCancelToken != null && !_mapCancelToken!.isCancelled) {
      _mapCancelToken!.cancel();
    }
    super.dispose();
  }
}

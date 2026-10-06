import 'dart:async';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../features/reference/domain/entities/reference_sync_progress.dart';
import '../../features/reference/domain/repositories/reference_repository.dart';
import '../di/injection.dart';
import '../map/tile_cache_service.dart';
import '../observability/crash_reporting.dart';
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

/// Roughly how much work each step is, so the bar tracks time rather than step
/// count. Counting steps equally made the bar jump to 63% in a second and then
/// sit there for minutes, because the images alone are ~2000 downloads while
/// the five lookup lists are one small request each.
const _stepWeights = <String, double>{
  'crop_types': 1,
  'plant_types': 1,
  'propagation_types': 1,
  'pest_types': 1,
  'pest_distribution_zones': 1,
  'plants': 3,
  'pests': 3,
  'images': 45,
  mapStepKey: 35,
};

double _weightOf(String key) => _stepWeights[key] ?? 1;

class AppDownloadController extends ChangeNotifier {
  bool includeCatalog = false;
  PendingMapDownload? mapDownload;
  List<String> orderedKeys = [];
  Map<String, ReferenceSyncStepStatus> statuses = {};
  TileDownloadProgress? mapProgress;

  /// How far the running catalog step has got, reported by the repository.
  /// Only the image step reports anything; the rest jump straight to done.
  double catalogStepFraction = 0;

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

  /// 0..1 across the whole download, weighted by how heavy each step is and
  /// including how far the running step has got.
  double get fraction {
    if (orderedKeys.isEmpty) return 1;

    var total = 0.0;
    var completed = 0.0;
    for (final key in orderedKeys) {
      final weight = _weightOf(key);
      total += weight;
      switch (statuses[key]) {
        case ReferenceSyncStepStatus.success:
        case ReferenceSyncStepStatus.error:
          completed += weight;
        case ReferenceSyncStepStatus.running:
          final within = key == mapStepKey
              ? (mapProgress?.fraction ?? 0)
              : catalogStepFraction;
          completed += weight * within.clamp(0.0, 1.0);
        case ReferenceSyncStepStatus.pending:
        case null:
          break;
      }
    }
    if (total == 0) return 1;
    return (completed / total).clamp(0.0, 1.0);
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
    catalogStepFraction = 0;
    allDone = false;
    minimized = false;
    running = true;
    WakelockPlus.enable();
    notifyListeners();

    if (includeCatalog) {
      _catalogSub = getIt<ReferenceRepository>().syncCatalog().listen((
        progress,
      ) {
        _logStepChanges(progress.statuses);
        statuses.addAll(progress.statuses);
        catalogStepFraction = progress.activeFraction;
        notifyListeners();
        if (progress.done) _startMapPhaseIfNeeded();
      });
    } else {
      _startMapPhaseIfNeeded();
    }
  }

  /// Records step transitions in the crash report. When a crash or a
  /// complaint arrives, this answers "where did the sync stop" — only the
  /// changes are logged, not every progress tick.
  void _logStepChanges(Map<String, ReferenceSyncStepStatus> incoming) {
    for (final entry in incoming.entries) {
      if (statuses[entry.key] == entry.value) continue;
      CrashReporting.log('sync: ${entry.key} -> ${entry.value.name}');
    }
  }

  void _startMapPhaseIfNeeded() {
    final map = mapDownload;
    if (map == null) {
      _finish();
      return;
    }
    statuses[mapStepKey] = ReferenceSyncStepStatus.running;
    CrashReporting.log('sync: $mapStepKey -> running');
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
          onError: (Object error, StackTrace stack) {
            if (error is DioException &&
                error.type == DioExceptionType.cancel) {
              return;
            }
            statuses[mapStepKey] = ReferenceSyncStepStatus.error;
            unawaited(
              CrashReporting.recordNonFatal(
                error,
                stack,
                reason: 'Offline map download failed',
              ),
            );
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

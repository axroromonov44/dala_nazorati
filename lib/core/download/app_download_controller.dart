import 'dart:async';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../features/reference/domain/entities/reference_sync_progress.dart';
import '../../features/reference/domain/repositories/reference_repository.dart';
import '../di/injection.dart';
import '../map/tile_cache_service.dart';
import '../observability/crash_reporting.dart';
import 'download_lifecycle.dart';
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

  final _lifecycle = DownloadLifecycle();

  /// Set when the map step failed while the app was away. The inspector never
  /// chose to stop, so it is resumed on return rather than left as an error
  /// they have to notice and retry.
  bool _resumeMapOnForeground = false;

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
    // Keeps the CPU and screen awake, which is what lets a download survive
    // the minutes right after the app is backgrounded. It is not a substitute
    // for a foreground service - the system can still cut the process off -
    // which is why the map step resumes itself below.
    WakelockPlus.enable();
    _lifecycle
      ..onResumed = _onForeground
      ..attach();
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
    _resumeMapOnForeground = false;
    _mapCancelToken = CancelToken();
    _mapSub =
        TileCacheService.downloadJobs(
          jobs: map.jobs,
          urlTemplate: map.urlTemplate,
          subdomains: map.subdomains,
          retina: map.retina,
          cancelToken: _mapCancelToken,
          lifecycle: _lifecycle,
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

            // Already-downloaded tiles come back from the cache without touching
            // the network, so resuming costs little and starting over costs the
            // whole region again.
            if (!_lifecycle.isForeground) {
              _resumeMapOnForeground = true;
              CrashReporting.log('sync: $mapStepKey interrupted in background');
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

  void _onForeground() {
    if (!_resumeMapOnForeground || !running) return;
    _resumeMapOnForeground = false;
    unawaited(_mapSub?.cancel());
    _mapSub = null;
    CrashReporting.log('sync: $mapStepKey resumed after foreground');
    _startMapPhaseIfNeeded();
  }

  void _finish() {
    allDone = true;
    _lifecycle.detach();
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
    _resumeMapOnForeground = false;
    _lifecycle.detach();
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
    _lifecycle.detach();
    unawaited(_catalogSub?.cancel());
    unawaited(_mapSub?.cancel());
    if (_mapCancelToken != null && !_mapCancelToken!.isCancelled) {
      _mapCancelToken!.cancel();
    }
    super.dispose();
  }
}

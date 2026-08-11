import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../reference/domain/entities/reference_sync_progress.dart';
import '../../../reference/domain/repositories/reference_repository.dart';

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

const _mapStepKey = '__map__';

const _stepLabelKeys = {
  'crop_types': 'referenceSyncCropTypes',
  'plant_types': 'referenceSyncPlantTypes',
  'propagation_types': 'referenceSyncPropagationTypes',
  'pest_types': 'referenceSyncPestTypes',
  'pest_distribution_zones': 'referenceSyncPestZones',
  'plants': 'referenceSyncPlants',
  'pests': 'referenceSyncPests',
  _mapStepKey: 'referenceSyncMapStep',
};

Future<void> showAppDownloadDialog(
  BuildContext context, {
  required bool includeCatalog,
  PendingMapDownload? mapDownload,
}) async {
  if (!includeCatalog && mapDownload == null) return;

  final bool? confirmed;
  if (Platform.isIOS) {
    confirmed = await _confirmDialogIOS(context, includeCatalog, mapDownload);
  } else {
    confirmed = await _confirmDialogAndroid(
      context,
      includeCatalog,
      mapDownload,
    );
  }

  if (!context.mounted) return;

  if (confirmed != true) {
    if (mapDownload != null) {
      for (final job in mapDownload.jobs) {
        await TileCacheService.markRegionDeclined(job.regionId);
      }
      NotificationCenter.add(
        OfflineDownloadNotification(
          jobs: mapDownload.jobs,
          title: mapDownload.title,
          body: mapDownload.body,
          urlTemplate: mapDownload.urlTemplate,
          subdomains: mapDownload.subdomains,
          retina: mapDownload.retina,
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  final dialog = _AppDownloadProgressDialog(
    includeCatalog: includeCatalog,
    mapDownload: mapDownload,
  );
  if (Platform.isIOS) {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  }
}

String _introTitle(bool includeCatalog, PendingMapDownload? mapDownload) =>
    includeCatalog ? 'referenceSyncIntroTitle'.tr() : mapDownload!.title;

String _introBody(bool includeCatalog, PendingMapDownload? mapDownload) =>
    includeCatalog ? 'referenceSyncIntroBody'.tr() : mapDownload!.body;

Future<bool?> _confirmDialogIOS(
  BuildContext context,
  bool includeCatalog,
  PendingMapDownload? mapDownload,
) {
  final estimate = mapDownload == null
      ? null
      : TileCacheService.estimateJobs(
          mapDownload.jobs,
          retina: mapDownload.retina,
        );
  return showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(_introTitle(includeCatalog, mapDownload)),
      ),
      content: Column(
        children: [
          Text(_introBody(includeCatalog, mapDownload)),
          if (estimate != null) ...[
            const SizedBox(height: 10),
            Text(
              'offlineMapSizeEstimate'.tr(
                namedArgs: {
                  'size': formatMapCacheSize(estimate.estimatedBytes),
                },
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeGreen,
              ),
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('offlineMapLaterAction'.tr()),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('referenceSyncContinueAction'.tr()),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDialogAndroid(
  BuildContext context,
  bool includeCatalog,
  PendingMapDownload? mapDownload,
) {
  final estimate = mapDownload == null
      ? null
      : TileCacheService.estimateJobs(
          mapDownload.jobs,
          retina: mapDownload.retina,
        );
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(
        Icons.download_for_offline_rounded,
        color: kGreen,
        size: 34,
      ),
      title: Text(
        _introTitle(includeCatalog, mapDownload),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _introBody(includeCatalog, mapDownload),
            textAlign: TextAlign.center,
          ),
          if (estimate != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kGreenSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sd_storage_rounded, size: 18, color: kGreen),
                  const SizedBox(width: 6),
                  Text(
                    'offlineMapSizeEstimate'.tr(
                      namedArgs: {
                        'size': formatMapCacheSize(estimate.estimatedBytes),
                      },
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('offlineMapLaterAction'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('referenceSyncContinueAction'.tr()),
        ),
      ],
    ),
  );
}

class _AppDownloadProgressDialog extends StatefulWidget {
  const _AppDownloadProgressDialog({
    required this.includeCatalog,
    required this.mapDownload,
  });

  final bool includeCatalog;
  final PendingMapDownload? mapDownload;

  @override
  State<_AppDownloadProgressDialog> createState() =>
      _AppDownloadProgressDialogState();
}

class _AppDownloadProgressDialogState
    extends State<_AppDownloadProgressDialog> {
  late final List<String> _orderedKeys = [
    if (widget.includeCatalog)
      ..._stepLabelKeys.keys.where((k) => k != _mapStepKey),
    if (widget.mapDownload != null) _mapStepKey,
  ];
  late final Map<String, ReferenceSyncStepStatus> _statuses = {
    for (final key in _orderedKeys) key: ReferenceSyncStepStatus.pending,
  };

  StreamSubscription<ReferenceSyncProgress>? _catalogSub;
  StreamSubscription<TileDownloadProgress>? _mapSub;
  final _mapCancelToken = CancelToken();
  TileDownloadProgress? _mapProgress;
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    if (widget.includeCatalog) {
      _catalogSub = getIt<ReferenceRepository>().syncCatalog().listen((
        progress,
      ) {
        if (!mounted) return;
        setState(() => _statuses.addAll(progress.statuses));
        if (progress.done) _startMapPhaseIfNeeded();
      });
    } else {
      _startMapPhaseIfNeeded();
    }
  }

  void _startMapPhaseIfNeeded() {
    final map = widget.mapDownload;
    if (map == null) {
      _finish();
      return;
    }
    setState(() => _statuses[_mapStepKey] = ReferenceSyncStepStatus.running);
    _mapSub =
        TileCacheService.downloadJobs(
          jobs: map.jobs,
          urlTemplate: map.urlTemplate,
          subdomains: map.subdomains,
          retina: map.retina,
          cancelToken: _mapCancelToken,
        ).listen(
          (progress) {
            if (!mounted) return;
            setState(() => _mapProgress = progress);
          },
          onDone: () {
            if (!mounted) return;
            setState(
              () => _statuses[_mapStepKey] = ReferenceSyncStepStatus.success,
            );
            _finish();
          },
          onError: (Object error) {
            if (!mounted) return;
            if (error is DioException &&
                error.type == DioExceptionType.cancel) {
              return;
            }
            setState(
              () => _statuses[_mapStepKey] = ReferenceSyncStepStatus.error,
            );
            _finish();
          },
        );
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _allDone = true);
    if (!_hasFailures) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  bool get _hasFailures =>
      _statuses.values.any((status) => status == ReferenceSyncStepStatus.error);

  bool get _mapRunning =>
      _statuses[_mapStepKey] == ReferenceSyncStepStatus.running;

  double get _fraction {
    if (_orderedKeys.isEmpty) return 1;
    final finished = _statuses.values.where(
      (status) =>
          status == ReferenceSyncStepStatus.success ||
          status == ReferenceSyncStepStatus.error,
    );
    return finished.length / _orderedKeys.length;
  }

  void _cancelMapDownload() {
    final map = widget.mapDownload;
    if (map == null) return;
    _mapCancelToken.cancel();
    Navigator.of(context).pop();
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
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    unawaited(_catalogSub?.cancel());
    unawaited(_mapSub?.cancel());
    if (!_mapCancelToken.isCancelled) _mapCancelToken.cancel();
    super.dispose();
  }

  Widget _stepIcon(ReferenceSyncStepStatus status, ColorScheme colorScheme) {
    switch (status) {
      case ReferenceSyncStepStatus.pending:
        return Icon(
          Icons.circle_outlined,
          size: 18,
          color: colorScheme.outlineVariant,
        );
      case ReferenceSyncStepStatus.running:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: kGreen),
        );
      case ReferenceSyncStepStatus.success:
        return const Icon(Icons.check_circle_rounded, size: 22, color: kGreen);
      case ReferenceSyncStepStatus.error:
        return Icon(Icons.error_rounded, size: 22, color: colorScheme.error);
    }
  }

  Widget _buildContent(BuildContext context, {required bool isIOS}) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = [
      for (final key in _orderedKeys)
        EasyStep(
          customStep: _stepIcon(
            _statuses[key] ?? ReferenceSyncStepStatus.pending,
            colorScheme,
          ),
          title: (_stepLabelKeys[key] ?? key).tr(),
        ),
    ];
    final runningIndex = _orderedKeys.indexWhere(
      (key) => _statuses[key] == ReferenceSyncStepStatus.running,
    );
    final activeStep = runningIndex == -1 ? _orderedKeys.length : runningIndex;
    final secondaryColor = isIOS
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : colorScheme.onSurfaceVariant;
    final errorColor = isIOS ? CupertinoColors.systemRed : colorScheme.error;

    // Tall enough for every step to be visible at once — no internal
    // scrolling — regardless of how many are in play (7 catalog steps,
    // +1 more when a map download is folded in).
    final stepperHeight = _orderedKeys.length * 58.0 + 20;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.maxFinite,
            height: stepperHeight,
            child: EasyStepper(
              activeStep: activeStep,
              direction: Axis.vertical,
              alignment: Alignment.topLeft,
              verticalAlignment: CrossAxisAlignment.start,
              stepRadius: 14,
              internalPadding: 6,
              showLoadingAnimation: false,
              showStepBorder: false,
              enableStepTapping: false,
              steppingEnabled: false,
              activeStepBackgroundColor: Colors.transparent,
              finishedStepBackgroundColor: Colors.transparent,
              unreachedStepBackgroundColor: Colors.transparent,
              lineStyle: LineStyle(
                lineLength: 18,
                defaultLineColor: colorScheme.outlineVariant,
                finishedLineColor: kGreen,
              ),
              steps: steps,
            ),
          ),
          const SizedBox(height: 12),
          isIOS
              ? _CupertinoProgressBar(
                  value: _fraction,
                  color: _hasFailures
                      ? CupertinoColors.systemRed
                      : CupertinoColors.activeGreen,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _fraction,
                    minHeight: 8,
                  ),
                ),
          const SizedBox(height: 6),
          Text(
            'referenceSyncProgress'.tr(
              namedArgs: {'percent': '${(_fraction * 100).round()}'},
            ),
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
          if (_mapRunning && _mapProgress != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'offlineMapProgress'.tr(
                  namedArgs: {
                    'percent': (_mapProgress!.fraction * 100).toStringAsFixed(
                      0,
                    ),
                    'size': formatMapCacheSize(_mapProgress!.downloadedBytes),
                  },
                ),
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ),
          if (_hasFailures)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'referenceSyncFailedNotice'.tr(),
                style: TextStyle(color: errorColor, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Platform.isIOS ? _buildIOS(context) : _buildAndroid(context),
  );

  Widget _buildAndroid(BuildContext context) => AlertDialog(
    title: Text('referenceSyncTitle'.tr()),
    // Wider than AlertDialog's default content width, so step titles have
    // room to sit on one line instead of wrapping and eating extra height.
    content: SizedBox(
      width: (MediaQuery.of(context).size.width - 64).clamp(280.0, 420.0),
      child: _buildContent(context, isIOS: false),
    ),
    actions: [
      if (_mapRunning)
        TextButton(
          onPressed: _cancelMapDownload,
          child: Text('offlineMapCancel'.tr()),
        ),
      if (_allDone && _hasFailures)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('referenceSyncClose'.tr()),
        ),
    ],
  );

  Widget _buildIOS(BuildContext context) => CupertinoAlertDialog(
    title: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('referenceSyncTitle'.tr()),
    ),
    content: _buildContent(context, isIOS: true),
    actions: [
      if (_mapRunning)
        CupertinoDialogAction(
          onPressed: _cancelMapDownload,
          child: Text('offlineMapCancel'.tr()),
        ),
      if (_allDone && _hasFailures)
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text('referenceSyncClose'.tr()),
        ),
    ],
  );
}

class _CupertinoProgressBar extends StatelessWidget {
  const _CupertinoProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      height: 6,
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 6,
          color: color,
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';

Future<void> showOfflineMapDownloadDialog(
  BuildContext context, {
  required List<TileDownloadJob> jobs,
  required String title,
  required String body,
  required String urlTemplate,
  required List<String> subdomains,
  required bool retina,
}) async {
  final estimate = TileCacheService.estimateJobs(jobs, retina: retina);
  if (!context.mounted) return;

  final bool? confirmed;
  if (Platform.isIOS) {
    confirmed = await _confirmDialogIOS(
      context,
      title,
      body,
      estimate.estimatedBytes,
    );
  } else {
    confirmed = await _confirmDialogAndroid(
      context,
      title,
      body,
      estimate.estimatedBytes,
    );
  }

  if (!context.mounted) return;

  if (confirmed != true) {
    for (final job in jobs) {
      await TileCacheService.markRegionDeclined(job.regionId);
    }
    NotificationCenter.add(
      OfflineDownloadNotification(
        jobs: jobs,
        title: title,
        body: body,
        urlTemplate: urlTemplate,
        subdomains: subdomains,
        retina: retina,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  await showOfflineDownloadProgress(
    context,
    jobs: jobs,
    title: title,
    body: body,
    urlTemplate: urlTemplate,
    subdomains: subdomains,
    retina: retina,
  );
}

Future<void> showOfflineDownloadProgress(
  BuildContext context, {
  required List<TileDownloadJob> jobs,
  required String title,
  required String body,
  required String urlTemplate,
  required List<String> subdomains,
  required bool retina,
}) async {
  final progressDialog = _DownloadProgressDialog(
    jobs: jobs,
    title: title,
    body: body,
    urlTemplate: urlTemplate,
    subdomains: subdomains,
    retina: retina,
  );

  if (Platform.isIOS) {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => progressDialog,
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => progressDialog,
    );
  }
}

Future<bool?> _confirmDialogIOS(
  BuildContext context,
  String title,
  String body,
  int estimatedBytes,
) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title),
      ),
      content: Column(
        children: [
          Text(body),
          const SizedBox(height: 10),
          Text(
            'offlineMapSizeEstimate'.tr(
              namedArgs: {'size': formatMapCacheSize(estimatedBytes)},
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: CupertinoColors.activeGreen,
            ),
          ),
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
          child: Text('offlineMapDownloadAction'.tr()),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDialogAndroid(
  BuildContext context,
  String title,
  String body,
  int estimatedBytes,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(
        Icons.download_for_offline_rounded,
        color: kGreen,
        size: 34,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body, textAlign: TextAlign.center),
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
                    namedArgs: {'size': formatMapCacheSize(estimatedBytes)},
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
          child: Text('offlineMapDownloadAction'.tr()),
        ),
      ],
    ),
  );
}

class _DownloadProgressDialog extends StatefulWidget {
  const _DownloadProgressDialog({
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

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  final _cancelToken = CancelToken();
  StreamSubscription<TileDownloadProgress>? _sub;
  TileDownloadProgress _progress = const TileDownloadProgress(
    downloadedTiles: 0,
    totalTiles: 0,
    downloadedBytes: 0,
  );
  bool _done = false;
  bool _failed = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sub =
        TileCacheService.downloadJobs(
          jobs: widget.jobs,
          urlTemplate: widget.urlTemplate,
          subdomains: widget.subdomains,
          retina: widget.retina,
          cancelToken: _cancelToken,
        ).listen(
          (progress) {
            if (!mounted || _cancelled) return;
            setState(() => _progress = progress);
          },
          onDone: () {
            if (!mounted || _cancelled) return;
            setState(() => _done = true);
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) Navigator.of(context).pop();
            });
          },
          onError: (Object error) {
            if (!mounted || _cancelled) return;
            if (error is DioException && error.type == DioExceptionType.cancel)
              return;
            setState(() => _failed = true);
          },
        );
  }

  void _cancel() {
    setState(() => _cancelled = true);
    _cancelToken.cancel();
    Navigator.of(context).pop();

    for (final job in widget.jobs) {
      TileCacheService.markRegionDeclined(job.regionId);
    }
    NotificationCenter.add(
      OfflineDownloadNotification(
        jobs: widget.jobs,
        title: widget.title,
        body: widget.body,
        urlTemplate: widget.urlTemplate,
        subdomains: widget.subdomains,
        retina: widget.retina,
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _sub?.cancel();
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    super.dispose();
  }

  String get _titleText => _failed
      ? 'offlineMapFailed'.tr()
      : _done
      ? 'offlineMapSuccess'.tr(
          namedArgs: {'size': formatMapCacheSize(_progress.downloadedBytes)},
        )
      : 'offlineMapDownloading'.tr();

  double get _fraction {
    final total = _progress.totalTiles;
    return total == 0
        ? 0.0
        : (_progress.downloadedTiles / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Platform.isIOS ? _buildIOS(context) : _buildAndroid(context),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    final total = _progress.totalTiles;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_titleText, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _failed || total == 0 ? null : _fraction,
              minHeight: 8,
              backgroundColor: kGreenSurface,
              valueColor: AlwaysStoppedAnimation(_failed ? kError : kGreen),
            ),
          ),
          const SizedBox(height: 10),
          if (!_failed)
            Text(
              'offlineMapProgress'.tr(
                namedArgs: {
                  'percent': (_fraction * 100).toStringAsFixed(0),
                  'size': formatMapCacheSize(_progress.downloadedBytes),
                },
              ),
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
        ],
      ),
      actions: [
        if (!_done && !_failed)
          TextButton(onPressed: _cancel, child: Text('offlineMapCancel'.tr())),
        if (_failed)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr()),
          ),
      ],
    );
  }

  Widget _buildIOS(BuildContext context) {
    return CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(_titleText),
      ),
      content: Column(
        children: [
          _CupertinoProgressBar(
            value: _failed ? 0 : _fraction,
            color: _failed
                ? CupertinoColors.systemRed
                : CupertinoColors.activeGreen,
          ),
          const SizedBox(height: 8),
          if (!_failed)
            Text(
              'offlineMapProgress'.tr(
                namedArgs: {
                  'percent': (_fraction * 100).toStringAsFixed(0),
                  'size': formatMapCacheSize(_progress.downloadedBytes),
                },
              ),
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 13,
              ),
            ),
        ],
      ),
      actions: [
        if (!_done && !_failed)
          CupertinoDialogAction(
            onPressed: _cancel,
            child: Text('offlineMapCancel'.tr()),
          ),
        if (_failed)
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr()),
          ),
      ],
    );
  }
}

class _CupertinoProgressBar extends StatelessWidget {
  const _CupertinoProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
}

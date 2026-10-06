import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/download/app_download_controller.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../reference/domain/entities/reference_sync_progress.dart';

double _dialogContentWidth(BuildContext context) =>
    (MediaQuery.of(context).size.width - 40).clamp(320.0, 480.0);

const _countdownDuration = Duration(seconds: 5);

Future<T?> _showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return Platform.isIOS
      ? showCupertinoDialog<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: builder,
        )
      : showDialog<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: builder,
        );
}

Future<void> showAppDownloadDialog(
  BuildContext context, {
  required bool includeCatalog,
  PendingMapDownload? mapDownload,
}) async {
  if (!includeCatalog && mapDownload == null) return;
  if (getIt<AppDownloadController>().isActive) return;

  final confirmed = await _showAppDialog<bool>(
    context,
    builder: (_) => _ConfirmDownloadDialog(
      includeCatalog: includeCatalog,
      mapDownload: mapDownload,
    ),
  );

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

  getIt<AppDownloadController>().start(
    includeCatalog: includeCatalog,
    mapDownload: mapDownload,
  );
  if (!context.mounted) return;
  await showAppDownloadProgressDialog(context);
}

Future<void> showAppDownloadProgressDialog(BuildContext context) async {
  getIt<AppDownloadController>().restore();
  await _showAppDialog<void>(
    context,
    barrierDismissible: false,
    builder: (_) => const _AppDownloadProgressDialog(),
  );
}

String _introTitle(bool includeCatalog, PendingMapDownload? mapDownload) =>
    includeCatalog ? 'referenceSyncIntroTitle'.tr() : mapDownload!.title;

String _introBody(bool includeCatalog, PendingMapDownload? mapDownload) =>
    includeCatalog ? 'referenceSyncIntroBody'.tr() : mapDownload!.body;

class _ConfirmDownloadDialog extends StatefulWidget {
  const _ConfirmDownloadDialog({
    required this.includeCatalog,
    required this.mapDownload,
  });

  final bool includeCatalog;
  final PendingMapDownload? mapDownload;

  @override
  State<_ConfirmDownloadDialog> createState() => _ConfirmDownloadDialogState();
}

class _ConfirmDownloadDialogState extends State<_ConfirmDownloadDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: _countdownDuration,
  )..forward();

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = widget.mapDownload == null
        ? null
        : TileCacheService.estimateJobs(
            widget.mapDownload!.jobs,
            retina: widget.mapDownload!.retina,
          );
    final width = _dialogContentWidth(context);

    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, _) {
        final secondsLeft =
            (_countdownDuration.inSeconds * (1 - _countdown.value))
                .ceil()
                .clamp(0, _countdownDuration.inSeconds);
        final content = _ConfirmBody(
          includeCatalog: widget.includeCatalog,
          mapDownload: widget.mapDownload,
          estimate: estimate,
          countdownProgress: _countdown.value,
          secondsLeft: secondsLeft,
        );
        final onContinue = _countdown.isCompleted
            ? () => Navigator.of(context).pop(true)
            : null;

        if (Platform.isIOS) {
          return _CupertinoDialogShell(
            width: width,
            content: content,
            actions: [
              _DialogAction(
                label: 'referenceSyncContinueAction'.tr(),
                isDefault: true,
                onPressed: onContinue,
              ),
            ],
          );
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(width: width, child: content),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                onPressed: onContinue,
                child: Text('referenceSyncContinueAction'.tr()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.includeCatalog,
    required this.mapDownload,
    required this.estimate,
    required this.countdownProgress,
    required this.secondsLeft,
  });

  final bool includeCatalog;
  final PendingMapDownload? mapDownload;
  final ({int tileCount, int estimatedBytes})? estimate;
  final double countdownProgress;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountdownRing(progress: countdownProgress, secondsLeft: secondsLeft),
        kVerticalSpace12,
        Text(
          _introTitle(includeCatalog, mapDownload),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        kVerticalSpace8,
        Text(
          _introBody(includeCatalog, mapDownload),
          textAlign: TextAlign.center,
        ),
        if (estimate != null) ...[
          kVerticalSpace16,
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
                kHorizontalSpace8,
                Text(
                  'offlineMapSizeEstimate'.tr(
                    namedArgs: {
                      'size': formatMapCacheSize(estimate!.estimatedBytes),
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
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.progress, required this.secondsLeft});

  final double progress;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft <= 0) {
      return const Icon(Icons.check_circle_rounded, color: kGreen, size: 36);
    }
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: kGreenSurface,
              valueColor: const AlwaysStoppedAnimation(kGreen),
            ),
          ),
          Text(
            '$secondsLeft',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kGreen,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
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

class _AppDownloadProgressDialog extends StatelessWidget {
  const _AppDownloadProgressDialog();

  void _minimize(BuildContext context, AppDownloadController controller) {
    controller.minimize();
    Navigator.of(context).pop();
  }

  void _cancel(BuildContext context, AppDownloadController controller) {
    controller.cancelMapDownload();
    Navigator.of(context).pop();
  }

  void _acknowledge(BuildContext context, AppDownloadController controller) {
    controller.acknowledge();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = getIt<AppDownloadController>();
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final titleKey = controller.allDone && !controller.hasFailures
              ? 'referenceSyncDone'
              : 'referenceSyncTitle';
          final width = _dialogContentWidth(context);
          final content = controller.allDone && !controller.hasFailures
              ? const _SuccessContent()
              : _ProgressContent(controller: controller);

          final actions = <_DialogAction>[
            if (controller.mapRunning && !controller.allDone)
              _DialogAction(
                label: 'offlineMapCancel'.tr(),
                onPressed: () => _cancel(context, controller),
              ),
            if (controller.allDone)
              _DialogAction(
                label:
                    (controller.hasFailures
                            ? 'referenceSyncClose'
                            : 'referenceSyncContinueAction')
                        .tr(),
                isDefault: true,
                isDestructive: controller.hasFailures,
                onPressed: () => _acknowledge(context, controller),
              ),
          ];

          final title = Row(
            children: [
              Expanded(
                child: Text(
                  titleKey.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
              if (!controller.allDone)
                _MinimizeButton(
                  onPressed: () => _minimize(context, controller),
                ),
            ],
          );

          if (Platform.isIOS) {
            return _CupertinoDialogShell(
              width: width,
              title: title,
              content: content,
              actions: actions,
            );
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: title,
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            content: SizedBox(width: width, child: content),
            actions: [
              for (final action in actions)
                action.isDefault
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: action.isDestructive
                              ? Theme.of(context).colorScheme.error
                              : kGreen,
                        ),
                        onPressed: action.onPressed,
                        child: Text(action.label),
                      )
                    : TextButton(
                        onPressed: action.onPressed,
                        child: Text(action.label),
                      ),
            ],
          );
        },
      ),
    );
  }
}

class _MinimizeButton extends StatelessWidget {
  const _MinimizeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const size = 32.0;
    return Platform.isIOS
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGreenSurface,
                ),
                child: Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 16,
                  color: kGreen,
                ),
              ),
            ),
          )
        : Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: const SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGreenSurface,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: kGreen,
                  ),
                ),
              ),
            ),
          );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: kGreenSurface,
          ),
          alignment: Alignment.center,
          child: Icon(
            Platform.isIOS ? CupertinoIcons.checkmark_alt : Icons.check_rounded,
            color: kGreen,
            size: 40,
          ),
        ),
        kVerticalSpace16,
        Text(
          'referenceSyncDoneBody'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.controller});

  final AppDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = colorScheme.onSurfaceVariant;
    final percent = (controller.fraction * 100).clamp(0, 100).round();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepList(controller: controller),
            kVerticalSpace12,
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: controller.fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, _) =>
                    LinearProgressIndicator(value: value, minHeight: 8),
              ),
            ),
            kVerticalSpace4,
            Text(
              'referenceSyncProgress'.tr(namedArgs: {'percent': '$percent'}),
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
            if (controller.mapRunning && controller.mapProgress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'offlineMapProgress'.tr(
                    namedArgs: {
                      'percent': (controller.mapProgress!.fraction * 100)
                          .toStringAsFixed(0),
                      'size': formatMapCacheSize(
                        controller.mapProgress!.downloadedBytes,
                      ),
                    },
                  ),
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
              ),
            if (controller.hasFailures)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'referenceSyncFailedNotice'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The vertical list of catalog steps.
///
/// Written by hand rather than with a stepper package because the labels are
/// long sentences in three languages ("Zararkunanda va kasalliklar
/// maʼlumotnomasi"): the label has to wrap inside the dialog instead of running
/// off its right edge.
class _StepList extends StatelessWidget {
  const _StepList({required this.controller});

  final AppDownloadController controller;

  static const _iconSlot = 28.0;
  static const _connectorHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keys = controller.orderedKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < keys.length; i++)
          _StepRow(
            label: (stepLabelKeys[keys[i]] ?? keys[i]).tr(),
            status:
                controller.statuses[keys[i]] ?? ReferenceSyncStepStatus.pending,
            isLast: i == keys.length - 1,
            colorScheme: colorScheme,
            iconSlot: _iconSlot,
            connectorHeight: _connectorHeight,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.status,
    required this.isLast,
    required this.colorScheme,
    required this.iconSlot,
    required this.connectorHeight,
  });

  final String label;
  final ReferenceSyncStepStatus status;
  final bool isLast;
  final ColorScheme colorScheme;
  final double iconSlot;
  final double connectorHeight;

  @override
  Widget build(BuildContext context) {
    final done =
        status == ReferenceSyncStepStatus.success ||
        status == ReferenceSyncStepStatus.error;
    final isPending = status == ReferenceSyncStepStatus.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(
                width: iconSlot,
                height: iconSlot,
                child: Center(child: _stepIcon(status, colorScheme)),
              ),
              // The connector stretches with the row, so a label that wraps to
              // two lines keeps the line unbroken down to the next step.
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: BoxConstraints(minHeight: connectorHeight),
                    color: done ? kGreen : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          kHorizontalSpace12,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 4,
                bottom: isLast ? 0 : connectorHeight,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: status == ReferenceSyncStepStatus.running
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: switch (status) {
                    ReferenceSyncStepStatus.running => kGreen,
                    ReferenceSyncStepStatus.error => colorScheme.error,
                    _ =>
                      isPending
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogAction {
  const _DialogAction({
    required this.label,
    required this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDefault;
  final bool isDestructive;
}

class _CupertinoDialogShell extends StatelessWidget {
  const _CupertinoDialogShell({
    required this.width,
    this.title,
    required this.content,
    required this.actions,
  });

  final double width;
  final Widget? title;
  final Widget content;
  final List<_DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: width,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontFamily: '.SF Pro Text',
                      ),
                      textAlign: TextAlign.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null) ...[title!, kVerticalSpace8],
                          content,
                        ],
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    Container(height: 0.5, color: separatorColor),
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0)
                              Container(width: 0.5, color: separatorColor),
                            Expanded(
                              child: _CupertinoActionButton(action: actions[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoActionButton extends StatelessWidget {
  const _CupertinoActionButton({required this.action});

  final _DialogAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final color = !enabled
        ? CupertinoColors.quaternaryLabel.resolveFrom(context)
        : action.isDestructive
        ? CupertinoColors.destructiveRed.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      onPressed: action.onPressed,
      child: Text(
        action.label,
        style: TextStyle(
          color: color,
          fontWeight: action.isDefault ? FontWeight.w600 : FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }
}

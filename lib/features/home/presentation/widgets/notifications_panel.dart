import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacings.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import 'offline_map_download_dialog.dart';

Future<void> showNotificationsPanel(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _NotificationsPage()));
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_rounded, color: kGreen, size: 22),
            SizedBox(width: context.spaceSm),
            Text(
              'notificationsTitle'.tr(),
              style: TextStyle(
                fontSize: context.rs(17.0, 20.0),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.spaceLg),
          child: ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationCenter.items,
            builder: (context, items, child) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'notificationsEmpty'.tr(),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: context.spaceSm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return switch (item) {
                    OfflineDownloadNotification() => _OfflineDownloadTile(
                      item: item,
                    ),
                    MessageNotification() => _MessageTile(item: item),
                  };
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OfflineDownloadTile extends StatelessWidget {
  const _OfflineDownloadTile({required this.item});

  final OfflineDownloadNotification item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estimate = TileCacheService.estimateJobs(
      item.jobs,
      retina: item.retina,
    );

    return _NotificationCard(
      icon: Icons.download_for_offline_rounded,
      onTap: hTap(() async {
        NotificationCenter.remove(item);
        Navigator.of(context).pop();
        await showOfflineMapDownloadDialog(
          context,
          jobs: item.jobs,
          title: item.title,
          body: item.body,
          urlTemplate: item.urlTemplate,
          subdomains: item.subdomains,
          retina: item.retina,
        );
      }),
      onDismiss: () => NotificationCenter.remove(item),
      title: item.title,
      subtitle: Text(
        'offlineMapSizeEstimate'.tr(
          namedArgs: {'size': formatMapCacheSize(estimate.estimatedBytes)},
        ),
        style: TextStyle(
          fontSize: context.rs(11.0, 13.0),
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.item});

  final MessageNotification item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _NotificationCard(
      icon: item.icon ?? Icons.info_outline_rounded,
      onTap: hTap(() => NotificationCenter.remove(item)),
      onDismiss: () => NotificationCenter.remove(item),
      title: item.title,
      subtitle: Text(
        item.body,
        style: TextStyle(
          fontSize: context.rs(11.0, 13.0),
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDismiss,
  });

  final IconData icon;
  final String title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withAlpha(120),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kGreenSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kGreen, size: 22),
              ),
              kHorizontalSpace12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: context.rs(13.0, 15.0),
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ),
              ),
              IconButton(
                tooltip: 'deleteLabel'.tr(),
                onPressed: hTap(onDismiss),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart' show IconData;

import '../map/tile_cache_service.dart';

/// Base type for anything shown in the map page's notification bell. Any
/// kind of message can be delivered through here — `notifications_panel.dart`
/// renders by matching on the subtype, so new kinds of notifications can be
/// added without reworking the page itself.
sealed class AppNotification {
  const AppNotification();
}

/// A map-tile download the user postponed ("Keyinroq") from the offline-map
/// dialog, kept here so it can be resumed later from the notification panel.
class OfflineDownloadNotification extends AppNotification {
  const OfflineDownloadNotification({
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

/// A plain informational message (e.g. an announcement, alert, or update
/// notice) with no special action attached — tapping it just dismisses it.
class MessageNotification extends AppNotification {
  const MessageNotification({
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;
}

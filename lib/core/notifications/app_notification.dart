import 'package:flutter/widgets.dart' show IconData;

import '../map/tile_cache_service.dart';

sealed class AppNotification {
  const AppNotification();
}

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

import 'package:flutter/foundation.dart';

import 'app_notification.dart';

/// Holds every [AppNotification] shown via the bell icon on the map page —
/// a general-purpose notification list, not specific to any one feature.
/// Session-scoped (in-memory only): does not survive an app restart.
class NotificationCenter {
  const NotificationCenter._();

  static final ValueNotifier<List<AppNotification>> items =
      ValueNotifier<List<AppNotification>>(const []);

  static void add(AppNotification notification) {
    items.value = [...items.value, notification];
  }

  static void remove(AppNotification notification) {
    items.value = items.value.where((e) => e != notification).toList();
  }

  static void clear() {
    items.value = const [];
  }
}

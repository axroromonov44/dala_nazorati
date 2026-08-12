import 'package:flutter/foundation.dart';

import 'app_notification.dart';

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

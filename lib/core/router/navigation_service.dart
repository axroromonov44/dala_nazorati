import 'package:flutter/material.dart';

/// Router qatlamiga bog'lanmagan joylardan (masalan DioService interceptor)
/// navigatsiya qilish uchun global kalit.
class NavigationService {
  const NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app.dart';
import 'core/di/injection.dart';
import 'core/map/tile_cache_service.dart';
import 'core/notifications/push_service.dart';
import 'core/observability/crash_reporting.dart';
import 'core/observability/diagnostics_log.dart';
import 'core/update/shorebird_update_service.dart';
import 'features/fields/data/field_media_cache.dart';
import 'features/reference/data/reference_image_cache.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // First, so every startup failure after this point is reported.
  await CrashReporting.init();

  await EasyLocalization.ensureInitialized();
  await configureDependencies();
  // configureDependencies opens Hive, which the log writes into.
  await DiagnosticsLog.init();
  binding.addObserver(DiagnosticsLifecycleObserver());
  await TileCacheService.init();
  await FieldMediaCache.init();
  await ReferenceImageCache.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      startLocale: const Locale('uz'),
      child: const App(),
    ),
  );

  unawaited(getIt<ShorebirdUpdateService>().checkAndUpdateSilently());
  // After runApp, so the permission prompt lands on the first rendered
  // screen rather than on an empty window.
  unawaited(getIt<PushService>().init());
}

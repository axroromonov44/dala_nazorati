import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../observability/crash_reporting.dart';
import '../observability/diagnostics_log.dart';
import 'app_version.dart';

/// Remote Config keys, created under exactly these names in the console.
class RemoteConfigKeys {
  const RemoteConfigKeys._();

  /// Anything below this is blocked (forced update).
  static const minSupportedVersion = 'min_supported_version';

  /// The newest released version (optional update).
  static const latestVersion = 'latest_version';

  /// Shown to the user. Falls back to a built-in string when empty.
  static const updateMessage = 'update_message';

  /// Store links, driven from the console: the App Store id is unknown until
  /// the app is first submitted, and a link that changes later should not
  /// require a new build.
  static const storeUrlAndroid = 'store_url_android';
  static const storeUrlIos = 'store_url_ios';
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.requirement,
    required this.message,
    this.storeUrl = '',
  });

  final UpdateRequirement requirement;
  final String message;

  /// Store link. The button is not shown when empty.
  final String storeUrl;

  static const none = AppUpdateStatus(
    requirement: UpdateRequirement.none,
    message: '',
    storeUrl: '',
  );
}

/// Reads the update policy from Firebase Remote Config.
///
/// Blocking an old version therefore needs no new build: one value changes in
/// the console and every device picks it up on its next launch.
class RemoteConfigService {
  /// Asking often costs quota and traffic, but an hour is responsive enough:
  /// an urgent block reaches everyone within the hour.
  static const _minimumFetchInterval = Duration(hours: 1);

  Future<AppUpdateStatus> checkForUpdate() async {
    // Nothing to do when Firebase is not configured.
    if (!CrashReporting.isActive) return AppUpdateStatus.none;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );
      // Defaults keep the logic safe with no network: an empty string blocks
      // nobody.
      await remoteConfig.setDefaults(const {
        RemoteConfigKeys.minSupportedVersion: '',
        RemoteConfigKeys.latestVersion: '',
        RemoteConfigKeys.updateMessage: '',
        RemoteConfigKeys.storeUrlAndroid:
            'https://play.google.com/store/apps/details?id=com.nazorat.aat.uz',
        RemoteConfigKeys.storeUrlIos: '',
      });
      await remoteConfig.fetchAndActivate();

      final info = await PackageInfo.fromPlatform();
      final requirement = resolveUpdateRequirement(
        current: info.version,
        minimumSupported: remoteConfig.getString(
          RemoteConfigKeys.minSupportedVersion,
        ),
        latest: remoteConfig.getString(RemoteConfigKeys.latestVersion),
      );

      DiagnosticsLog.info(
        'update',
        'installed ${info.version} -> ${requirement.name}',
      );

      return AppUpdateStatus(
        requirement: requirement,
        message: remoteConfig.getString(RemoteConfigKeys.updateMessage),
        storeUrl: Platform.isIOS
            ? remoteConfig.getString(RemoteConfigKeys.storeUrlIos)
            : remoteConfig.getString(RemoteConfigKeys.storeUrlAndroid),
      );
    } catch (error, stack) {
      // No network, or Remote Config did not answer: carry on regardless.
      DiagnosticsLog.warn('update', 'Remote Config unavailable', error: error);
      await CrashReporting.recordNonFatal(
        error,
        stack,
        reason: 'Remote Config unavailable',
      );
      return AppUpdateStatus.none;
    }
  }
}

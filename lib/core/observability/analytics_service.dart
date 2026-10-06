import 'package:firebase_analytics/firebase_analytics.dart';

import 'crash_reporting.dart';
import 'diagnostics_log.dart';

/// A thin layer over Firebase Analytics.
///
/// Every call is a no-op when Firebase is not configured, so callers never
/// have to check first.
class AnalyticsService {
  const AnalyticsService();

  bool get _enabled => CrashReporting.isActive;

  FirebaseAnalytics get instance => FirebaseAnalytics.instance;

  /// Passed to `MaterialApp.router` for automatic screen tracking.
  FirebaseAnalyticsObserver? get navigatorObserver =>
      _enabled ? FirebaseAnalyticsObserver(analytics: instance) : null;

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!_enabled) return;
    await instance.logEvent(name: name, parameters: parameters);
  }

  /// The internal identifier only — never a name, phone number or passport id.
  Future<void> setUserId(String? id) async {
    if (!_enabled) return;
    await instance.setUserId(id: id);
    await CrashReporting.setUserId(id);
    DiagnosticsLog.info('auth', 'user: ${id ?? "signed out"}');
  }
}

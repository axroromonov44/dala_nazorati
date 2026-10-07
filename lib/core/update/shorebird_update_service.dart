import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../observability/crash_reporting.dart';
import '../observability/diagnostics_log.dart';

/// Downloads Shorebird patches in the background.
///
/// Nothing here is ever shown to the inspector. A patch is Dart code only, it
/// applies on the next launch, and an inspector in a field has no use for a
/// dialog about it — so a failure must stay quiet and still be visible to us
/// afterwards, which is what the diagnostics log is for.
class ShorebirdUpdateService {
  ShorebirdUpdateService({ShorebirdUpdater? updater})
    : _updater = updater ?? ShorebirdUpdater();

  static const _tag = 'shorebird';

  /// The Crashlytics key carrying the running patch number.
  static const patchKey = 'shorebird_patch';

  final ShorebirdUpdater _updater;

  bool get isAvailable => _updater.isAvailable;

  /// Reports which patch the app is running, then downloads a newer one if
  /// there is one.
  ///
  /// Called without awaiting, after `runApp`: a weak connection must not hold
  /// the first screen back.
  Future<void> checkAndUpdateSilently() async {
    // False in debug and in a `flutter build` release — only a build made by
    // `shorebird release` carries the updater.
    if (!_updater.isAvailable) {
      DiagnosticsLog.info(_tag, 'updater not in this build');
      return;
    }

    await _reportCurrentPatch();

    final UpdateStatus status;
    try {
      status = await _updater.checkForUpdate();
    } catch (error) {
      // The check talks to Shorebird's servers, so in the field it fails as
      // often as any other request.
      DiagnosticsLog.warn(_tag, 'could not check for a patch', error: error);
      return;
    }

    switch (status) {
      case UpdateStatus.upToDate:
        DiagnosticsLog.info(_tag, 'up to date');
      case UpdateStatus.unavailable:
        DiagnosticsLog.info(_tag, 'updates unavailable');
      case UpdateStatus.restartRequired:
        // Downloaded on an earlier launch; the app is still running the old
        // code and nothing more can be done until it is reopened.
        DiagnosticsLog.info(_tag, 'patch waiting for a restart');
      case UpdateStatus.outdated:
        await _download();
    }
  }

  Future<void> _download() async {
    DiagnosticsLog.info(_tag, 'patch available, downloading');
    try {
      await _updater.update();
    } on UpdateException catch (error) {
      await _recordFailure(error);
      return;
    } catch (error, stack) {
      await CrashReporting.recordNonFatal(
        error,
        stack,
        reason: 'Shorebird update failed',
      );
      DiagnosticsLog.error(_tag, 'update failed', error: error);
      return;
    }

    final next = await _readNextPatch();
    DiagnosticsLog.info(
      _tag,
      next == null
          ? 'patch downloaded, applies on the next launch'
          : 'patch ${next.number} downloaded, applies on the next launch',
    );
  }

  /// A download that fails because the inspector is in a field with no signal
  /// is not a defect, and reporting it would bury the ones that are. Only a
  /// patch that downloaded and then would not install says something is
  /// actually wrong.
  Future<void> _recordFailure(UpdateException error) async {
    switch (error.reason) {
      case UpdateFailureReason.noUpdate:
      case UpdateFailureReason.downloadFailed:
        DiagnosticsLog.warn(_tag, 'patch not downloaded', error: error);
      case UpdateFailureReason.installFailed:
      case UpdateFailureReason.unknown:
        DiagnosticsLog.error(
          _tag,
          'patch could not be installed',
          error: error,
        );
        await CrashReporting.recordNonFatal(
          error,
          null,
          reason: 'Shorebird patch ${error.reason.name}',
        );
    }
  }

  Future<void> _reportCurrentPatch() async {
    final Patch? patch;
    try {
      patch = await _updater.readCurrentPatch();
    } catch (error) {
      // Reported as text rather than as a number: "unknown" and "patch 0"
      // mean different things, and a crash filtered on the wrong one sends
      // whoever reads it after the wrong build.
      await CrashReporting.setCustomKey(patchKey, 'unknown');
      DiagnosticsLog.warn(
        _tag,
        'could not read the running patch number',
        error: error,
      );
      return;
    }

    // No patch means the release as the stores shipped it, which is worth
    // saying explicitly — an absent key would read as "reporting is broken".
    final number = patch?.number ?? 0;
    await CrashReporting.setCustomKey(patchKey, number);
    DiagnosticsLog.info(_tag, 'running patch $number');
  }

  /// Reads the patch that was just staged. Only used to name it in the log,
  /// so a failure here costs nothing and must not surface as an update
  /// failure.
  Future<Patch?> _readNextPatch() async {
    try {
      return await _updater.readNextPatch();
    } catch (error) {
      DiagnosticsLog.warn(
        _tag,
        'could not read the staged patch number',
        error: error,
      );
      return null;
    }
  }
}

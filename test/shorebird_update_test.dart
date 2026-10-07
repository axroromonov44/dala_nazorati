import 'package:flutter_test/flutter_test.dart';
import 'package:nazorat_aat/core/observability/diagnostics_log.dart';
import 'package:nazorat_aat/core/update/shorebird_update_service.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Stands in for the platform updater, which only exists in a build made by
/// `shorebird release`.
class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    this.available = true,
    this.status = UpdateStatus.upToDate,
    this.currentPatch,
    this.nextPatch,
    this.updateError,
    this.checkError,
    this.readError,
  });

  final bool available;
  final UpdateStatus status;
  final Patch? currentPatch;
  final Patch? nextPatch;
  final Object? updateError;
  final Object? checkError;
  final Object? readError;

  var updateCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    if (checkError != null) throw checkError!;
    return status;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<Patch?> readCurrentPatch() async {
    if (readError != null) throw readError!;
    return currentPatch;
  }

  @override
  Future<Patch?> readNextPatch() async {
    if (readError != null) throw readError!;
    return nextPatch;
  }
}

void main() {
  setUp(DiagnosticsLog.clear);

  test('a build without the updater does nothing at all', () async {
    final updater = _FakeUpdater(available: false);
    await ShorebirdUpdateService(updater: updater).checkAndUpdateSilently();

    expect(updater.updateCalls, 0);
    expect(DiagnosticsLog.dump(), contains('updater not in this build'));
  });

  test('the running patch number is recorded before anything else', () async {
    await ShorebirdUpdateService(
      updater: _FakeUpdater(currentPatch: const Patch(number: 7)),
    ).checkAndUpdateSilently();

    expect(DiagnosticsLog.dump(), contains('running patch 7'));
  });

  test('an unpatched release reports patch 0, not nothing', () async {
    await ShorebirdUpdateService(
      updater: _FakeUpdater(),
    ).checkAndUpdateSilently();

    expect(DiagnosticsLog.dump(), contains('running patch 0'));
  });

  test('an outdated app downloads and names the staged patch', () async {
    final updater = _FakeUpdater(
      status: UpdateStatus.outdated,
      currentPatch: const Patch(number: 7),
      nextPatch: const Patch(number: 8),
    );
    await ShorebirdUpdateService(updater: updater).checkAndUpdateSilently();

    expect(updater.updateCalls, 1);
    expect(DiagnosticsLog.dump(), contains('patch 8 downloaded'));
  });

  test('a patch already waiting is not downloaded again', () async {
    final updater = _FakeUpdater(status: UpdateStatus.restartRequired);
    await ShorebirdUpdateService(updater: updater).checkAndUpdateSilently();

    expect(updater.updateCalls, 0);
    expect(DiagnosticsLog.dump(), contains('waiting for a restart'));
  });

  // The point of splitting the failure reasons: an inspector in a field with
  // no signal must not produce the same report as a patch that will not
  // install.
  test('a failed download is a warning, not an error', () async {
    await ShorebirdUpdateService(
      updater: _FakeUpdater(
        status: UpdateStatus.outdated,
        updateError: const UpdateException(
          message: 'no signal',
          reason: UpdateFailureReason.downloadFailed,
        ),
      ),
    ).checkAndUpdateSilently();

    final log = DiagnosticsLog.dump();
    expect(log, contains('WARN'));
    expect(log, isNot(contains('ERROR')));
  });

  test('a patch that will not install is an error', () async {
    await ShorebirdUpdateService(
      updater: _FakeUpdater(
        status: UpdateStatus.outdated,
        updateError: const UpdateException(
          message: 'broken patch',
          reason: UpdateFailureReason.installFailed,
        ),
      ),
    ).checkAndUpdateSilently();

    expect(DiagnosticsLog.dump(), contains('ERROR'));
  });

  test('a failed check stops before the download', () async {
    final updater = _FakeUpdater(checkError: Exception('offline'));
    await ShorebirdUpdateService(updater: updater).checkAndUpdateSilently();

    expect(updater.updateCalls, 0);
    expect(DiagnosticsLog.dump(), contains('could not check for a patch'));
  });

  // Reading the number goes through the same platform channel as the update,
  // so it can fail on its own; losing it must not cost us the patch.
  test('an unreadable patch number does not stop the update', () async {
    final updater = _FakeUpdater(
      status: UpdateStatus.outdated,
      readError: const ReadPatchException(message: 'channel closed'),
    );
    await ShorebirdUpdateService(updater: updater).checkAndUpdateSilently();

    expect(updater.updateCalls, 1);
    final log = DiagnosticsLog.dump();
    expect(log, contains('could not read the running patch number'));
    // "unknown" and "patch 0" are different findings, and reporting the
    // second one for the first would point at the wrong build.
    expect(log, isNot(contains('running patch 0')));
  });
}

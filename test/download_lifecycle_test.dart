import 'package:dala_nazorati/core/download/download_lifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A download must not fail because the inspector left the app. The tile loop
/// decides the network is gone from a run of failed tiles, and a backgrounded
/// process times out whatever was in flight - so those failures have to be
/// told apart from a real loss of signal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DownloadLifecycle lifecycle;

  setUp(() => lifecycle = DownloadLifecycle()..attach());
  tearDown(() => lifecycle.detach());

  test('reports nothing while the app stays in front', () {
    expect(lifecycle.consumeSawBackground(), isFalse);
  });

  test('reports a trip to the background exactly once', () {
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(lifecycle.consumeSawBackground(), isTrue);
    // Cleared by reading: each batch asks about its own window, not about
    // every background trip the download has ever seen.
    expect(lifecycle.consumeSawBackground(), isFalse);
  });

  test('counts inactive and hidden as away, not only paused', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      lifecycle.didChangeAppLifecycleState(state);
      expect(
        lifecycle.consumeSawBackground(),
        isTrue,
        reason: '$state should count as away',
      );
    }
  });

  test('calls back on return, so an interrupted step can restart', () {
    var resumed = 0;
    lifecycle.onResumed = () => resumed++;

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(resumed, 1);
  });

  test('detaching twice is harmless', () {
    lifecycle.detach();
    expect(lifecycle.detach, returnsNormally);
  });
}

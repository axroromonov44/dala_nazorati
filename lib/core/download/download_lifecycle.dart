import 'package:flutter/widgets.dart';

/// Tracks whether the app has been out of the foreground while a download is
/// running.
///
/// It exists because of how the tile loop decides the network is gone: a run of
/// failed tiles. When Android freezes a backgrounded process, the requests
/// already in flight time out after six to eight seconds, which looks exactly
/// like a lost connection - two batches of that and the download gives up with
/// an error, on a phone whose signal never dropped.
///
/// Leaving the app is not a reason to fail a download, so failures that span a
/// trip to the background are not counted. The loop keeps running for as long
/// as the system lets it, and the controller restarts it on return if the
/// system did cut it off.
class DownloadLifecycle with WidgetsBindingObserver {
  bool _sawBackground = false;
  bool _attached = false;

  VoidCallback? onResumed;

  bool get isForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void attach() {
    if (_attached) return;
    _attached = true;
    _sawBackground = false;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// True once since the last call. Reading it clears it, so each batch asks
  /// about its own window rather than about the whole download.
  bool consumeSawBackground() {
    final saw = _sawBackground;
    _sawBackground = false;
    return saw;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _sawBackground = true;
      case AppLifecycleState.resumed:
        onResumed?.call();
    }
  }
}

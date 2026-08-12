import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdUpdateService {
  ShorebirdUpdateService() : _updater = ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  bool get isAvailable => _updater.isAvailable;

  Future<void> checkAndUpdateSilently() async {
    if (!_updater.isAvailable) return;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
        debugPrint(
          '[Shorebird] Yangi patch yuklandi, keyingi startda ishlaydi',
        );
      }
    } catch (e) {
      debugPrint('[Shorebird] Update tekshiruvida xato: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdUpdateService {
  ShorebirdUpdateService() : _updater = ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  bool get isAvailable => _updater.isAvailable;

  /// App ishga tushgandan so'ng fon da chaqiriladi.
  /// Yangi patch topilsa yuklab oladi — keyingi ishga tushirishda tatbiq bo'ladi.
  /// Hech qanday xato foydalanuvchiga ko'rsatilmaydi.
  Future<void> checkAndUpdateSilently() async {
    if (!_updater.isAvailable) return;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
        // Patch yuklandi — keyingi restart da avtomatik tatbiq bo'ladi
        debugPrint('[Shorebird] Yangi patch yuklandi, keyingi startda ishlaydi');
      }
    } catch (e) {
      // Silent fail — foydalanuvchiga hech narsa ko'rsatilmaydi
      debugPrint('[Shorebird] Update tekshiruvida xato: $e');
    }
  }
}

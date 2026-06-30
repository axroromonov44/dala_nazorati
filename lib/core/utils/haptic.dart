import 'package:flutter/services.dart';

/// Engil tap — oddiy tugmalar
VoidCallback? hTap(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.lightImpact();
    fn();
  };
}

/// O'rta tap — muhim amallar (saqlash, tasdiqlash)
VoidCallback? hTapMedium(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.mediumImpact();
    fn();
  };
}

/// Og'ir tap — xavfli amallar (o'chirish, bekor)
VoidCallback? hTapHeavy(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.heavyImpact();
    fn();
  };
}

/// To'g'ridan-to'g'ri selectionClick chaqirish uchun
void hapticSelect() => HapticFeedback.selectionClick();

/// Tanlash uchun (dropdown, switch)
VoidCallback? hTapSelect(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.selectionClick();
    fn();
  };
}

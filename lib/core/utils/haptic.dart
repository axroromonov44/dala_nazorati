import 'package:flutter/services.dart';

VoidCallback? hTap(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.lightImpact();
    fn();
  };
}

VoidCallback? hTapMedium(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.mediumImpact();
    fn();
  };
}

VoidCallback? hTapHeavy(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.heavyImpact();
    fn();
  };
}

void hapticSelect() => HapticFeedback.selectionClick();

void hapticLight() => HapticFeedback.lightImpact();
void hapticMedium() => HapticFeedback.mediumImpact();
void hapticHeavy() => HapticFeedback.heavyImpact();

VoidCallback? hTapSelect(VoidCallback? fn) {
  if (fn == null) return null;
  return () {
    HapticFeedback.selectionClick();
    fn();
  };
}

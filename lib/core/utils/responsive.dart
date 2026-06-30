import 'package:flutter/material.dart';

extension Responsive on BuildContext {
  /// Telefon yoki planshet ekanligini aniqlaydi
  bool get isTablet => MediaQuery.of(this).size.shortestSide >= 600;

  /// Telefon uchun [phone], planshet uchun [tablet] qiymatini qaytaradi
  T rs<T>(T phone, T tablet) => isTablet ? tablet : phone;

  // Icon o'lchamlari
  double get iconSm  => rs(18.0, 24.0);
  double get iconMd  => rs(24.0, 32.0);
  double get iconLg  => rs(48.0, 64.0);
  double get iconXl  => rs(80.0, 108.0);

  // Padding / spacing
  double get spaceSm => rs(8.0,  12.0);
  double get spaceMd => rs(16.0, 24.0);
  double get spaceLg => rs(24.0, 36.0);
  double get spaceXl => rs(32.0, 48.0);

  // Map control FAB
  double get fabRadius   => rs(12.0, 16.0);
  double get fabIconSize => rs(20.0, 26.0);

  // Content max width (login, error, drawer)
  double get contentMaxWidth => rs(double.infinity, 540.0);
  double get sheetMaxWidth   => rs(double.infinity, 600.0);
}

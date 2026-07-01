import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : kBackground;
    final appBarBg = isDark ? const Color(0xFF1A1A1A) : kBackground;
    final fgColor = isDark ? kWhite : kBlack;

    final textColor = isDark ? kWhite : kBlack;
    final textSecColor = isDark ? const Color(0xFF9CA3AF) : kTextSecondary;

    final textTheme = TextTheme(
      displayMedium:  kBold28.copyWith(color: textColor, letterSpacing: -0.5),
      headlineLarge:  kBold24.copyWith(color: textColor, letterSpacing: -0.3),
      headlineMedium: kSemiBold20.copyWith(color: textColor),
      titleLarge:     kSemiBold18.copyWith(color: textColor),
      titleMedium:    kMedium16.copyWith(color: textColor),
      titleSmall:     kMedium14.copyWith(color: textColor),
      bodyLarge:      kRegular16.copyWith(color: textColor, height: 1.5),
      bodyMedium:     kRegular14.copyWith(color: textColor, height: 1.5),
      bodySmall:      kRegular12.copyWith(color: textSecColor, height: 1.4),
      labelLarge:     kMedium14.copyWith(color: textColor),
      labelMedium:    kMedium12.copyWith(color: textSecColor),
      labelSmall:     kMedium11.copyWith(color: textSecColor, letterSpacing: 0.3),
    );

    final softBorderColor = isDark
        ? const Color(0xFFFFFFFF).withAlpha(22)
        : const Color(0xFF2E7D32).withAlpha(45);
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: softBorderColor, width: 1.4),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kGreen, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kError, width: 1.4),
    );
    final inputFill = isDark ? const Color(0xFF1A211A) : const Color(0xFFF5F8F5);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGreen,
        brightness: brightness,
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder.copyWith(
          borderSide: const BorderSide(color: kError, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(color: isDark ? kGreenLight : kGreen, fontSize: 14),
        floatingLabelStyle: TextStyle(
          color: isDark ? kGreenLight : kGreen,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: isDark ? kGreenLight : kGreen,
        suffixIconColor: isDark ? kGreenLight : kGreen,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: kGreen,
          foregroundColor: kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        elevation: 0,
        foregroundColor: fgColor,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: appBarBg,
      ),
    );
  }
}

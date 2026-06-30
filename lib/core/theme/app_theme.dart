import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1E1E1E) : kWhite;
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

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGreen),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGreen, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kError),
    );

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
        fillColor: fillColor,
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder.copyWith(
          borderSide: const BorderSide(color: kError, width: 2),
        ),
        labelStyle: const TextStyle(color: kGreen),
        floatingLabelStyle: const TextStyle(color: kGreen),
        prefixIconColor: kGreen,
        suffixIconColor: kGreen,
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

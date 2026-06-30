import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacings.dart';
import '../di/injection.dart';
import '../storage/secure_storage_service.dart';
import '../utils/haptic.dart';
import '../utils/responsive.dart';
import '../theme/theme_cubit.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    final isDark = themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final hPad = context.spaceLg;
    final avatarRadius = context.rs(32.0, 44.0);
    final avatarIconSize = context.rs(36.0, 50.0);

    return Drawer(
      width: context.rs(304.0, 360.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            color: kGreen,
            padding: EdgeInsets.fromLTRB(
              hPad,
              MediaQuery.of(context).padding.top + hPad,
              hPad,
              hPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: kWhite,
                  child: Image.asset(
                    'assets/images/main_logo.png',
                    width: avatarIconSize,
                    height: avatarIconSize,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, e, s) => Icon(
                      Icons.grass_rounded,
                      color: kGreen,
                      size: avatarIconSize,
                    ),
                  ),
                ),
                SizedBox(height: context.spaceSm),
                Text(
                  'appTitle'.tr(),
                  style: TextStyle(
                    color: kWhite,
                    fontSize: context.rs(20.0, 26.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.spaceMd),

          // ── Til ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _SectionLabel('languageLabel'.tr()),
          ),
          SizedBox(height: context.spaceSm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: const _LanguageDropdown(),
          ),

          SizedBox(height: context.spaceLg),
          Divider(indent: hPad, endIndent: hPad, color: colorScheme.outlineVariant),
          SizedBox(height: context.spaceSm),

          // ── Ilova rejimi ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _SectionLabel('appMode'.tr()),
          ),
          SizedBox(height: context.spaceSm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _ThemeSwitchTile(isDark: isDark),
          ),

          const Spacer(),

          // ── Logout ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, context.spaceSm),
            child: const _LogoutButton(),
          ),

          // ── Version ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: context.spaceMd),
            child: Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.rs(11.0, 13.0),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section label
// ──────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: context.rs(11.0, 13.0),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Language dropdown
// ──────────────────────────────────────────────────────────────────────────────

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown();

  static const _langs = [
    (code: 'uz', label: "O'zbek tili", flag: '🇺🇿'),
    (code: 'ru', label: 'Русский язык', flag: '🇷🇺'),
    (code: 'en', label: 'English', flag: '🇬🇧'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      initialValue: current,
      isDense: true,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: colorScheme.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kGreen),
      items: _langs
          .map(
            (lang) => DropdownMenuItem(
              value: lang.code,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  kHorizontalSpace8,
                  Text(
                    lang.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (code) {
        if (code != null) {
          hapticSelect();
          context.setLocale(Locale(code));
        }
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Theme switch tile
// ──────────────────────────────────────────────────────────────────────────────

class _ThemeSwitchTile extends StatelessWidget {
  const _ThemeSwitchTile({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        hapticSelect();
        context.read<ThemeCubit>().toggle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                key: ValueKey(isDark),
                color: kGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isDark ? 'darkMode'.tr() : 'lightMode'.tr(),
                style: TextStyle(
                  fontSize: context.rs(13.0, 15.0),
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            _MiniSwitch(value: isDark),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      width: 48,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? kGreen : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: kWhite,
                shape: BoxShape.circle,
              ),
              child: Icon(
                value ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                size: 13,
                color: value ? kGreen : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Logout button
// ──────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        hapticSelect();
        await getIt<SecureStorageService>().clearTokens();
        if (context.mounted) {
          Navigator.of(context).pop();
          context.go('/login');
        }
      },
      icon: const Icon(Icons.logout_rounded, size: 18, color: kError),
      label: Text(
        'logout'.tr(),
        style: const TextStyle(
          color: kError,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: kError),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

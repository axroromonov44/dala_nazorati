import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  static const _flags = {'uz': '🇺🇿', 'ru': '🇷🇺', 'en': '🇬🇧'};
  static const _labels = {'uz': "O'z", 'ru': 'Ру', 'en': 'En'};
  static const _locales = [Locale('uz'), Locale('ru'), Locale('en')];

  @override
  Widget build(BuildContext context) {
    final current = context.locale;
    return PopupMenuButton<Locale>(
      initialValue: current,
      onSelected: context.setLocale,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => _locales
          .map(
            (locale) => PopupMenuItem(
              value: locale,
              child: Row(
                children: [
                  Text(
                    _flags[locale.languageCode] ?? '',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(_labels[locale.languageCode] ?? locale.languageCode),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: kGreen),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _flags[current.languageCode] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Text(
              _labels[current.languageCode] ?? current.languageCode,
              style: const TextStyle(
                color: kGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

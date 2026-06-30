import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../storage/hive_service.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._hiveService) : super(const Locale('uz')) {
    _load();
  }

  final HiveService _hiveService;
  static const _key = 'locale';

  static const supportedLocales = [
    Locale('uz'),
    Locale('ru'),
    Locale('en'),
  ];

  void _load() {
    final code = _hiveService.userBox.get(_key) as String?;
    if (code != null) emit(Locale(code));
  }

  void setLocale(Locale locale) {
    _hiveService.userBox.put(_key, locale.languageCode);
    emit(locale);
  }
}

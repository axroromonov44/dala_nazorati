import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../storage/hive_service.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._hiveService) : super(ThemeMode.light) {
    _load();
  }

  final HiveService _hiveService;
  static const _key = 'theme_mode';

  void _load() {
    final saved = _hiveService.userBox.get(_key) as String?;
    if (saved != null) emit(ThemeMode.values.byName(saved));
  }

  void setTheme(ThemeMode mode) {
    _hiveService.userBox.put(_key, mode.name);
    emit(mode);
  }

  void toggle() =>
      setTheme(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
}

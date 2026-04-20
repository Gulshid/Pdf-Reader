import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const _key = 'theme_mode';
  final _box = Hive.box('settings');

  void _loadTheme() {
    final saved = _box.get(_key, defaultValue: 'system') as String;
    switch (saved) {
      case 'light':
        emit(ThemeMode.light);
      case 'dark':
        emit(ThemeMode.dark);
      default:
        emit(ThemeMode.system);
    }
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _box.put(_key, next == ThemeMode.dark ? 'dark' : 'light');
    emit(next);
  }

  void setMode(ThemeMode mode) {
    _box.put(
        _key,
        switch (mode) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          _ => 'system',
        });
    emit(mode);
  }
}
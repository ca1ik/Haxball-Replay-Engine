// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _lang = 'en';
  bool _highRefreshRate = true;

  ThemeMode get themeMode => _themeMode;
  String get lang => _lang;
  bool get highRefreshRate => _highRefreshRate;
  bool get isDark => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getBool('dark') ?? true
        ? ThemeMode.dark
        : ThemeMode.light;
    _lang = prefs.getString('lang') ?? 'en';
    _highRefreshRate = prefs.getBool('highRefreshRate') ?? true;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark', mode == ThemeMode.dark);
  }

  Future<void> setLang(String lang) async {
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
  }

  Future<void> setHighRefreshRate(bool v) async {
    _highRefreshRate = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highRefreshRate', v);
  }
}

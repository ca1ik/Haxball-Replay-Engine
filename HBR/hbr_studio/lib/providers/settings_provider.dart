// lib/providers/settings_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _lang = 'en';
  bool _showBackground = true;
  String _clipSavePath = '';

  ThemeMode get themeMode => _themeMode;
  String get lang => _lang;
  bool get showBackground => _showBackground;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Returns the user-set clip save path, or defaults to the Downloads folder.
  String get clipSavePath {
    if (_clipSavePath.isNotEmpty) return _clipSavePath;
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return '$home${Platform.pathSeparator}Downloads';
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = (prefs.getBool('dark') ?? true)
        ? ThemeMode.dark
        : ThemeMode.light;
    _lang = prefs.getString('lang') ?? 'en';
    _showBackground = prefs.getBool('showBackground') ?? true;
    _clipSavePath = prefs.getString('clipSavePath') ?? '';
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

  Future<void> setShowBackground(bool v) async {
    _showBackground = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showBackground', v);
  }

  Future<void> setClipSavePath(String path) async {
    _clipSavePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clipSavePath', path);
  }
}

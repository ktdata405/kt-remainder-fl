import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remainder/reminder_model.dart';

/// Persists all app settings using SharedPreferences.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kWebAppUrl         = 'web_app_url';
  static const _kThemeMode         = 'theme_mode';
  static const _kDefaultRepeat     = 'default_repeat';
  static const _kUse24h            = 'use_24h';
  static const _kShowCancelled     = 'show_cancelled';
  static const _kDefaultLeadMin    = 'default_lead_min';
  static const _kUseLocalStorage   = 'use_local_storage';
  
  // Font settings
  static const _kFontSizeTitle     = 'font_size_title';
  static const _kFontSizeBody      = 'font_size_body';
  static const _kFontSizeLabel     = 'font_size_label';
  static const _kFontColorTitle    = 'font_color_title';
  static const _kFontColorGlobal   = 'font_color';
  static const _kFontStyleTitle    = 'font_style_title';
  static const _kFontStyleBody     = 'font_style_body';
  static const _kFontStyleLabel    = 'font_style_label';

  SharedPreferences? _prefs;

  Future<void> init({String seedUrl = ''}) async {
    _prefs = await SharedPreferences.getInstance();
    if (seedUrl.isNotEmpty &&
        !seedUrl.contains('PASTE_YOUR') &&
        (_prefs!.getString(_kWebAppUrl) ?? '').isEmpty) {
      await _prefs!.setString(_kWebAppUrl, seedUrl);
    }
  }

  String get webAppUrl => _prefs?.getString(_kWebAppUrl) ?? '';
  Future<void> setWebAppUrl(String url) async {
    await _prefs!.setString(_kWebAppUrl, url.trim());
    notifyListeners();
  }

  bool get isConfigured => webAppUrl.isNotEmpty && !webAppUrl.contains('PASTE_YOUR');

  ThemeMode get themeMode {
    switch (_prefs?.getString(_kThemeMode) ?? 'system') {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }
  Future<void> setThemeMode(ThemeMode mode) async {
    final val = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await _prefs!.setString(_kThemeMode, val);
    notifyListeners();
  }

  bool get use24hFormat => _prefs?.getBool(_kUse24h) ?? false;
  Future<void> setUse24hFormat(bool value) async {
    await _prefs!.setBool(_kUse24h, value);
    notifyListeners();
  }

  bool get showCancelledReminders => _prefs?.getBool(_kShowCancelled) ?? false;
  Future<void> setShowCancelledReminders(bool value) async {
    await _prefs!.setBool(_kShowCancelled, value);
    notifyListeners();
  }

  RepeatFrequency get defaultRepeat {
    final raw = _prefs?.getString(_kDefaultRepeat) ?? 'none';
    return RepeatFrequency.values.firstWhere((v) => v.name == raw, orElse: () => RepeatFrequency.none);
  }
  Future<void> setDefaultRepeat(RepeatFrequency freq) async {
    await _prefs!.setString(_kDefaultRepeat, freq.name);
    notifyListeners();
  }

  int get defaultLeadMinutes => _prefs?.getInt(_kDefaultLeadMin) ?? 0;
  Future<void> setDefaultLeadMinutes(int minutes) async {
    await _prefs!.setInt(_kDefaultLeadMin, minutes);
    notifyListeners();
  }

  bool get useLocalStorage => _prefs?.getBool(_kUseLocalStorage) ?? true;
  Future<void> setUseLocalStorage(bool value) async {
    await _prefs!.setBool(_kUseLocalStorage, value);
    notifyListeners();
  }

  // Font settings accessors
  double get fontSizeTitle => _prefs?.getDouble(_kFontSizeTitle) ?? 16.0;
  Future<void> setFontSizeTitle(double size) async {
    await _prefs!.setDouble(_kFontSizeTitle, size);
    notifyListeners();
  }

  double get fontSizeBody => _prefs?.getDouble(_kFontSizeBody) ?? 13.0;
  Future<void> setFontSizeBody(double size) async {
    await _prefs!.setDouble(_kFontSizeBody, size);
    notifyListeners();
  }

  double get fontSizeLabel => _prefs?.getDouble(_kFontSizeLabel) ?? 10.0;
  Future<void> setFontSizeLabel(double size) async {
    await _prefs!.setDouble(_kFontSizeLabel, size);
    notifyListeners();
  }

  int get fontColorTitle => _prefs?.getInt(_kFontColorTitle) ?? 0;
  Future<void> setFontColorTitle(int value) async {
    await _prefs!.setInt(_kFontColorTitle, value);
    notifyListeners();
  }

  int get fontColorValue => _prefs?.getInt(_kFontColorGlobal) ?? 0;
  Future<void> setFontColor(int value) async {
    await _prefs!.setInt(_kFontColorGlobal, value);
    notifyListeners();
  }

  String get fontStyleTitle => _prefs?.getString(_kFontStyleTitle) ?? 'bold';
  Future<void> setFontStyleTitle(String style) async {
    await _prefs!.setString(_kFontStyleTitle, style);
    notifyListeners();
  }

  String get fontStyleBody => _prefs?.getString(_kFontStyleBody) ?? 'normal';
  Future<void> setFontStyleBody(String style) async {
    await _prefs!.setString(_kFontStyleBody, style);
    notifyListeners();
  }

  String get fontStyleLabel => _prefs?.getString(_kFontStyleLabel) ?? 'normal';
  Future<void> setFontStyleLabel(String style) async {
    await _prefs!.setString(_kFontStyleLabel, style);
    notifyListeners();
  }

  String formatDateTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = local.day;
    final month = months[local.month - 1];
    final year = local.year;

    if (use24hFormat) {
      final h = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '$day $month $year · $h:$min';
    } else {
      final rawH = local.hour;
      final h = rawH > 12 ? rawH - 12 : (rawH == 0 ? 12 : rawH);
      final ampm = rawH >= 12 ? 'PM' : 'AM';
      final min = local.minute.toString().padLeft(2, '0');
      return '$day $month $year · $h:$min $ampm';
    }
  }
}

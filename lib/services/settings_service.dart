import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remainder/reminder_model.dart';

/// Persists all app settings using SharedPreferences.
/// Call [init] once at startup before reading any values.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  // ─── Storage keys ──────────────────────────────────────────────────────────
  static const _kWebAppUrl         = 'web_app_url';
  static const _kThemeMode         = 'theme_mode';      // 'system'|'light'|'dark'
  static const _kDefaultRepeat     = 'default_repeat';  // RepeatFrequency.name
  static const _kUse24h            = 'use_24h';
  static const _kShowCancelled     = 'show_cancelled';
  static const _kDefaultLeadMin    = 'default_lead_min'; // advance-alert minutes

  SharedPreferences? _prefs;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init({String seedUrl = ''}) async {
    _prefs = await SharedPreferences.getInstance();
    // Seed the URL from app_config.dart on first launch if not yet saved.
    if (seedUrl.isNotEmpty &&
        !seedUrl.contains('PASTE_YOUR') &&
        (_prefs!.getString(_kWebAppUrl) ?? '').isEmpty) {
      await _prefs!.setString(_kWebAppUrl, seedUrl);
    }
  }

  // ─── Web App URL ───────────────────────────────────────────────────────────

  String get webAppUrl => _prefs?.getString(_kWebAppUrl) ?? '';

  Future<void> setWebAppUrl(String url) async {
    await _prefs!.setString(_kWebAppUrl, url.trim());
    notifyListeners();
  }

  bool get isConfigured {
    final url = webAppUrl;
    return url.isNotEmpty && !url.contains('PASTE_YOUR');
  }

  // ─── Theme ─────────────────────────────────────────────────────────────────

  ThemeMode get themeMode {
    switch (_prefs?.getString(_kThemeMode) ?? 'system') {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final val = mode == ThemeMode.light ? 'light'
              : mode == ThemeMode.dark  ? 'dark'
              : 'system';
    await _prefs!.setString(_kThemeMode, val);
    notifyListeners();
  }

  // ─── Time format ───────────────────────────────────────────────────────────

  bool get use24hFormat => _prefs?.getBool(_kUse24h) ?? false;

  Future<void> setUse24hFormat(bool value) async {
    await _prefs!.setBool(_kUse24h, value);
    notifyListeners();
  }

  // ─── Show cancelled reminders ──────────────────────────────────────────────

  bool get showCancelledReminders => _prefs?.getBool(_kShowCancelled) ?? true;

  Future<void> setShowCancelledReminders(bool value) async {
    await _prefs!.setBool(_kShowCancelled, value);
    notifyListeners();
  }

  // ─── Default repeat frequency ──────────────────────────────────────────────

  RepeatFrequency get defaultRepeat {
    final raw = _prefs?.getString(_kDefaultRepeat) ?? 'none';
    return RepeatFrequency.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => RepeatFrequency.none,
    );
  }

  Future<void> setDefaultRepeat(RepeatFrequency freq) async {
    await _prefs!.setString(_kDefaultRepeat, freq.name);
    notifyListeners();
  }

  // ─── Advance reminder alert (minutes before) ───────────────────────────────
  // 0 = notify exactly at scheduled time, other values = also notify N min before.

  int get defaultLeadMinutes => _prefs?.getInt(_kDefaultLeadMin) ?? 0;

  Future<void> setDefaultLeadMinutes(int minutes) async {
    await _prefs!.setInt(_kDefaultLeadMin, minutes);
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Format a [DateTime] according to the current time-format setting.
  String formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day   = dt.day;
    final month = months[dt.month - 1];
    final year  = dt.year;

    if (use24hFormat) {
      final h   = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year · $h:$min';
    } else {
      final rawH = dt.hour;
      final h    = rawH > 12 ? rawH - 12 : (rawH == 0 ? 12 : rawH);
      final ampm = rawH >= 12 ? 'PM' : 'AM';
      final min  = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year · $h:$min $ampm';
    }
  }
}


import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'remainder/reminder_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init(seedUrl: kWebAppUrl);
  runApp(const ReminderApp());
}

class ReminderApp extends StatefulWidget {
  const ReminderApp({super.key});

  @override
  State<ReminderApp> createState() => _ReminderAppState();
}

class _ReminderAppState extends State<ReminderApp> {
  final SettingsService _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = _settings.themeMode;
    return MaterialApp(
      title: 'Remainder',
      themeMode: mode,
      theme: AppTheme.buildTheme(Brightness.light),
      darkTheme: AppTheme.buildTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: ReminderScreen(
        webAppUrl: _settings.webAppUrl,
        isDark: _isDarkMode(mode),
        onToggleTheme: _toggleTheme,
        onSettingsChanged: () => setState(() {}),
      ),
    );
  }

  bool _isDarkMode(ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  void _toggleTheme() {
    final next = _settings.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _settings.setThemeMode(next);
  }
}

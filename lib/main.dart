import 'package:flutter/material.dart';

import 'config/app_config.dart';
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
      title: 'Reminders',
      themeMode: mode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: ReminderScreen(
        webAppUrl: _settings.webAppUrl,
        isDark: mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark),
        onToggleTheme: () {
          final next = _settings.themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          _settings.setThemeMode(next);
        },
        onSettingsChanged: () => setState(() {}),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const seedColor = Color(0xFF4F46E5);
  final isDark = brightness == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF6F7FB),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF6F7FB),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
      ),
    ),
    cardTheme: CardTheme(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF1C1C28) : Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF6F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? const Color(0xFF2D2D3F) : const Color(0xFF1A1A2E),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    ),
  );
}

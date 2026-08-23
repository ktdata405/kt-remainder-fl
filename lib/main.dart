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
  const seedColor = Color(0xFF19A796);
  final isDark = brightness == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0C2625) : const Color(0xFFF3FBFA),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF0C2625) : const Color(0xFFF3FBFA),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        color: isDark ? const Color(0xFFE7FFFD) : const Color(0xFF154C49),
      ),
      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFF9EECE4) : const Color(0xFF19A796),
      ),
    ),
    cardTheme: CardTheme(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF153633) : Colors.white,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.15 : 0.07),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? const Color(0xFF2ED1BF) : const Color(0xFF19A796),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark
                ? const Color(0xFF2B6D67)
                : const Color(0xFFD8F5F1);
          }
          return isDark ? const Color(0xFF194542) : const Color(0xFFEFFAF8);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFFE7FFFD) : const Color(0xFF15635B);
          }
          return isDark ? const Color(0xFF9ED9D3) : const Color(0xFF3A7D77);
        }),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? const Color(0xFF1B4542)
          : const Color(0xFFEFFAF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2D6862) : const Color(0xFFCEEAE6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF5EE7D8) : const Color(0xFF16A394),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      labelStyle: TextStyle(color: isDark ? const Color(0xFF9ACCC7) : const Color(0xFF648F8A)),
      hintStyle: TextStyle(color: isDark ? const Color(0xFF5D8F8A) : const Color(0xFF88ABA6)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? const Color(0xFF1F5450) : const Color(0xFF135E57),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2C5A56) : const Color(0xFFD7ECE9),
    ),
  );
}

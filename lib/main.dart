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
      title: 'Remainder',
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

  ThemeData _buildTheme(Brightness brightness) {
    const seedColor = Color(0xFF4F46E5);
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    );

    final s = SettingsService.instance;
    final titleColor = Color(s.fontColorTitle);
    final globalColor = Color(s.fontColorValue);

    TextStyle getStyle(double size, String style, Color color) {
      return TextStyle(
        fontSize: size,
        color: color,
        fontWeight: style == 'bold' ? FontWeight.bold : FontWeight.normal,
        fontStyle: style == 'italic' ? FontStyle.italic : FontStyle.normal,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      textTheme: TextTheme(
        titleLarge: getStyle(s.fontSizeTitle + 4, s.fontStyleTitle, titleColor),
        titleMedium: getStyle(s.fontSizeTitle, s.fontStyleTitle, titleColor),
        bodyMedium: getStyle(s.fontSizeBody, s.fontStyleBody, globalColor),
        bodySmall: getStyle(s.fontSizeLabel, s.fontStyleLabel, globalColor),
        labelLarge: getStyle(s.fontSizeLabel + 2, s.fontStyleLabel, globalColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: getStyle(s.fontSizeTitle + 6, s.fontStyleTitle, titleColor).copyWith(color: cs.onSurface),
        iconTheme: IconThemeData(color: cs.primary),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

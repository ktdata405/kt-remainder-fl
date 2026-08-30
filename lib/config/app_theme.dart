import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppTheme {
  static ThemeData buildTheme(Brightness brightness) {
    const seedColor = Color(0xFF4F46E5);
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    );

    final s = SettingsService.instance;
    
    final titleColor = s.fontColorTitle == 0 
        ? (isDark ? Colors.white : Colors.black) 
        : Color(s.fontColorTitle);
        
    final globalColor = s.fontColorValue == 0 
        ? (isDark ? Colors.white70 : const Color(0xFF475569)) 
        : Color(s.fontColorValue);

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

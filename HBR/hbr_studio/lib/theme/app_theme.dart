// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Dark Palette ─────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF090C1A);
  static const Color surface = Color(0xFF0C1020);
  static const Color card = Color(0xFF101428);
  static const Color border = Color(0xFF1B2238);
  static const Color accent = Color(0xFF00D4AA);
  static const Color accentDim = Color(0xFF00A882);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color purpleDim = Color(0xFF5C4580);
  static const Color indigo = Color(0xFF4A6CF7);
  static const Color textPrim = Color(0xFFE8EAF2);
  static const Color textSec = Color(0xFF8B92B0);
  static const Color textHint = Color(0xFF4A5270);
  static const Color danger = Color(0xFFFF4D6A);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF00D4AA);

  // ── Light Palette ─────────────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF0F2F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF8F9FC);
  static const Color borderLight = Color(0xFFDDE1EE);
  static const Color accentLight = Color(0xFF00B894);
  static const Color textPrimLight = Color(0xFF0D1020);
  static const Color textSecLight = Color(0xFF5A6280);
  static const Color textHintLight = Color(0xFF9BA3BC);

  // ── Gradients ─────────────────────────────────────────────────────────────────
  static const LinearGradient accentGrad = LinearGradient(
    colors: [accent, Color(0xFF00A8C6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleGrad = LinearGradient(
    colors: [purple, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGrad = LinearGradient(
    colors: [Color(0xFF141929), Color(0xFF0F1524)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient aiGrad = LinearGradient(
    colors: [purple, indigo, Color(0xFF00C9FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Theme ────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get theme => darkTheme; // legacy

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? bg : bgLight,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? accent : accentLight,
        onPrimary: Colors.white,
        secondary: purple,
        onSecondary: Colors.white,
        surface: isDark ? surface : surfaceLight,
        onSurface: isDark ? textPrim : textPrimLight,
        error: danger,
        onError: Colors.white,
      ),
      dividerColor: isDark ? border : borderLight,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: _ts(32, FontWeight.w700, isDark, -0.5),
        headlineMedium: _ts(20, FontWeight.w600, isDark),
        titleMedium: _ts(14, FontWeight.w500, isDark),
        bodyMedium: _ts(13, FontWeight.w400, isDark, 0, true),
        labelSmall: _ts(11, FontWeight.w500, isDark, 0.8, true),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        fillColor: isDark ? surface : surfaceLight,
        filled: true,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(isDark ? border : borderLight),
      ),
    );
  }

  static TextStyle _ts(
    double size,
    FontWeight weight,
    bool isDark, [
    double ls = 0,
    bool secondary = false,
  ]) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: ls,
    color: secondary
        ? (isDark ? textSec : textSecLight)
        : (isDark ? textPrim : textPrimLight),
    decoration: TextDecoration.none,
    decorationStyle: null,
  );

  // ── Context-aware helpers ─────────────────────────────────────────────────────
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;
  static Color bgOf(BuildContext ctx) => isDark(ctx) ? bg : bgLight;
  static Color surfaceOf(BuildContext ctx) =>
      isDark(ctx) ? surface : surfaceLight;
  static Color cardOf(BuildContext ctx) => isDark(ctx) ? card : cardLight;
  static Color borderOf(BuildContext ctx) => isDark(ctx) ? border : borderLight;
  static Color textPrimOf(BuildContext ctx) =>
      isDark(ctx) ? textPrim : textPrimLight;
  static Color textSecOf(BuildContext ctx) =>
      isDark(ctx) ? textSec : textSecLight;
  static Color textHintOf(BuildContext ctx) =>
      isDark(ctx) ? textHint : textHintLight;
  static LinearGradient cardGradOf(BuildContext ctx) =>
      isDark(ctx) ? cardGrad : cardGradLight;
}

/// Responsive font-size helper. Scales linearly with window width beyond
/// 1200 logical pixels (clamped 0.85×–1.75×). Usage: context.rfs(13)
extension ResponsiveFontSize on BuildContext {
  double rfs(double base) {
    final w = MediaQuery.of(this).size.width;
    final scale = (w / 1200.0).clamp(0.85, 1.75);
    return base * scale;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ──────────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF080B14);
  static const Color surface = Color(0xFF0F1524);
  static const Color card = Color(0xFF141929);
  static const Color border = Color(0xFF1E2740);
  static const Color accent = Color(0xFF00D4AA);
  static const Color accentDim = Color(0xFF00A882);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color purpleDim = Color(0xFF5C4580);
  static const Color textPrim = Color(0xFFE8EAF2);
  static const Color textSec = Color(0xFF8B92B0);
  static const Color textHint = Color(0xFF4A5270);
  static const Color danger = Color(0xFFFF4D6A);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF00D4AA);

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient accentGrad = LinearGradient(
    colors: [accent, Color(0xFF00A8C6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleGrad = LinearGradient(
    colors: [purple, Color(0xFF4A6CF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGrad = LinearGradient(
    colors: [Color(0xFF141929), Color(0xFF0F1524)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme ────────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: purple,
      surface: surface,
      error: danger,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrim,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrim,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrim,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSec,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textHint,
        letterSpacing: 0.8,
      ),
    ),
  );
}

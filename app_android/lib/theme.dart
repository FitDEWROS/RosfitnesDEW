import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg = Color(0xFF0F0F10);
  static const Color bgSoft = Color(0xFF141417);
  static const Color text = Color(0xFFF4F1E8);
  static const Color muted = Color(0xFFC6C0B2);
  static const Color card = Color(0xFF1B1B1F);
  static const Color accent = Color(0xFFF6E5A6);
  static const Color accentStrong = Color(0xFFF2D17C);
  static const Color green = Color(0xFF36C75A);

  static ThemeData darkTheme() {
    final textTheme = GoogleFonts.manropeTextTheme(
      const TextTheme(),
    ).apply(
      bodyColor: text,
      displayColor: text,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentStrong,
        surface: card,
      ),
      textTheme: textTheme.copyWith(
        titleLarge: GoogleFonts.exo2(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        titleMedium: GoogleFonts.exo2(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      useMaterial3: true,
    );
  }
}

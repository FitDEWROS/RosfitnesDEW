import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgDark = Color(0xFF0F0F10);
  static const Color bgSoftDark = Color(0xFF141417);
  static const Color textDark = Color(0xFFF4F1E8);
  static const Color mutedDark = Color(0xFFC6C0B2);
  static const Color cardDark = Color(0xFF1B1B1F);
  static const Color accentDark = Color(0xFFF6E5A6);
  static const Color accentStrongDark = Color(0xFFF2D17C);

  static const Color bgLight = Color(0xFFF4F1E6);
  static const Color bgSoftLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF1B1B1B);
  static const Color mutedLight = Color(0xFF6F6A60);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color accentLight = Color(0xFFE8C86A);
  static const Color accentStrongLight = Color(0xFFDDB24D);
  static const Color green = Color(0xFF36C75A);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color bgColor(BuildContext context) {
    return isDark(context) ? bgDark : bgLight;
  }

  static Color bgSoftColor(BuildContext context) {
    return isDark(context) ? bgSoftDark : bgSoftLight;
  }

  static Color textColor(BuildContext context) {
    return isDark(context) ? textDark : textLight;
  }

  static Color mutedColor(BuildContext context) {
    return isDark(context) ? mutedDark : mutedLight;
  }

  static Color cardColor(BuildContext context) {
    return isDark(context) ? cardDark : cardLight;
  }

  static Color accentColor(BuildContext context) {
    return isDark(context) ? accentDark : accentLight;
  }

  static Color accentStrongColor(BuildContext context) {
    return isDark(context) ? accentStrongDark : accentStrongLight;
  }

  static List<Color> backgroundGradient(BuildContext context) {
    if (isDark(context)) {
      return [bgDark, const Color(0xFF151518), const Color(0xFF0C0C0D)];
    }
    return [bgLight, const Color(0xFFF8F3E8), const Color(0xFFF1E9D6)];
  }

  static ThemeData darkTheme() {
    final textTheme = GoogleFonts.manropeTextTheme(
      const TextTheme(),
    ).apply(
      bodyColor: textDark,
      displayColor: textDark,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: accentDark,
        secondary: accentStrongDark,
        surface: cardDark,
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

  static ThemeData lightTheme() {
    final textTheme = GoogleFonts.manropeTextTheme(
      const TextTheme(),
    ).apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: accentLight,
        secondary: accentStrongLight,
        surface: cardLight,
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

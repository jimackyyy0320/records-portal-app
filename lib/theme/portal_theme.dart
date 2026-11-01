import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PortalColors {
  PortalColors._();

  static const Color forest = Color(0xFF1A3A2A);
  static const Color forestMid = Color(0xFF244D38);
  static const Color forestLight = Color(0xFF2E6347);
  static const Color forestDark = Color(0xFF0D2218);
  static const Color forestFaint = Color(0x0F1A3A2A);

  static const Color gold = Color(0xFFC9A84C);
  static const Color goldDark = Color(0xFFA07C2A);
  static const Color goldPale = Color(0xFFFDF6E3);

  static const Color parchment = Color(0xFFF5F0E8);
  static const Color parchmentDk = Color(0xFFEDE5D4);

  static const Color burg = Color(0xFF8B1A1A);
  static const Color burgBg = Color(0xFFFDF0F0);
  static const Color burgBorder = Color(0xFFF0C8C8);

  static const Color emerald = Color(0xFF1A5C38);
  static const Color emeraldBg = Color(0xFFEBF5EF);
  static const Color emeraldBorder = Color(0x331A5C38);

  static const Color ink = Color(0xFF1A1A14);
  static const Color ink2 = Color(0xFF3D3D28);
  static const Color ink3 = Color(0xFF7A7A5A);

  static const Color rule = Color(0x1F1A3A2A);
  static const Color ruleMed = Color(0x331A3A2A);
}

class PortalTheme {
  PortalTheme._();

  static TextStyle serif({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = PortalColors.forest,
    bool italic = false,
    double height = 1.2,
  }) {
    return GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: height,
    );
  }

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = PortalColors.ink,
    double? letterSpacing,
    double height = 1.4,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData buildTheme() {
    final baseText = GoogleFonts.outfitTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PortalColors.parchment,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PortalColors.forest,
        primary: PortalColors.forest,
        secondary: PortalColors.gold,
        surface: Colors.white,
        error: PortalColors.burg,
      ),
      textTheme: baseText.apply(
        bodyColor: PortalColors.ink,
        displayColor: PortalColors.forest,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: PortalColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: serif(
          size: 22,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PortalColors.forest,
        contentTextStyle: sans(color: Colors.white, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Dark Mode controller persisted in `SharedPreferences`.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const String _kDarkModeKey = 'mis_portal_dark_mode_v1';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_kDarkModeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, _isDarkMode);
  }
}

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

  // Dark Mode Palette
  static const Color darkBg = Color(0xFF0B131E);
  static const Color darkSurface = Color(0xFF131F30);
  static const Color darkCard = Color(0xFF1A2940);
  static const Color darkRule = Color(0x3364748B);
  static const Color darkInk = Color(0xFFF1F5F9);
  static const Color darkInk2 = Color(0xFFCBD5E1);
  static const Color darkInk3 = Color(0xFF94A3B8);

  static bool get isDark => ThemeController.instance.isDarkMode;

  static Color get activeBg => isDark ? darkBg : parchment;
  static Color get activeCard => isDark ? darkSurface : Colors.white;
  static Color get activeInk => isDark ? darkInk : ink;
  static Color get activeInk2 => isDark ? darkInk2 : ink2;
  static Color get activeInk3 => isDark ? darkInk3 : ink3;
  static Color get activeRule => isDark ? darkRule : rule;
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
    final effectiveColor =
        (PortalColors.isDark && color == PortalColors.forest)
            ? PortalColors.gold
            : (PortalColors.isDark && color == PortalColors.ink)
                ? PortalColors.darkInk
                : color;
    return GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      color: effectiveColor,
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
    final effectiveColor = (PortalColors.isDark && color == PortalColors.ink)
        ? PortalColors.darkInk
        : (PortalColors.isDark && color == PortalColors.ink2)
            ? PortalColors.darkInk2
            : (PortalColors.isDark && color == PortalColors.ink3)
                ? PortalColors.darkInk3
                : (PortalColors.isDark && color == PortalColors.forest)
                    ? const Color(0xFF6EE7B7)
                    : color;
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: effectiveColor,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData buildTheme() {
    final baseText = GoogleFonts.outfitTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PortalColors.parchment,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PortalColors.forest,
        brightness: Brightness.light,
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

  static ThemeData buildDarkTheme() {
    final baseText = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PortalColors.darkBg,
      cardColor: PortalColors.darkSurface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PortalColors.gold,
        brightness: Brightness.dark,
        primary: PortalColors.gold,
        secondary: const Color(0xFF34D399),
        surface: PortalColors.darkSurface,
        error: const Color(0xFFF87171),
      ),
      textTheme: baseText.apply(
        bodyColor: PortalColors.darkInk,
        displayColor: PortalColors.gold,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: PortalColors.darkSurface,
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
        backgroundColor: PortalColors.darkCard,
        contentTextStyle: sans(color: Colors.white, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

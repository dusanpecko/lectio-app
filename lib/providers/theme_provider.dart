import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Theme Provider pre správu témy, fontu a veľkosti písma
///
/// Používa SharedPreferences pre perzistenciu nastavení.
/// Poskytuje notifyListeners() pre reaktívne UI updates.
class ThemeProvider with ChangeNotifier {
  // Theme Mode
  ThemeMode _themeMode = ThemeMode.system;

  // Font Settings
  String _fontFamily = 'Default';
  double _fontSize = 16.0;

  // Loading state
  bool _isInitialized = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  bool get isInitialized => _isInitialized;

  /// Konštruktor - načíta nastavenia pri inicializácii
  ThemeProvider() {
    _loadSettings();
  }

  /// Inicializuje provider a načíta uložené nastavenia
  Future<void> initialize() async {
    await _loadSettings();
  }

  /// Načíta nastavenia z SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme Mode
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    _themeMode = _themeModeFromString(themeModeString);

    // Font Family
    _fontFamily = prefs.getString('fontFamily') ?? 'Default';

    // Font Size
    _fontSize = prefs.getDouble('fontSize') ?? 16.0;

    _isInitialized = true;
    notifyListeners();
  }

  /// Konvertuje string na ThemeMode enum
  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Konvertuje ThemeMode enum na string
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  /// Zmení theme mode a uloží do SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeModeToString(mode));
  }

  /// Zmení font family a uloží do SharedPreferences
  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;

    _fontFamily = family;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', family);
  }

  /// Zmení font size a uloží do SharedPreferences
  Future<void> setFontSize(double size) async {
    if (_fontSize == size) return;

    _fontSize = size;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
  }

  /// Vráti správnu font family pre TextStyle
  /// 'Default' -> 'Inter' (hlavný font aplikácie)
  String? getFontFamilyForTextStyle() {
    if (_fontFamily == 'Default') return 'Inter';
    return _fontFamily;
  }

  /// Vytvorí TextTheme s použitými font nastaveniami
  TextTheme applyFontSettings(TextTheme baseTheme) {
    final fontFamily = getFontFamilyForTextStyle();
    final scaleFactor = _fontSize / 16.0; // 16 je baseline

    return TextTheme(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.displayLarge?.fontSize ?? 57) * scaleFactor,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.displayMedium?.fontSize ?? 45) * scaleFactor,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.displaySmall?.fontSize ?? 36) * scaleFactor,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.headlineLarge?.fontSize ?? 32) * scaleFactor,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.headlineMedium?.fontSize ?? 28) * scaleFactor,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.headlineSmall?.fontSize ?? 24) * scaleFactor,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.titleLarge?.fontSize ?? 22) * scaleFactor,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.titleMedium?.fontSize ?? 16) * scaleFactor,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.titleSmall?.fontSize ?? 14) * scaleFactor,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.bodyLarge?.fontSize ?? 16) * scaleFactor,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.labelLarge?.fontSize ?? 14) * scaleFactor,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.labelMedium?.fontSize ?? 12) * scaleFactor,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontFamily: fontFamily,
        fontSize: (baseTheme.labelSmall?.fontSize ?? 11) * scaleFactor,
      ),
    );
  }
}

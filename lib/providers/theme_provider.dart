import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Language Settings
  String _languageCode = 'system'; // 'system', 'sk', 'en'

  // Loading state
  bool _isInitialized = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  String get languageCode => _languageCode;
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

    // Language Code
    _languageCode = prefs.getString('languageCode') ?? 'system';

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

  /// Zmení jazyk aplikácie a uloží do SharedPreferences
  Future<void> setLanguageCode(String code, BuildContext context) async {
    if (_languageCode == code) return;

    _languageCode = code;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', code);

    // Aplikuj zmenu jazyka okamžite
    if (code != 'system') {
      await context.setLocale(Locale(code));
    } else {
      // Pre 'system' použij systémový jazyk
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final supportedLanguages = ['sk', 'en'];
      final systemLang = supportedLanguages.contains(systemLocale.languageCode)
          ? systemLocale.languageCode
          : 'sk';
      await context.setLocale(Locale(systemLang));
    }
  }

  /// Vráti správnu font family pre TextStyle
  /// 'Default' -> 'Inter' (hlavný font aplikácie)
  String? getFontFamilyForTextStyle() {
    if (_fontFamily == 'Default') return 'Inter';
    return _fontFamily;
  }

  /// Vytvorí TextTheme s použitými font nastaveniami
  TextTheme applyFontSettings(TextTheme baseTheme) {
    final scaleFactor = _fontSize / 16.0; // 16 je baseline

    // Pre každý TextStyle aplikuj font family a scale
    TextStyle? applyToStyle(TextStyle? style) {
      if (style == null) return null;

      final baseSize = style.fontSize ?? 14.0;
      final scaledSize = baseSize * scaleFactor;

      // Aplikuj správny font podľa výberu
      switch (_fontFamily) {
        case 'Default':
          // Inter font z Google Fonts
          return GoogleFonts.inter(textStyle: style, fontSize: scaledSize);
        case 'Serif':
          // Merriweather - elegantný serif font
          return GoogleFonts.merriweather(
            textStyle: style,
            fontSize: scaledSize,
          );
        case 'Monospace':
          // Roboto Mono - čitateľný monospace font
          return GoogleFonts.robotoMono(textStyle: style, fontSize: scaledSize);
        default:
          return style.copyWith(fontSize: scaledSize);
      }
    }

    return TextTheme(
      displayLarge: applyToStyle(baseTheme.displayLarge),
      displayMedium: applyToStyle(baseTheme.displayMedium),
      displaySmall: applyToStyle(baseTheme.displaySmall),
      headlineLarge: applyToStyle(baseTheme.headlineLarge),
      headlineMedium: applyToStyle(baseTheme.headlineMedium),
      headlineSmall: applyToStyle(baseTheme.headlineSmall),
      titleLarge: applyToStyle(baseTheme.titleLarge),
      titleMedium: applyToStyle(baseTheme.titleMedium),
      titleSmall: applyToStyle(baseTheme.titleSmall),
      bodyLarge: applyToStyle(baseTheme.bodyLarge),
      bodyMedium: applyToStyle(baseTheme.bodyMedium),
      bodySmall: applyToStyle(baseTheme.bodySmall),
      labelLarge: applyToStyle(baseTheme.labelLarge),
      labelMedium: applyToStyle(baseTheme.labelMedium),
      labelSmall: applyToStyle(baseTheme.labelSmall),
    );
  }
}

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
  String _languageCode = 'system'; // 'system', 'sk', 'en', 'es'

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

    // Check if context is still mounted before using it
    if (!context.mounted) return;

    // Aplikuj zmenu jazyka okamžite
    if (code != 'system') {
      await context.setLocale(Locale(code));
    } else {
      // Pre 'system' použij systémový jazyk
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final supportedLanguages = ['en', 'sk', 'es', 'fr'];
      final systemLang = supportedLanguages.contains(systemLocale.languageCode)
          ? systemLocale.languageCode
          : 'en';
      await context.setLocale(Locale(systemLang));
    }
  }

  /// Vráti správnu font family pre TextStyle
  /// 'Default' -> 'Inter' (hlavný font aplikácie)
  String? getFontFamilyForTextStyle() {
    if (_fontFamily == 'Default') return 'Inter';
    return _fontFamily;
  }

  /// Faktor veľkosti písma (baseline 16). Aplikuje sa GLOBÁLNE cez
  /// MediaQuery.textScaler v MyApp, aby platil pre VŠETKY Text widgety
  /// (nielen tie z témy — väčšina obrazoviek má hardcoded fontSize).
  double get textScale => _fontSize / 16.0;

  /// Aplikuje LEN font family na TextTheme. Veľkosť rieši globálny textScaler.
  TextTheme applyFontSettings(TextTheme baseTheme) {
    TextStyle? applyToStyle(TextStyle? style) {
      if (style == null) return null;
      switch (_fontFamily) {
        case 'Serif':
          return GoogleFonts.merriweather(textStyle: style);
        case 'Monospace':
          return GoogleFonts.robotoMono(textStyle: style);
        case 'Default':
          return GoogleFonts.inter(textStyle: style);
        default:
          return style;
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

import 'package:flutter/material.dart';

class AppColors {
  // ---- Svetlý režim ----
  static const Color primary = Color(0xFF4A5085); // DeepPurple
  static const Color accent = Color(
    0xFF686ea3,
  ); // Fialová (nepoužíva sa priamo v theme)
  static const Color background = Color(
    0xFFEDE7F6,
  ); // Svetlá fialová, scaffold background
  static const Color card = Colors.white;
  static const Color error = Colors.red;
  static const Color text = Colors.black87;
  static const Color textHint = Colors.black38;
  static const Color textDisabled = Colors.black26;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color divider = Colors.grey;
  static const Color buttonText = Colors.white;
  static const Color buttonBackground = Color(0xFF4A5085); // Zhodné s primary
  static const Color appBarBackground = Color(0xFF4A5085);
  static const Color appBarText = Colors.white;
  static const Color cardShadow = Color(0x10673AB7);

  // ---- Tmavý režim ----
  static const Color darkPrimary = Color(0xFF4A5085);
  static const Color darkAccent = Color(0xFF686ea3);
  static const Color darkBackground = Color(0xFF181225); // Tmavé pozadie
  static const Color darkCard = Color(0xFF241A35);
  static const Color darkError = Colors.redAccent;
  static const Color darkText = Colors.white;
  static const Color darkTextHint = Colors.white38;
  static const Color darkTextDisabled = Colors.white24;
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkDivider = Colors.white24;
  static const Color darkButtonText = Colors.white;
  static const Color darkButtonBackground = Color(0xFF4A5085);
  static const Color darkAppBarBackground = Color(0xFF4A5085);
  static const Color darkAppBarText = Colors.white;
  static const Color darkCardShadow = Colors.black54;
  static const Color darkInputFill = Color(0xFF33224C);

  // ---- Sémantické farby (svetlý režim) ----
  /// Hlavný titulkový text na kartách (tmavý blue-gray)
  static const Color cardTitle = Color(0xFF2D3748);

  /// Sekundárny popisný text na kartách (stredný gray)
  static const Color cardSubtitle = Color(0xFF718096);

  /// Svetlejší odtieň primary pre gradienty
  static const Color primaryLight = Color(0xFF6B73A8);

  /// Tmavší odtieň primary (napr. news detail)
  static const Color primaryDark = Color(0xFF40467b);

  /// Primary s 30% opacity (pre overlaye, tiene)
  static const Color primaryOverlay = Color(0x4D4A5085);

  /// Čierny tieň 10% (pre hero slider shadow)
  static const Color shadowLight = Color(0x1A000000);

  /// Červená pre urgentné/živé akcie
  static const Color liveRed = Color(0xFFD32F2F);

  // ---- Sémantické farby (tmavý režim) ----
  /// Hlavný titulkový text na kartách (tmavý režim)
  static const Color darkCardTitle = Color(0xFFE2E8F0);

  /// Sekundárny popisný text na kartách (tmavý režim)
  static const Color darkCardSubtitle = Color(0xFFA0AEC0);

  /// Svetlejší odtieň primary pre gradienty (tmavý režim)
  static const Color darkPrimaryLight = Color(0xFF8B92C4);

  /// Tmavší odtieň primary (tmavý režim)
  // ignore: no-equal-then-else
  static const Color darkPrimaryDark = Color(0xFF40467b);

  /// Primary s 30% opacity overlay (tmavý režim)
  static const Color darkPrimaryOverlay = Color(0x4D6B73A8);

  /// Tieň (tmavý režim)
  static const Color darkShadowLight = Color(0x33000000);

  /// Červená pre urgentné/živé akcie (tmavý režim)
  static const Color darkLiveRed = Color(0xFFEF5350);

  // ---- Alias pre kompatibilitu ----
  static const Color kAccentColor = accent;
  static const Color scaffoldBackground = background;
  static const Color darkScaffoldBackground = darkBackground;

  // ═══════════════════════════════════════════════════════════════════════════
  // ADAPTIVE HELPERY (automaticky light/dark podľa kontextu)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Hlavný titulkový text na kartách (adaptive)
  static Color adaptiveCardTitle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkCardTitle
      : cardTitle;

  /// Sekundárny popisný text (adaptive)
  static Color adaptiveCardSubtitle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkCardSubtitle
      : cardSubtitle;

  /// Primary light pre gradienty (adaptive)
  static Color adaptivePrimaryLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkPrimaryLight
      : primaryLight;

  /// Primary overlay (adaptive)
  static Color adaptivePrimaryOverlay(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkPrimaryOverlay
      : primaryOverlay;

  /// Shadow (adaptive)
  static Color adaptiveShadowLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkShadowLight
      : shadowLight;

  /// Live red (adaptive)
  static Color adaptiveLiveRed(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLiveRed : liveRed;

  /// Je tmavý režim?
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

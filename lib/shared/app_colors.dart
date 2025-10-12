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

  // ---- Alias pre kompatibilitu ----
  static const Color kAccentColor = accent;
  static const Color scaffoldBackground = background;
  static const Color darkScaffoldBackground = darkBackground;
}

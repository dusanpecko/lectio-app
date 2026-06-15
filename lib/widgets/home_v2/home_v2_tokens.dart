import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/app_colors.dart';

/// Dizajnové tokeny pre prémiový HomeScreen v2.
///
/// Vychádzajú z mockupu (svetlá levanduľová paleta, mäkké difúzne tiene,
/// serifová typografia v duchu Playfair Display / Cormorant Garamond) a zároveň
/// rešpektujú brandový [AppColors] kvôli konzistencii a podpore dark mode.
class HomeV2 {
  HomeV2._();

  // ── Paleta ──────────────────────────────────────────────────────────────
  /// Brand primary (#4A5085) — vizuálne takmer zhodný s mockupom (#4F4D91).
  static const Color primary = AppColors.primary;
  static const Color spotify = Color(0xFF1DB954);

  /// Brand gold — rámik profilu pre podporovateľov (aktívne predplatné).
  static const Color gold = Color(0xFFD4A853);
  static const Color goldLight = Color(0xFFE9C77E);

  static const Color _lightBackground = Color(0xFFF5F2FF);
  static const Color _lightCard = Colors.white;

  /// Pozadie obrazovky (adaptívne light/dark).
  static Color background(BuildContext c) =>
      AppColors.isDark(c) ? AppColors.darkBackground : _lightBackground;

  /// Pozadie kariet (adaptívne light/dark).
  static Color card(BuildContext c) =>
      AppColors.isDark(c) ? AppColors.darkCard : _lightCard;

  /// Hlavný (tmavý) text.
  static Color textDark(BuildContext c) => AppColors.adaptiveCardTitle(c);

  /// Sekundárny (stlmený) text.
  static Color textMuted(BuildContext c) => AppColors.adaptiveCardSubtitle(c);

  /// Je tmavý režim?
  static bool isDark(BuildContext c) => AppColors.isDark(c);

  /// Akcent ikon — v dark móde svetlejší (bledší) odtieň primary, nech ikony
  /// na tmavých kartách nepôsobia tmavo/muddy.
  static Color iconAccent(BuildContext c) =>
      AppColors.isDark(c) ? AppColors.darkPrimaryLight : primary;

  // ── Tvar ────────────────────────────────────────────────────────────────
  static const double radius = 22.0;
  static const double radiusSm = 16.0;

  // ── Tiene (jemné, difúzne — žiadne tvrdé čierne tiene) ────────────────────
  static List<BoxShadow> softShadow(BuildContext c) => [
        BoxShadow(
          color: AppColors.isDark(c)
              ? Colors.black.withValues(alpha: 0.30)
              : primary.withValues(alpha: 0.08),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> softShadowSm(BuildContext c) => [
        BoxShadow(
          color: AppColors.isDark(c)
              ? Colors.black.withValues(alpha: 0.25)
              : primary.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Motion ────────────────────────────────────────────────────────────────
  static const Duration anim = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;

  // ── Typografia ──────────────────────────────────────────────────────────
  /// Serifový nadpis (Playfair Display) — tituly a názvy.
  static TextStyle serifTitle(
    BuildContext c, {
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
  }) =>
      GoogleFonts.playfairDisplay(
        textStyle: TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? textDark(c),
        ),
      );

  /// Serifový citát (Cormorant Garamond, italic) — duchovné citáty / actio.
  static TextStyle serifQuote(
    BuildContext c, {
    double size = 18,
    Color? color,
    double height = 1.45,
  }) =>
      GoogleFonts.cormorantGaramond(
        textStyle: TextStyle(
          fontSize: size,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          height: height,
          color: color ?? textMuted(c),
        ),
      );

  /// Prémiový štýl pre `showDatePicker` (zaoblený, primary header, brand farby).
  /// Použiť v `builder: (ctx, child) => HomeV2.datePickerTheme(ctx, child!)`.
  static Widget datePickerTheme(BuildContext c, Widget child) {
    final base = Theme.of(c);
    final dark = textDark(c);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: primary,
          onPrimary: Colors.white,
          surface: card(c),
          onSurface: dark,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: card(c),
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          headerBackgroundColor: primary,
          headerForegroundColor: Colors.white,
          dayStyle: const TextStyle(fontWeight: FontWeight.w600),
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : dark,
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : null,
          ),
          todayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : primary,
          ),
          todayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : null,
          ),
          todayBorder: BorderSide(color: primary),
          yearForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : dark,
          ),
          yearBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : null,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
      ),
      child: child,
    );
  }
}

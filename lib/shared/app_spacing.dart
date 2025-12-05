import 'package:flutter/material.dart';

/// Konštanty pre medzery a padding v aplikácii
/// Používajte tieto hodnoty pre konzistentnú vizuálnu hierarchiu
class AppSpacing {
  AppSpacing._();

  // ═══════════════════════════════════════════════════════════════════════════
  // ZÁKLADNÉ MEDZERY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extra malá medzera (4.0)
  static const double xs = 4.0;

  /// Malá medzera (8.0)
  static const double sm = 8.0;

  /// Stredná medzera (12.0)
  static const double md = 12.0;

  /// Štandardná medzera (16.0)
  static const double lg = 16.0;

  /// Veľká medzera (20.0)
  static const double xl = 20.0;

  /// Extra veľká medzera (24.0)
  static const double xxl = 24.0;

  /// Mega medzera (32.0)
  static const double xxxl = 32.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD PADDING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Štandardný padding pre karty
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Horizontálny padding pre karty
  static const EdgeInsets cardHorizontal =
      EdgeInsets.symmetric(horizontal: lg);

  /// Vertikálny padding pre karty
  static const EdgeInsets cardVertical =
      EdgeInsets.symmetric(vertical: md);

  /// Kompaktný padding pre karty
  static const EdgeInsets cardCompact = EdgeInsets.all(md);

  // ═══════════════════════════════════════════════════════════════════════════
  // SCREEN PADDING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Štandardný padding pre obrazovky
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Horizontálny padding pre obrazovky
  static const EdgeInsets screenHorizontal =
      EdgeInsets.symmetric(horizontal: lg);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIST ITEM SPACING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Medzera medzi položkami v zozname
  static const double listItemSpacing = sm;

  /// Padding pre položky v zozname
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

/// Konštanty pre zaoblenia rohov
class AppRadius {
  AppRadius._();

  /// Extra malé zaoblenie (4.0)
  static const double xs = 4.0;

  /// Malé zaoblenie (8.0)
  static const double sm = 8.0;

  /// Stredné zaoblenie (12.0)
  static const double md = 12.0;

  /// Štandardné zaoblenie (16.0)
  static const double lg = 16.0;

  /// Veľké zaoblenie (20.0)
  static const double xl = 20.0;

  /// Extra veľké zaoblenie (24.0)
  static const double xxl = 24.0;

  /// Plne zaoblené (cirkulárne)
  static const double full = 999.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // PREDEFINOVANÉ BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Štandardný border radius pre karty
  static BorderRadius get card => BorderRadius.circular(lg);

  /// Border radius pre tlačidlá
  static BorderRadius get button => BorderRadius.circular(md);

  /// Border radius pre textové polia
  static BorderRadius get input => BorderRadius.circular(sm);

  /// Border radius pre dialógy
  static BorderRadius get dialog => BorderRadius.circular(xl);

  /// Border radius pre bottom sheet
  static BorderRadius get bottomSheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}

/// Konštanty pre animácie
class AppAnimation {
  AppAnimation._();

  /// Rýchla animácia (150ms)
  static const Duration fast = Duration(milliseconds: 150);

  /// Štandardná animácia (300ms)
  static const Duration standard = Duration(milliseconds: 300);

  /// Pomalá animácia (500ms)
  static const Duration slow = Duration(milliseconds: 500);

  /// Štandardná krivka animácie
  static const Curve defaultCurve = Curves.easeInOut;

  /// Krivka pre vstup elementu
  static const Curve enterCurve = Curves.easeOut;

  /// Krivka pre odchod elementu
  static const Curve exitCurve = Curves.easeIn;
}


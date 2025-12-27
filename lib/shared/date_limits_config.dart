/// Konfigurácia dátumových limitov pre Lectio Divina
///
/// Tieto hodnoty je jednoduché upraviť podľa dostupnosti dát.
/// Po nahratí všetkých dát stačí zmeniť tieto konštanty.
class DateLimitsConfig {
  DateLimitsConfig._();

  // ============================================
  // KONFIGUROVATEĽNÉ HODNOTY - ĽAHKO UPRAVITEĽNÉ
  // ============================================

  /// Počet dní dozadu, ktoré môže bežný používateľ prezerať
  ///
  /// Aktuálne: 15 dní (dočasne, kým nie sú všetky dáta)
  /// Po nahratí všetkých dát zmeniť na ~90 dní (3 mesiace)
  static const int daysBack = 15;

  /// Počet dní dopredu, ktoré môže bežný používateľ prezerať
  ///
  /// Aktuálne: 7 dní (dočasne, kým nie sú všetky dáta)
  /// Po nahratí všetkých dát zmeniť na ~30 dní (1 mesiac)
  static const int daysForward = 7;

  /// Či sú limity aktívne
  ///
  /// Nastaviť na `false` pre vypnutie všetkých limitov
  static const bool limitsEnabled = true;

  // ============================================
  // HELPER METÓDY - NERUŠIŤ
  // ============================================

  /// Vráti minimálny povolený dátum
  static DateTime getMinDate() {
    if (!limitsEnabled) {
      return DateTime(2020); // Bez limitov - veľký rozsah
    }
    return DateTime.now().subtract(Duration(days: daysBack));
  }

  /// Vráti maximálny povolený dátum
  static DateTime getMaxDate() {
    if (!limitsEnabled) {
      return DateTime.now().add(const Duration(days: 365)); // Bez limitov
    }
    return DateTime.now().add(Duration(days: daysForward));
  }

  /// Skontroluje či je dátum v povolenom rozsahu
  static bool isDateAllowed(DateTime date) {
    if (!limitsEnabled) return true;

    final minDate = getMinDate();
    final maxDate = getMaxDate();

    // Porovnávaj len dátumy (bez času)
    final dateOnly = DateTime(date.year, date.month, date.day);
    final minDateOnly = DateTime(minDate.year, minDate.month, minDate.day);
    final maxDateOnly = DateTime(maxDate.year, maxDate.month, maxDate.day);

    return !dateOnly.isBefore(minDateOnly) && !dateOnly.isAfter(maxDateOnly);
  }

  /// Vráti či je možné ísť na predchádzajúci deň
  static bool canGoToPreviousDay(DateTime currentDate) {
    if (!limitsEnabled) return true;

    final previousDay = currentDate.subtract(const Duration(days: 1));
    return isDateAllowed(previousDay);
  }

  /// Vráti či je možné ísť na nasledujúci deň
  static bool canGoToNextDay(DateTime currentDate) {
    if (!limitsEnabled) return true;

    final nextDay = currentDate.add(const Duration(days: 1));
    return isDateAllowed(nextDay);
  }
}

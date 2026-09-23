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

  /// Podporovatelia (11.2.4, rozhodnuté 5. 9. 2026): 60 dní dozadu / 14 dopredu.
  /// „Pred mesiacom ma oslovila myšlienka, zabudol som si ju uložiť“ — 60 dozadu;
  /// 14 dopredu presne sedí s korektúrou, ktorá beží pol mesiaca vopred.
  /// Bonus navyše, free ostáva 15/7. (Konfig zo servera — neskôr.)
  static const int supporterDaysBack = 60;
  static const int supporterDaysForward = 14;

  /// Či sú limity aktívne
  ///
  /// Nastaviť na `false` pre vypnutie všetkých limitov
  static const bool limitsEnabled = true;

  // ============================================
  // HELPER METÓDY - NERUŠIŤ
  // ============================================

  /// Vráti minimálny povolený dátum
  static DateTime getMinDate({bool isSupporter = false}) {
    if (!limitsEnabled) {
      return DateTime(2020); // Bez limitov - veľký rozsah
    }
    final back = isSupporter ? supporterDaysBack : daysBack;
    return DateTime.now().subtract(Duration(days: back));
  }

  /// Vráti maximálny povolený dátum
  static DateTime getMaxDate({bool isSupporter = false}) {
    if (!limitsEnabled) {
      return DateTime.now().add(const Duration(days: 365)); // Bez limitov
    }
    final forward = isSupporter ? supporterDaysForward : daysForward;
    return DateTime.now().add(Duration(days: forward));
  }

  /// Skontroluje či je dátum v povolenom rozsahu
  static bool isDateAllowed(DateTime date, {bool isSupporter = false}) {
    if (!limitsEnabled) return true;

    final minDate = getMinDate(isSupporter: isSupporter);
    final maxDate = getMaxDate(isSupporter: isSupporter);

    // Porovnávaj len dátumy (bez času)
    final dateOnly = DateTime(date.year, date.month, date.day);
    final minDateOnly = DateTime(minDate.year, minDate.month, minDate.day);
    final maxDateOnly = DateTime(maxDate.year, maxDate.month, maxDate.day);

    return !dateOnly.isBefore(minDateOnly) && !dateOnly.isAfter(maxDateOnly);
  }

  /// Vráti či je možné ísť na predchádzajúci deň
  static bool canGoToPreviousDay(DateTime currentDate, {bool isSupporter = false}) {
    if (!limitsEnabled) return true;

    final previousDay = currentDate.subtract(const Duration(days: 1));
    return isDateAllowed(previousDay, isSupporter: isSupporter);
  }

  /// Vráti či je možné ísť na nasledujúci deň
  static bool canGoToNextDay(DateTime currentDate, {bool isSupporter = false}) {
    if (!limitsEnabled) return true;

    final nextDay = currentDate.add(const Duration(days: 1));
    return isDateAllowed(nextDay, isSupporter: isSupporter);
  }
}

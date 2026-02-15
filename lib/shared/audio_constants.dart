/// Konštanty pre audio súbory v Lectio Divina
///
/// Všetky audio URLs sú centralizované tu pre ľahšiu údržbu
/// a možnosť zmeny prostredia (dev/staging/prod).
class AudioConstants {
  AudioConstants._(); // Private constructor - prevent instantiation

  /// Base URL pre Supabase storage
  static const String _supabaseStorageBase =
      'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public';

  /// Priečinok pre lectio audio súbory
  static const String _lectioAudioPath = 'audio-files/lectio';

  /// Priečinok pre avatary (ikony)
  static const String _avatarsPath = 'avatars/avatars';

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERLUDE / MEDITAČNÁ HUDBA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dlhá meditačná hudba (pre contemplatio a záverečnú meditáciu)
  static const String interludeLong =
      '$_supabaseStorageBase/$_lectioAudioPath/lectio_full.mp3';

  /// Krátka meditačná hudba (tichý prechod medzi sekciami)
  static const String interludeShort =
      '$_supabaseStorageBase/$_lectioAudioPath/audio_null.mp3';

  // ═══════════════════════════════════════════════════════════════════════════
  // IKONY A ARTWORK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default artwork pre audio notifikácie (lock screen, media controls)
  static const String defaultArtworkUrl =
      '$_supabaseStorageBase/$_avatarsPath/icon.png';

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METÓDY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vráti URL pre interlude na základe módu
  /// [isLong] - true pre dlhú meditáciu, false pre krátku
  static String getInterludeUrl({required bool isLong}) {
    return isLong ? interludeLong : interludeShort;
  }

  /// Vráti URL pre audio súbor v lectio priečinku
  static String getLectioAudioUrl(String filename) {
    return '$_supabaseStorageBase/$_lectioAudioPath/$filename';
  }
}

/// Konštanty pre časovanie v audio playback
class AudioTimingConstants {
  AudioTimingConstants._();

  /// Oneskorenie pred spustením krátkeho interlude (ms)
  static const int shortInterludeDelay = 1200;

  /// Oneskorenie pred spustením dlhého interlude (ms)
  static const int longInterludeDelay = 700;

  /// Oneskorenie pred prechodom na ďalší track (ms)
  static const int trackTransitionDelay = 500;

  /// Oneskorenie po seekovaní pred resetom flagu (ms)
  static const int seekCompletionDelay = 300;

  /// Interval pre aktualizáciu pozície (ms)
  static const int positionUpdateInterval = 200;
}

/// Konštanty pre notification scheduling
class NotificationConstants {
  NotificationConstants._();

  /// Počet dní dopredu pre plánovanie notifikácií
  static const int scheduleDaysAhead = 7;

  /// Predvolený čas pre welcome notifikáciu (hodina)
  static const int welcomeNotificationHour = 10;

  /// Počet dní po registrácii pre welcome notifikáciu
  static const int welcomeNotificationDaysAfterRegistration = 3;

  /// Maximálna dĺžka textu pre notifikáciu
  static const int maxNotificationTextLength = 100;
}

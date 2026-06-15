import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Model pre uložené Lectio dáta
class CachedLectioData {
  final String date;
  final String locale;
  final String? celebrationTitle;
  final String? lectioHlava;
  final String? actioText;
  final String? lectioText;
  final String? meditatioText;
  final String? oratioText;
  final String? contemplatioText;
  final String? reference;
  final String? audioUrl;
  final DateTime cachedAt;

  /// Kompletné raw dáta z lectio_sources tabuľky (obsahuje všetky audio URL)
  final Map<String, dynamic>? rawLectioSource;

  CachedLectioData({
    required this.date,
    required this.locale,
    this.celebrationTitle,
    this.lectioHlava,
    this.actioText,
    this.lectioText,
    this.meditatioText,
    this.oratioText,
    this.contemplatioText,
    this.reference,
    this.audioUrl,
    required this.cachedAt,
    this.rawLectioSource,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'locale': locale,
    'celebrationTitle': celebrationTitle,
    'lectioHlava': lectioHlava,
    'actioText': actioText,
    'lectioText': lectioText,
    'meditatioText': meditatioText,
    'oratioText': oratioText,
    'contemplatioText': contemplatioText,
    'reference': reference,
    'audioUrl': audioUrl,
    'cachedAt': cachedAt.toIso8601String(),
    'rawLectioSource': rawLectioSource,
  };

  factory CachedLectioData.fromJson(Map<String, dynamic> json) {
    return CachedLectioData(
      date: json['date'] as String,
      locale: json['locale'] as String,
      celebrationTitle: json['celebrationTitle'] as String?,
      lectioHlava: json['lectioHlava'] as String?,
      actioText: json['actioText'] as String?,
      lectioText: json['lectioText'] as String?,
      meditatioText: json['meditatioText'] as String?,
      oratioText: json['oratioText'] as String?,
      contemplatioText: json['contemplatioText'] as String?,
      reference: json['reference'] as String?,
      audioUrl: json['audioUrl'] as String?,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      rawLectioSource: json['rawLectioSource'] as Map<String, dynamic>?,
    );
  }

  /// Kontrola či sú dáta stále platné (menej ako 24 hodín)
  bool get isValid {
    final age = DateTime.now().difference(cachedAt);
    return age.inHours < 24;
  }

  /// Vráti dáta ako Map pre kompatibilitu s existujúcim kódom
  /// Ak máme rawLectioSource, vrátime ho (obsahuje všetky polia vrátane audio URLs)
  Map<String, dynamic> get rawData {
    if (rawLectioSource != null) {
      // Pridáme celebration_title ak chýba
      final data = Map<String, dynamic>.from(rawLectioSource!);
      data['celebration_title'] = celebrationTitle;
      return data;
    }
    // Fallback pre staré cache dáta bez rawLectioSource
    return {
      'hlava': lectioHlava,
      'actio_text': actioText,
      'lectio_text': lectioText,
      'meditatio_text': meditatioText,
      'oratio_text': oratioText,
      'contemplatio_text': contemplatioText,
      'reference': reference,
      'audio_url': audioUrl,
      'celebration_title': celebrationTitle,
    };
  }
}

/// Služba pre offline caching Lectio dát
class LectioCacheService {
  static LectioCacheService? _instance;
  static LectioCacheService get instance =>
      _instance ??= LectioCacheService._internal();

  LectioCacheService._internal();

  static const String _cacheKeyPrefix = 'lectio_cache_';
  static const String _cacheMetaKey = 'lectio_cache_meta';
  static const int _defaultDaysToCache = 7;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Získa kľúč pre konkrétny dátum a jazyk
  String _getCacheKey(String date, String locale) {
    return '$_cacheKeyPrefix${locale}_$date';
  }

  /// Načíta Lectio z cache pre konkrétny dátum
  Future<CachedLectioData?> getCachedLectio(String date, String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(date, locale);
      final jsonStr = prefs.getString(key);

      if (jsonStr == null) {
        appLogger.d('📦 Cache MISS pre $date ($locale)');
        return null;
      }

      final data = CachedLectioData.fromJson(jsonDecode(jsonStr));

      if (!data.isValid) {
        appLogger.d('📦 Cache EXPIRED pre $date ($locale)');
        return null;
      }

      appLogger.d('📦 Cache HIT pre $date ($locale)');
      return data;
    } catch (e) {
      appLogger.e('❌ Chyba pri čítaní cache: $e');
      return null;
    }
  }

  /// Uloží Lectio do cache
  Future<void> cacheLectio(CachedLectioData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(data.date, data.locale);
      await prefs.setString(key, jsonEncode(data.toJson()));
      appLogger.d('💾 Cached Lectio pre ${data.date} (${data.locale})');
    } catch (e) {
      appLogger.e('❌ Chyba pri ukladaní cache: $e');
    }
  }

  /// Odstráni cache pre konkrétny deň a jazyk.
  Future<void> removeCachedLectio(String date, String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCacheKey(date, locale));
      appLogger.d('🗑️ Odstránená cache pre $date ($locale)');
    } catch (e) {
      appLogger.e('❌ Chyba pri mazaní cache: $e');
    }
  }

  /// Stiahne a uloží Lectio na najbližších N dní
  Future<DownloadResult> downloadLectioForDays({
    required String locale,
    int days = _defaultDaysToCache,
    void Function(int current, int total)? onProgress,
  }) async {
    appLogger.i('⬇️ Sťahujem Lectio pre $days dní ($locale)...');

    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    for (int i = 0; i < days; i++) {
      final date = DateTime.now().add(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);

      try {
        final data = await _fetchLectioFromServer(dateStr, locale);
        if (data != null) {
          await cacheLectio(data);
          successCount++;
        } else {
          errors.add('Žiadne dáta pre $dateStr');
          errorCount++;
        }
      } catch (e) {
        errors.add('$dateStr: $e');
        errorCount++;
        appLogger.e('❌ Chyba pri sťahovaní pre $dateStr: $e');
      }

      // Callback pre progress
      onProgress?.call(i + 1, days);
    }

    // Uložíme metadata o poslednom stiahnutí
    await _saveDownloadMeta(locale, days);

    appLogger.i('✅ Stiahnuté: $successCount/$days dní ($errorCount chýb)');

    return DownloadResult(
      success: errorCount == 0,
      downloadedDays: successCount,
      totalDays: days,
      errors: errors,
    );
  }

  /// Stiahne Lectio zo servera pre konkrétny dátum
  Future<CachedLectioData?> _fetchLectioFromServer(
    String date,
    String locale,
  ) async {
    try {
      // 1. Nájdi liturgický rok
      final liturgicalYearsResponse = await _supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', locale)
          .lte('start_date', date)
          .gte('end_date', date);

      Map<String, dynamic>? correctLiturgicalYear;
      final liturgicalYearsList = liturgicalYearsResponse as List;

      if (liturgicalYearsList.isNotEmpty) {
        correctLiturgicalYear = liturgicalYearsList[0] as Map<String, dynamic>;
      } else if (locale != 'sk') {
        // Fallback to SK
        final skYearsResponse = await _supabase
            .from('liturgical_years')
            .select()
            .eq('locale_code', 'sk')
            .lte('start_date', date)
            .gte('end_date', date);
        final skYearsList = skYearsResponse as List;
        if (skYearsList.isNotEmpty) {
          correctLiturgicalYear = skYearsList[0] as Map<String, dynamic>;
        }
      }

      // 2. Nájdi kalendárny záznam
      final calendarResponse = await _supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', date)
          .eq('locale_code', locale)
          .maybeSingle();

      if (calendarResponse == null ||
          calendarResponse['lectio_hlava'] == null) {
        return null;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      // 3. Urči rok (A/B/C alebo N)
      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday).+(týždňa|Week)',
      ).hasMatch(celebrationTitle);

      final isSpecialDay =
          !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      final lectionaryCycle = correctLiturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      // 4. Nájdi lectio source
      var lectioSource = await _supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', locale)
          .eq('rok', rokToSearch)
          .maybeSingle();

      // Fallback logika
      if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
        lectioSource = await _supabase
            .from('lectio_sources')
            .select()
            .eq('hlava', lectioHlava)
            .eq('lang', locale)
            .eq('rok', 'N')
            .maybeSingle();
      }

      return CachedLectioData(
        date: date,
        locale: locale,
        celebrationTitle: celebrationTitle,
        lectioHlava: lectioHlava,
        actioText: lectioSource?['actio_text'],
        lectioText: lectioSource?['lectio_text'],
        meditatioText: lectioSource?['meditatio_text'],
        oratioText: lectioSource?['oratio_text'],
        contemplatioText: lectioSource?['contemplatio_text'],
        reference: lectioSource?['reference'] ?? celebrationTitle,
        audioUrl: lectioSource?['audio_url'],
        cachedAt: DateTime.now(),
        rawLectioSource: lectioSource,
      );
    } catch (e) {
      appLogger.e('❌ Chyba pri fetch Lectio pre $date: $e');
      rethrow;
    }
  }

  /// Uloží metadata o stiahnutí
  Future<void> _saveDownloadMeta(String locale, int days) async {
    final prefs = await SharedPreferences.getInstance();
    final meta = {
      'locale': locale,
      'days': days,
      'downloadedAt': DateTime.now().toIso8601String(),
      'validUntil': DateTime.now().add(Duration(days: days)).toIso8601String(),
    };
    await prefs.setString(_cacheMetaKey, jsonEncode(meta));
  }

  /// Získa metadata o stiahnutí
  Future<DownloadMeta?> getDownloadMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheMetaKey);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr);
      return DownloadMeta(
        locale: json['locale'] as String,
        days: json['days'] as int,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        validUntil: DateTime.parse(json['validUntil'] as String),
      );
    } catch (e) {
      return null;
    }
  }

  /// Kontrola či máme platné offline dáta
  Future<bool> hasValidOfflineData(String locale) async {
    final meta = await getDownloadMeta();
    if (meta == null) return false;
    if (meta.locale != locale) return false;
    return DateTime.now().isBefore(meta.validUntil);
  }

  /// Počet dní do vypršania offline dát
  Future<int> getDaysUntilExpiry(String locale) async {
    final meta = await getDownloadMeta();
    if (meta == null || meta.locale != locale) return 0;

    final diff = meta.validUntil.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Vymaže všetky cached dáta
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    await prefs.remove(_cacheMetaKey);
    appLogger.i('🗑️ Cache vymazaná');
  }

  /// Automatické cachovanie dnes + zajtra
  Future<void> autoCache(String locale) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final tomorrow = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    // Cache dnes ak chýba
    final todayData = await getCachedLectio(today, locale);
    if (todayData == null) {
      try {
        final data = await _fetchLectioFromServer(today, locale);
        if (data != null) await cacheLectio(data);
      } catch (e) {
        appLogger.w('⚠️ Nepodarilo sa auto-cache dnes: $e');
      }
    }

    // Cache zajtra ak chýba
    final tomorrowData = await getCachedLectio(tomorrow, locale);
    if (tomorrowData == null) {
      try {
        final data = await _fetchLectioFromServer(tomorrow, locale);
        if (data != null) await cacheLectio(data);
      } catch (e) {
        appLogger.w('⚠️ Nepodarilo sa auto-cache zajtra: $e');
      }
    }
  }
}

/// Výsledok sťahovania
class DownloadResult {
  final bool success;
  final int downloadedDays;
  final int totalDays;
  final List<String> errors;

  DownloadResult({
    required this.success,
    required this.downloadedDays,
    required this.totalDays,
    this.errors = const [],
  });
}

/// Metadata o stiahnutí
class DownloadMeta {
  final String locale;
  final int days;
  final DateTime downloadedAt;
  final DateTime validUntil;

  DownloadMeta({
    required this.locale,
    required this.days,
    required this.downloadedAt,
    required this.validUntil,
  });
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spiritual_exercise.dart';
import '../utils/app_logger.dart';

class DailyQuote {
  final String? text;
  final String? reference;

  /// Súradnice biblického čítania daného dňa (`suradnice_pismo`, neformátované).
  final String? suradnice;

  DailyQuote({this.text, this.reference, this.suradnice});
}

class LectioDataService {
  static LectioDataService? _instance;
  static LectioDataService get instance =>
      _instance ??= LectioDataService.internal();

  final SupabaseClient _supabase;

  @visibleForTesting
  static void setInstanceForTesting(LectioDataService instance) {
    _instance = instance;
  }

  @visibleForTesting
  LectioDataService.internal({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  /// Poradie jazykov pre fallback OBSAHU: jazyk používateľa → EN → SK.
  /// (Deduplikované — SK/EN používateľ nemá zbytočné duplikáty.)
  List<String> _fallbackChain(String locale) {
    final chain = <String>[locale];
    for (final fb in const ['en', 'sk']) {
      if (!chain.contains(fb)) chain.add(fb);
    }
    return chain;
  }

  static final RegExp _weekdayRe = RegExp(
    r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday).+(týždňa|Week)',
  );

  /// Liturgický cyklus (A/B/C) pre dátum — skúša jazyk → EN → SK.
  Future<String> _cycleForDate(String today, String locale) async {
    for (final lang in _fallbackChain(locale)) {
      final res = await _supabase
          .from('liturgical_years')
          .select('lectionary_cycle')
          .eq('locale_code', lang)
          .lte('start_date', today)
          .gte('end_date', today);
      final list = res as List;
      if (list.isNotEmpty) {
        return (list[0]['lectionary_cycle'] ?? 'A') as String;
      }
    }
    return 'A';
  }

  /// Určí `rok` (cyklus A/B/C alebo 'N') pre dátum. Typ dňa klasifikuje zo SK
  /// kalendára (regex spoľahlivo zachytí SK/EN názvy) — je univerzálny pre
  /// všetky jazyky, takže sa nepokazí pri FR/ES názvoch.
  Future<String> _rokForDate(String today, String cycle) async {
    final cal = await _supabase
        .from('liturgical_calendar')
        .select('celebration_title, celebration_rank_num')
        .eq('datum', today)
        .eq('locale_code', 'sk')
        .maybeSingle();
    if (cal == null) return 'N';
    final title = (cal['celebration_title'] ?? '') as String;
    final rank = cal['celebration_rank_num'];
    final isWeekday = _weekdayRe.hasMatch(title);
    final isSpecialDay =
        !isWeekday &&
        (title.toLowerCase().contains('nedeľa') ||
            title.toLowerCase().contains('sunday') ||
            (rank != null && rank > 1));
    return isSpecialDay ? cycle : 'N';
  }

  /// Lectio_source pre JEDEN jazyk: kalendár(dátum,lang) → hlava →
  /// source(hlava,lang,rok) (+ skús 'N' pre sviatky). null = pre jazyk chýba.
  /// `hlava` je per-jazyk, preto sa rieši z kalendára toho istého jazyka.
  Future<Map<String, dynamic>?> _sourceForLang(
    String today,
    String lang,
    String rok,
  ) async {
    final cal = await _supabase
        .from('liturgical_calendar')
        .select('lectio_hlava')
        .eq('datum', today)
        .eq('locale_code', lang)
        .maybeSingle();
    final hlava = cal?['lectio_hlava'];
    if (hlava == null) return null;

    var source = await _supabase
        .from('lectio_sources')
        .select()
        .eq('hlava', hlava)
        .eq('lang', lang)
        .eq('rok', rok)
        .maybeSingle();
    if (source == null && rok != 'N') {
      source = await _supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', hlava)
          .eq('lang', lang)
          .eq('rok', 'N')
          .maybeSingle();
    }
    return source;
  }

  /// Fetch daily actio/quote based on liturgical calendar (fallback jazyk→EN→SK)
  Future<DailyQuote?> getDailyQuote({required String locale}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final cycle = await _cycleForDate(today, locale);
      final rok = await _rokForDate(today, cycle);

      Map<String, dynamic>? source;
      for (final lang in _fallbackChain(locale)) {
        source = await _sourceForLang(today, lang, rok);
        if (source != null) break;
      }

      // Názov slávenia v jazyku používateľa (pre fallback referenciu).
      final cal = await _supabase
          .from('liturgical_calendar')
          .select('celebration_title')
          .eq('datum', today)
          .eq('locale_code', locale)
          .maybeSingle();
      final celeb = (cal?['celebration_title'] as String?)?.trim();

      if (source == null && (celeb == null || celeb.isEmpty)) return null;
      return DailyQuote(
        text: source?['actio_text'],
        reference: source?['reference'] ?? celeb,
        suradnice: source?['suradnice_pismo'] as String?,
      );
    } catch (e) {
      appLogger.e('❌ Service: Error fetching daily quote: $e');
      return null;
    }
  }

  /// Fetch recent news
  Future<List<Map<String, dynamic>>> getNews({
    required String locale,
    int limit = 5,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final newsRes = await _supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(newsRes);
    } catch (e) {
      appLogger.e('❌ Service: Error fetching news: $e');
      return [];
    }
  }

  /// Fetch featured spiritual exercise
  Future<SpiritualExercise?> getFeaturedExercise({
    required String locale,
  }) async {
    final now = DateTime.now().toIso8601String().substring(0, 10);

    try {
      // Find locale ID
      final localeData = await _supabase
          .from('locales')
          .select('id')
          .eq('code', locale)
          .maybeSingle();

      if (localeData == null) {
        return null;
      }

      // Find exercise
      final response = await _supabase
          .from('spiritual_exercises')
          .select('''
            id,
            title,
            slug,
            description,
            image_url,
            home_image_url,
            start_date,
            end_date,
            location_name,
            location_city,
            location_country,
            leader_name,
            max_capacity,
            locale:locales(id, code, native_name)
          ''')
          .eq('is_published', true)
          .eq('is_active', true)
          .eq('locale_id', localeData['id'])
          .gte('end_date', now)
          .order('start_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return SpiritualExercise.fromJson(response);
      }
      return null;
    } catch (e) {
      appLogger.e('❌ Service: Error fetching featured exercise: $e');
      return null;
    }
  }

  /// Fetch full Lectio Divina content for a specific date (fallback jazyk→EN→SK)
  Future<Map<String, dynamic>?> getDailyLectio({
    required DateTime date,
    required String locale,
  }) async {
    final today = date.toIso8601String().substring(0, 10);
    try {
      appLogger.d(
        '🔍 Service: Načítavam lectio pre dátum: $today, jazyk: $locale',
      );
      final cycle = await _cycleForDate(today, locale);
      final rok = await _rokForDate(today, cycle);

      for (final lang in _fallbackChain(locale)) {
        final source = await _sourceForLang(today, lang, rok);
        if (source != null) {
          if (lang != locale) {
            appLogger.d('🔄 Service: lectio fallback $locale → $lang');
          }
          return source;
        }
      }

      appLogger.e(
        '❌ Service: Lectio nenájdené pre $today (locale $locale → en → sk)',
      );
      return null;
    } catch (e) {
      appLogger.e('❌ Service: Chyba pri načítavaní Lectio dát: $e');
      return null;
    }
  }
}

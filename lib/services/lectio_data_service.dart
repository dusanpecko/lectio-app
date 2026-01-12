import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spiritual_exercise.dart';
import '../utils/app_logger.dart';

class DailyQuote {
  final String? text;
  final String? reference;

  DailyQuote({this.text, this.reference});
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

  /// Fetch daily actio/quote based on liturgical calendar
  Future<DailyQuote?> getDailyQuote({required String locale}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      // 1. NAJPRV nájdeme správny liturgický rok
      final liturgicalYearsResponse = await _supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', locale)
          .lte('start_date', today)
          .gte('end_date', today);

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
            .lte('start_date', today)
            .gte('end_date', today);
        final skYearsList = skYearsResponse as List;
        if (skYearsList.isNotEmpty) {
          correctLiturgicalYear = skYearsList[0] as Map<String, dynamic>;
        }
      }

      // 2. Nájdi dnešný liturgický deň
      final calendarResponse = await _supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', today)
          .eq('locale_code', locale)
          .maybeSingle();

      if (calendarResponse == null ||
          calendarResponse['lectio_hlava'] == null) {
        return null;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      // 3. Určíme či použiť cyklus (A/B/C) alebo 'N'
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

      return DailyQuote(
        text: lectioSource?['actio_text'],
        reference: lectioSource?['reference'] ?? celebrationTitle,
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

  /// Fetch full Lectio Divina content for a specific date
  Future<Map<String, dynamic>?> getDailyLectio({
    required DateTime date,
    required String locale,
  }) async {
    final today = date.toIso8601String().substring(0, 10);

    try {
      appLogger.d(
        '🔍 Service: Načítavam lectio pre dátum: $today, jazyk: $locale',
      );

      // 1. NAJPRV nájdeme správny liturgický rok na základe dátumu
      final liturgicalYearsResponse = await _supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', locale)
          .lte('start_date', today)
          .gte('end_date', today);

      Map<String, dynamic>? correctLiturgicalYear;
      final liturgicalYearsList = liturgicalYearsResponse as List;

      if (liturgicalYearsList.isNotEmpty) {
        final yearData = liturgicalYearsList[0] as Map<String, dynamic>;
        correctLiturgicalYear = yearData;
        appLogger.i(
          '✅ Service: Nájdený liturgický rok: ${yearData['year']} '
          '(${yearData['start_date']} - ${yearData['end_date']}), '
          'cyklus: ${yearData['lectionary_cycle']}',
        );
      } else {
        // Fallback na slovenčinu ak aktuálny jazyk nemá liturgický rok
        if (locale != 'sk') {
          appLogger.d('🔄 Service: Hľadám liturgický rok v slovenčine...');
          final skYearsResponse = await _supabase
              .from('liturgical_years')
              .select()
              .eq('locale_code', 'sk')
              .lte('start_date', today)
              .gte('end_date', today);

          final skYearsList = skYearsResponse as List;
          if (skYearsList.isNotEmpty) {
            final skYearData = skYearsList[0] as Map<String, dynamic>;
            correctLiturgicalYear = skYearData;
            appLogger.i(
              '✅ Service: Nájdený SK liturgický rok: ${skYearData['year']} '
              '(${skYearData['start_date']} - ${skYearData['end_date']}), '
              'cyklus: ${skYearData['lectionary_cycle']}',
            );
          }
        }
      }

      // 2. Nájdi deň v liturgical_calendar
      var calendarResponse = await _supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', today)
          .eq('locale_code', locale)
          .maybeSingle();

      // Fallback na slovenčinu ak kalendár pre aktuálny jazyk neexistuje
      if (calendarResponse == null && locale != 'sk') {
        appLogger.d('🔄 Service: Skúšam načítať kalendár pre slovenčinu...');
        calendarResponse = await _supabase
            .from('liturgical_calendar')
            .select()
            .eq('datum', today)
            .eq('locale_code', 'sk')
            .maybeSingle();
      }

      if (calendarResponse == null) {
        appLogger.e(
          '❌ Service: Liturgický kalendár nenájdený pre dátum $today',
        );
        return null;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      if (lectioHlava == null) {
        debugPrint('❌ Service: Tento deň nemá priradenú lectio hlavičku');
        return null;
      }

      // 3. Určíme či použiť cyklus (A/B/C) alebo 'N' pre všedné dni
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      // Pre všedné dni (pondelok-sobota v cezročnom období) používame 'N'
      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday).+(týždňa|Week)',
      ).hasMatch(celebrationTitle);

      // Pre nedele a sviatky používame A/B/C
      final isSpecialDay =
          !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      // POUŽIJEME správny liturgický rok
      final lectionaryCycle = correctLiturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      // 4. Nájdi zodpovedajúci záznam v lectio_sources
      var lectioSource = await _supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', locale)
          .eq('rok', rokToSearch)
          .maybeSingle();

      // Fallback logika
      if (lectioSource == null) {
        appLogger.e(
          '❌ Service: Lectio source nenájdený pre $locale, rok $rokToSearch',
        );

        // Pre sviatky: skús rok 'N'
        if (isSpecialDay && rokToSearch != 'N') {
          lectioSource = await _supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', locale)
              .eq('rok', 'N')
              .maybeSingle();
        }

        // Fallback na slovenčinu
        if (lectioSource == null && locale != 'sk') {
          appLogger.d(
            '🔄 Service: Skúšam načítať lectio source pre slovenčinu...',
          );
          lectioSource = await _supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', 'sk')
              .eq('rok', rokToSearch)
              .maybeSingle();

          // Pre sviatky v slovenčine: aj tu skús 'N'
          if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
            lectioSource = await _supabase
                .from('lectio_sources')
                .select()
                .eq('hlava', lectioHlava)
                .eq('lang', 'sk')
                .eq('rok', 'N')
                .maybeSingle();
          }
        }
      }

      return lectioSource;
    } catch (e) {
      appLogger.e('❌ Service: Chyba pri načítavaní Lectio dát: $e');
      return null;
    }
  }
}

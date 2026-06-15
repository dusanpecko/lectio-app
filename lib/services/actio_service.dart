import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Načíta dnešný „actio" text z `lectio_sources`.
///
/// Logika je vytiahnutá z pôvodného `HomeScreen._fetchQuoteData` aby ju mohol
/// zdieľať starý aj nový (v2) home screen:
///   1. liturgický rok podľa dátumového rozsahu (fallback na `sk`),
///   2. dnešný liturgický deň z `liturgical_calendar`,
///   3. určenie cyklu (A/B/C pre sviatky/nedele, inak `N`),
///   4. nájdenie `lectio_sources` so správnym `actio_text` + fallbacky.
class ActioService {
  ActioService._();
  static final ActioService instance = ActioService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<String?> fetchTodaysActio(String locale) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      // 1. Liturgický rok podľa dátumového rozsahu (nie z calendar entry).
      Map<String, dynamic>? liturgicalYear;
      final years = await _supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', locale)
          .lte('start_date', today)
          .gte('end_date', today);
      if (years.isNotEmpty) {
        liturgicalYear = years.first;
      } else if (locale != 'sk') {
        // Fallback na slovenčinu.
        final sk = await _supabase
            .from('liturgical_years')
            .select()
            .eq('locale_code', 'sk')
            .lte('start_date', today)
            .gte('end_date', today);
        if (sk.isNotEmpty) {
          liturgicalYear = sk.first;
        }
      }

      // 2. Dnešný liturgický deň.
      final calendar = await _supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', today)
          .eq('locale_code', locale)
          .maybeSingle();

      if (calendar == null || calendar['lectio_hlava'] == null) {
        return null;
      }

      final lectioHlava = calendar['lectio_hlava'];
      final celebrationTitle = (calendar['celebration_title'] ?? '') as String;
      final celebrationRankNum = calendar['celebration_rank_num'];

      // 3. Cyklus A/B/C (sviatky/nedele) vs. 'N' (všedné dni).
      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday).+(týždňa|Week)',
      ).hasMatch(celebrationTitle);

      final isSpecialDay = !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      final lectionaryCycle = liturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      // 4. Nájdi lectio source s actio textom (+ fallbacky).
      var src = await _supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', locale)
          .eq('rok', rokToSearch)
          .maybeSingle();

      if (src == null && isSpecialDay && rokToSearch != 'N') {
        src = await _supabase
            .from('lectio_sources')
            .select()
            .eq('hlava', lectioHlava)
            .eq('lang', locale)
            .eq('rok', 'N')
            .maybeSingle();
      }

      if (src == null && locale != 'sk') {
        src = await _supabase
            .from('lectio_sources')
            .select()
            .eq('hlava', lectioHlava)
            .eq('lang', 'sk')
            .eq('rok', rokToSearch)
            .maybeSingle();

        if (src == null && isSpecialDay && rokToSearch != 'N') {
          src = await _supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', 'sk')
              .eq('rok', 'N')
              .maybeSingle();
        }
      }

      return src?['actio_text'] as String?;
    } catch (e) {
      appLogger.e('❌ Actio: chyba pri načítaní: $e');
      return null;
    }
  }
}

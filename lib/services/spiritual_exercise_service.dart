import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../utils/app_logger.dart';

/// Načítanie „featured" duchovného cvičenia pre home (v2).
class SpiritualExerciseService {
  SpiritualExerciseService._();
  static final SpiritualExerciseService instance =
      SpiritualExerciseService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  static const String _fields = '''
    id, title, slug, description, image_url, home_image_url,
    start_date, end_date, location_name, location_city, location_country,
    leader_name, max_capacity, locale:locales(id, code, native_name)
  ''';

  /// Najbližšie cvičenie pre daný jazyk.
  ///
  /// [onlyActive] = true (produkcia): len publikované, aktívne a budúce.
  /// [onlyActive] = false (test): zobrazí aj vypnuté/nepublikované záznamy.
  Future<SpiritualExercise?> fetchFeatured(
    String locale, {
    bool onlyActive = true,
  }) async {
    try {
      final localeData = await _supabase
          .from('locales')
          .select('id')
          .eq('code', locale)
          .maybeSingle();
      if (localeData == null) return null;

      var query = _supabase
          .from('spiritual_exercises')
          .select(_fields)
          .eq('locale_id', localeData['id']);

      if (onlyActive) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        query = query
            .eq('is_published', true)
            .eq('is_active', true)
            .gte('end_date', today);
      }

      final response = await query
          .order('start_date', ascending: onlyActive)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return SpiritualExercise.fromJson(response);
    } catch (e) {
      appLogger.e('❌ Featured exercise: $e');
      return null;
    }
  }
}

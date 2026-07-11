import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/novena.dart';
import '../models/prayer.dart' show PrayerCategory;
import '../utils/app_logger.dart';

/// Načítanie deviatnikov a ich kategórií. Obsah je verejný (RLS public-read
/// aktívnych) — číta sa priamo cez Supabase, vrátane dní (jeden dotaz;
/// deviatnikov je málo a detail tak funguje bez ďalšieho načítavania).
class NovenasService {
  NovenasService._();
  static final NovenasService instance = NovenasService._();

  Future<List<Novena>> fetchNovenas() async {
    try {
      final data = await Supabase.instance.client
          .from('novenas')
          .select(
            'id, shortcode, lang, category, title, description, image_url, '
            'intro_title, intro_content, intro_audio_url, '
            'conclusion_title, conclusion_content, conclusion_audio_url, '
            'display_order, '
            'novena_days(id, day_number, title, content, audio_url)',
          )
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('title', ascending: true);
      return (data as List)
          .map((e) => Novena.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ NovenasService.fetchNovenas: $e');
      rethrow;
    }
  }

  /// Kategórie deviatnikov — rovnaká štruktúra ako kategórie modlitieb,
  /// preto sa zdieľa model [PrayerCategory].
  Future<List<PrayerCategory>> fetchCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('novena_categories')
          .select(
            'code, title_sk, title_en, title_cz, title_es, title_fr, title_ptbr, title_de, sort_order',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => PrayerCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ NovenasService.fetchCategories: $e');
      return [];
    }
  }
}

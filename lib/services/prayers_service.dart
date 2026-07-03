import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/prayer.dart';
import '../utils/app_logger.dart';

/// Načítanie základných modlitieb a ich kategórií. Obsah je verejný
/// (RLS public-read aktívnych) — číta sa priamo cez Supabase.
class PrayersService {
  PrayersService._();
  static final PrayersService instance = PrayersService._();

  Future<List<Prayer>> fetchPrayers() async {
    try {
      final data = await Supabase.instance.client
          .from('prayers')
          .select(
            'id, shortcode, lang, category, title, content, display_order, audio_url',
          )
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('title', ascending: true);
      return (data as List)
          .map((e) => Prayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ PrayersService.fetchPrayers: $e');
      rethrow;
    }
  }

  Future<List<PrayerCategory>> fetchCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('prayer_categories')
          .select('code, title_sk, title_en, title_cz, title_es, title_fr, title_ptbr, title_de, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => PrayerCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ PrayersService.fetchCategories: $e');
      return [];
    }
  }
}

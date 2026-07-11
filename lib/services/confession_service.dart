import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/confession_mirror.dart';
import '../utils/app_logger.dart';

/// Načítanie spovedných zrkadiel (verejný obsah, RLS public-read aktívnych).
/// Jeden dotaz vráti aj sekcie s otázkami — zrkadiel je málo.
class ConfessionService {
  ConfessionService._();
  static final ConfessionService instance = ConfessionService._();

  Future<List<ConfessionMirror>> fetchMirrors() async {
    try {
      final data = await Supabase.instance.client
          .from('confession_mirrors')
          .select(
            'id, shortcode, lang, title, description, image_url, '
            'intro_text, intro_prayer, closing_prayer, '
            'guide_confession_flow, guide_invocation, guide_contrition, '
            'display_order, '
            'confession_sections(id, sort_order, title, '
            'confession_questions(id, sort_order, text))',
          )
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('title', ascending: true);
      return (data as List)
          .map((e) => ConfessionMirror.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ ConfessionService.fetchMirrors: $e');
      rethrow;
    }
  }
}

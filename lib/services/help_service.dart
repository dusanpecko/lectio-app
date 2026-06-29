import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/help_article.dart';
import '../utils/app_logger.dart';

/// Načítanie návodov sekcie „Pomoc". Obsah je verejný (RLS public-read
/// aktívnych) — číta sa priamo cez Supabase.
class HelpService {
  HelpService._();
  static final HelpService instance = HelpService._();

  Future<List<HelpArticle>> fetchArticles() async {
    try {
      final data = await Supabase.instance.client
          .from('help_articles')
          .select('id, slug, title, body, image_url, sort_order, platform')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => HelpArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appLogger.e('❌ HelpService.fetchArticles: $e');
      rethrow;
    }
  }
}

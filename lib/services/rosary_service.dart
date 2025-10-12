// lib/services/rosary_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rosary_model.dart';
import '../shared/rosary_constants.dart';

class RosaryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Získanie štatistík pre všetky kategórie
  Future<List<RosaryCategoryStats>> getCategoryStats(String lang) async {
    try {
      final response = await _supabase
          .from('lectio_divina_ruzenec')
          .select('kategoria, audio_nahravka, ilustracny_obrazok')
          .eq('lang', lang)
          .eq('publikovane', true);

      // Spracovanie štatistík pre každú kategóriu
      final Map<RosaryCategory, List<Map<String, dynamic>>> categoryData = {};

      for (final item in response) {
        final categoryString = item['kategoria'] as String?;

        if (categoryString != null &&
            RosaryConstants.isValidCategory(categoryString)) {
          final category = RosaryCategory.values.firstWhere(
            (e) => e.toString().split('.').last == categoryString,
          );

          categoryData.putIfAbsent(category, () => []).add(item);
        }
      }

      // Vytvorenie štatistík
      return RosaryCategory.values.map((category) {
        final data = categoryData[category] ?? [];
        return RosaryCategoryStats(
          category: category,
          totalCount: data.length,
          withAudio: data
              .where(
                (item) =>
                    item['audio_nahravka'] != null &&
                    (item['audio_nahravka'] as String).isNotEmpty,
              )
              .length,
          withImages: data
              .where(
                (item) =>
                    item['ilustracny_obrazok'] != null &&
                    (item['ilustracny_obrazok'] as String).isNotEmpty,
              )
              .length,
        );
      }).toList();
    } catch (e) {
      throw Exception('Chyba pri načítavaní štatistík: $e');
    }
  }

  // Získanie desiatkov pre kategóriu
  Future<List<RosaryDecade>> getDecadesForCategory(
    RosaryCategory category,
    String lang,
  ) async {
    try {
      final categoryString = category.toString().split('.').last;

      final response = await _supabase
          .from('lectio_divina_ruzenec')
          .select('*')
          .eq('kategoria', categoryString)
          .eq('lang', lang)
          .eq('publikovane', true)
          .order('poradie', ascending: true);

      return response
          .map<RosaryDecade>((json) => RosaryDecade.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Chyba pri načítavaní desiatkov: $e');
    }
  }

  // Získanie konkrétneho desiatka
  Future<RosaryDecade?> getDecade(
    RosaryCategory category,
    int order,
    String lang,
  ) async {
    try {
      final categoryString = category.toString().split('.').last;

      final response = await _supabase
          .from('lectio_divina_ruzenec')
          .select('*')
          .eq('kategoria', categoryString)
          .eq('poradie', order)
          .eq('lang', lang)
          .eq('publikovane', true)
          .maybeSingle();

      if (response == null) return null;

      return RosaryDecade.fromJson(response);
    } catch (e) {
      throw Exception('Chyba pri načítavaní desiatka: $e');
    }
  }

  // Získanie navigácie pre desiatka
  Future<RosaryNavigation> getDecadeNavigation(
    RosaryCategory category,
    int currentOrder,
    String lang,
  ) async {
    try {
      final decades = await getDecadesForCategory(category, lang);

      final currentIndex = decades.indexWhere((d) => d.order == currentOrder);
      if (currentIndex == -1) {
        return const RosaryNavigation(
          canGoToPrevious: false,
          canGoToNext: false,
        );
      }

      RosaryDecade? previousDecade;
      RosaryDecade? nextDecade;

      if (currentIndex > 0) {
        previousDecade = decades[currentIndex - 1];
      }

      if (currentIndex < decades.length - 1) {
        nextDecade = decades[currentIndex + 1];
      }

      return RosaryNavigation(
        previousDecade: previousDecade,
        nextDecade: nextDecade,
        canGoToPrevious: previousDecade != null,
        canGoToNext: nextDecade != null,
      );
    } catch (e) {
      throw Exception('Chyba pri načítavaní navigácie: $e');
    }
  }

  // Vyhľadávanie v ružencom
  Future<List<RosaryDecade>> searchDecades(
    String query,
    String lang, {
    RosaryCategory? category,
    bool onlyWithAudio = false,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('lectio_divina_ruzenec')
          .select('*')
          .eq('lang', lang)
          .eq('publikovane', true);

      if (category != null) {
        final categoryString = category.toString().split('.').last;
        queryBuilder = queryBuilder.eq('kategoria', categoryString);
      }

      if (onlyWithAudio) {
        queryBuilder = queryBuilder.not('audio_nahravka', 'is', null);
      }

      // Vyhľadávanie v texte
      queryBuilder = queryBuilder.or(
        'ruzenec.ilike.%$query%,'
        'biblicky_text.ilike.%$query%,'
        'uvod.ilike.%$query%,'
        'lectio_text.ilike.%$query%,'
        'meditatio_text.ilike.%$query%,'
        'contemplatio_text.ilike.%$query%,'
        'actio_text.ilike.%$query%',
      );

      final response = await queryBuilder.order('kategoria').order('poradie');

      return response
          .map<RosaryDecade>((json) => RosaryDecade.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Chyba pri vyhľadávaní: $e');
    }
  }

  // Získanie najnovších desiatkov
  Future<List<RosaryDecade>> getLatestDecades(
    String lang, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('lectio_divina_ruzenec')
          .select('*')
          .eq('lang', lang)
          .eq('publikovane', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<RosaryDecade>((json) => RosaryDecade.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Chyba pri načítavaní najnovších: $e');
    }
  }

  // Overenie dostupnosti kategórie
  Future<bool> isCategoryAvailable(RosaryCategory category, String lang) async {
    try {
      final categoryString = category.toString().split('.').last;

      final response = await _supabase
          .from('lectio_divina_ruzenec')
          .select('id')
          .eq('kategoria', categoryString)
          .eq('lang', lang)
          .eq('publikovane', true)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

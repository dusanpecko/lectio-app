// lib/services/adoration_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/adoration_model.dart';

class AdorationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Získanie štatistík adorácií
  Future<AdorationStats> getStats(String lang) async {
    try {
      final response = await _supabase
          .from('lectio_divina_adoracia')
          .select('audio_nahravka, ilustracny_obrazok')
          .eq('lang', lang)
          .eq('publikovane', true);

      final totalCount = response.length;
      final withAudio = response
          .where(
            (item) =>
                item['audio_nahravka'] != null &&
                (item['audio_nahravka'] as String).isNotEmpty,
          )
          .length;
      final withImages = response
          .where(
            (item) =>
                item['ilustracny_obrazok'] != null &&
                (item['ilustracny_obrazok'] as String).isNotEmpty,
          )
          .length;

      return AdorationStats(
        totalCount: totalCount,
        withAudio: withAudio,
        withImages: withImages,
      );
    } catch (e) {
      throw Exception('Chyba pri načítavaní štatistík adorácií: $e');
    }
  }

  // Získanie všetkých adorácií
  Future<List<Adoration>> getAdorations(String lang) async {
    try {
      final response = await _supabase
          .from('lectio_divina_adoracia')
          .select('*')
          .eq('lang', lang)
          .eq('publikovane', true)
          .order('poradie', ascending: true);

      return response
          .map<Adoration>((json) => Adoration.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Chyba pri načítavaní adorácií: $e');
    }
  }

  // Získanie konkrétnej adorácie
  Future<Adoration?> getAdoration(String id) async {
    try {
      final response = await _supabase
          .from('lectio_divina_adoracia')
          .select('*')
          .eq('id', id)
          .eq('publikovane', true)
          .single();

      return Adoration.fromJson(response);
    } catch (e) {
      throw Exception('Chyba pri načítavaní adorácie: $e');
    }
  }

  // Získanie nasledujúcej adorácie
  Future<Adoration?> getNextAdoration(int currentOrder, String lang) async {
    try {
      final response = await _supabase
          .from('lectio_divina_adoracia')
          .select('*')
          .eq('lang', lang)
          .eq('publikovane', true)
          .gt('poradie', currentOrder)
          .order('poradie', ascending: true)
          .limit(1);

      if (response.isEmpty) return null;

      return Adoration.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }

  // Získanie predchádzajúcej adorácie
  Future<Adoration?> getPreviousAdoration(int currentOrder, String lang) async {
    try {
      final response = await _supabase
          .from('lectio_divina_adoracia')
          .select('*')
          .eq('lang', lang)
          .eq('publikovane', true)
          .lt('poradie', currentOrder)
          .order('poradie', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return Adoration.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }
}

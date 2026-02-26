// lib/services/stations_of_cross_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stations_of_cross_model.dart';

class StationsOfCrossService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Získanie všetkých publikovaných krížových ciest pre daný jazyk
  Future<List<StationsOfCross>> getStationsOfCross(String lang) async {
    try {
      final response = await _supabase
          .from('krizove_cesty')
          .select('*, krizove_cesty_zastavenia(id, audio, obrazok)')
          .eq('lang', lang)
          .eq('publikovane', true)
          .order('poradie', ascending: true);

      return response
          .map<StationsOfCross>(
            (json) => StationsOfCross.fromJson(json),
          )
          .toList();
    } catch (e) {
      throw Exception('Chyba pri načítavaní krížových ciest: $e');
    }
  }

  /// Získanie konkrétnej krížovej cesty s plnými zastaveniami
  Future<StationsOfCross?> getStationsOfCrossDetail(String id) async {
    try {
      final response = await _supabase
          .from('krizove_cesty')
          .select('*, krizove_cesty_zastavenia(*)')
          .eq('id', id)
          .eq('publikovane', true)
          .single();

      return StationsOfCross.fromJson(response);
    } catch (e) {
      throw Exception('Chyba pri načítavaní krížovej cesty: $e');
    }
  }

  /// Získanie nasledujúcej krížovej cesty
  Future<StationsOfCross?> getNext(int currentOrder, String lang) async {
    try {
      final response = await _supabase
          .from('krizove_cesty')
          .select('id, nazov, poradie, autor, ilustracny_obrazok')
          .eq('lang', lang)
          .eq('publikovane', true)
          .gt('poradie', currentOrder)
          .order('poradie', ascending: true)
          .limit(1);

      if (response.isEmpty) return null;
      return StationsOfCross.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }

  /// Získanie predchádzajúcej krížovej cesty
  Future<StationsOfCross?> getPrevious(int currentOrder, String lang) async {
    try {
      final response = await _supabase
          .from('krizove_cesty')
          .select('id, nazov, poradie, autor, ilustracny_obrazok')
          .eq('lang', lang)
          .eq('publikovane', true)
          .lt('poradie', currentOrder)
          .order('poradie', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return StationsOfCross.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }
}

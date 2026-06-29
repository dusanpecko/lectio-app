import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// In-app admin úpravy Lectio krokov: editácia textu + pregenerovanie TTS audia.
/// Volá admin API s Bearer tokenom prihláseného používateľa; backend overí rolu
/// `admin` cez service-role (RLS na priamy zápis neobchádzame).
class LectioAdminService {
  LectioAdminService._();
  static final LectioAdminService instance = LectioAdminService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  Map<String, String> get _headers {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Je prihlásený používateľ administrátor?
  Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final data = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return (data?['role'] as String?) == 'admin';
    } catch (e) {
      appLogger.e('❌ LectioAdminService.isAdmin: $e');
      return false;
    }
  }

  /// Uloží upravený text kroku (napr. `lectio_text`) do lectio_sources.
  Future<void> updateStepText(int sourceId, String textField, String text) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/api/admin/lectio-sources/$sourceId'),
      headers: _headers,
      body: jsonEncode({textField: text}),
    );
    if (res.statusCode != 200) {
      throw Exception('Uloženie zlyhalo (${res.statusCode}): ${res.body}');
    }
  }

  /// Pre-/regeneruje audio pre daný krok (`lectio`/`meditatio`/…). Vráti novú URL.
  Future<String> regenerateStepAudio(int sourceId, String field) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/admin/lectio-sources/$sourceId/regenerate-audio'),
      headers: _headers,
      body: jsonEncode({'field': field}),
    );
    if (res.statusCode != 200) {
      throw Exception('Generovanie audia zlyhalo (${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['audioUrl'] as String;
  }

  /// Pregeneruje CELÉ audio dňa pre `lectio_sources.id`: **podcast epizódu** +
  /// kombinované **dlhé** (`full_long_audio`) a **krátke** (`full_short_audio`)
  /// audio. Volá `/api/podcast/generate` (ffmpeg + ElevenLabs, môže trvať
  /// desiatky sekúnd až minúty). Spustiť po úprave/pregenerovaní krokov, aby sa
  /// celé audio aktualizovalo z nového textu.
  Future<({bool long, bool short, int? durationSeconds})> regenerateFullAudio(
    int lectioSourceId,
  ) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/podcast/generate'),
          headers: _headers,
          body: jsonEncode({'lectio_source_id': lectioSourceId}),
        )
        .timeout(const Duration(seconds: 300));

    final body = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode == 422) {
      final missing = (body['missing'] as List?)?.join(', ') ?? '';
      throw Exception(
        'Niektoré kroky nemajú audio — najprv ich pregeneruj. Chýba: $missing',
      );
    }
    if (res.statusCode != 200) {
      throw Exception(
        'Generovanie zlyhalo (${res.statusCode}): ${body['error'] ?? res.body}',
      );
    }

    final variants = (body['lectioVariants'] as Map?) ?? const {};
    return (
      long: variants['long'] == true,
      short: variants['short'] == true,
      durationSeconds: (body['durationSeconds'] as num?)?.toInt(),
    );
  }
}

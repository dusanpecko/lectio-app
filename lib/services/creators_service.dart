import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../utils/app_logger.dart';

/// Načíta obsah tvorcov (Creator Studio) z verejného API. Gate-logika pobožností
/// (is_active/publikovane, jazykové kódy, owner filter) je server-side — appka
/// dostáva už hotový, filtrovaný obsah pre daný jazyk. Fail-soft (sekcia sa skryje).
///
/// Každý dotaz na obsah nesie `platform` a `app_version`: server podľa nich
/// vyhodnotí prepínač sekcie (stav off/náhľad/zapnuté + rozsah verzií appky).
/// Bez `app_version` sa build považuje za starý a obsah nedostane.
class CreatorsService {
  CreatorsService._();
  static final CreatorsService instance = CreatorsService._();

  // Rovnaký prepínač base URL ako ostatné services (inbox/documents/fcm…).
  // Lokálne testovanie: nastav NEXT_PUBLIC_BACKEND_URL v mobile/.env.
  String get _baseUrl => dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  String? get _token => Supabase.instance.client.auth.currentSession?.accessToken;

  // Platforma + verzia buildu do každého dotazu na obsah tvorcov. Server z toho
  // vyhodnocuje `app_feature_flags` (min/max verzia) — appka, ktorá parameter
  // neposiela, je pre server stará a obsah nedostane.
  String? _appQueryCache;
  Future<String> _appQueryBase() async {
    if (_appQueryCache != null) return _appQueryCache!;
    final info = await PackageInfo.fromPlatform();
    final platform = Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other';
    // Zámerne BEZ buildu za '+': verzia je časťou URL, teda aj kľúča CDN cache,
    // a build number by ju delil pri každom internom builde.
    _appQueryCache = 'platform=$platform&app_version=${info.version}';
    return _appQueryCache!;
  }

  /// Query parametre každého dotazu na obsah tvorcov.
  Future<String> _appQuery() async {
    final base = await _appQueryBase();
    // Testerovi pridá `preview=1` — iná URL, teda iný kľúč CDN cache. Bez toho by
    // mu edge vrátil uloženú verejnú odpoveď bez interných (testovacích) tvorcov
    // a smoke test by mlčky nefungoval. Oprávnenie dáva token, nie tento parameter.
    return await _isTester() ? '$base&preview=1' : base;
  }

  // Testeri (admin/editor/moderátor) posielajú pri obsahu token — vďaka nemu
  // vidia sekciu aj v stave „náhľad" a v nej interných (testovacích) tvorcov.
  // Bežný používateľ ho ZÁMERNE neposiela: požiadavka s hlavičkou Authorization
  // obchádza CDN cache, na ktorej stoja /discover aj /creator/[slug].
  static const Set<String> _testerRoles = {'admin', 'editor', 'moderator'};
  bool? _testerCache;
  String? _testerForUserId;

  Future<bool> _isTester() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    if (_testerCache != null && _testerForUserId == user.id) return _testerCache!;
    _testerForUserId = user.id;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      _testerCache = _testerRoles.contains((data?['role'] as String?) ?? 'user');
    } catch (e) {
      appLogger.d('CreatorsService._isTester skipped: $e');
      _testerCache = false;
    }
    return _testerCache!;
  }

  /// Hlavičky pre dotaz na obsah tvorcov (token len testerom, viď vyššie).
  Future<Map<String, String>> _contentHeaders() async {
    final t = _token;
    if (t == null || !await _isTester()) return const {};
    return {'Authorization': 'Bearer $t'};
  }

  /// Počet sledovateľov + či ich prihlásený používateľ sleduje.
  Future<({int count, bool following})> followStatus(String profileId) async {
    try {
      final headers = <String, String>{};
      final t = _token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/follow?profileId=$profileId'), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return (count: 0, following: false);
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      return (count: (d['count'] as num?)?.toInt() ?? 0, following: d['following'] == true);
    } catch (e) {
      appLogger.d('CreatorsService.followStatus skipped: $e');
      return (count: 0, following: false);
    }
  }

  /// Prepne sledovanie tvorcu. Vráti `null`, ak používateľ nie je prihlásený.
  Future<({int count, bool following})?> setFollow(String profileId, bool follow) async {
    final t = _token;
    if (t == null) return null;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/creator-content/follow?profileId=$profileId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: jsonEncode({'follow': follow}),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      return (count: (d['count'] as num?)?.toInt() ?? 0, following: d['following'] == true);
    } catch (e) {
      appLogger.d('CreatorsService.setFollow skipped: $e');
      return null;
    }
  }

  /// Detail duchovného cvičenia tvorcu (pre in-app prihlášku).
  Future<CreatorExerciseDetail?> fetchExercise(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/exercise/$id?${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final ex = (jsonDecode(res.body) as Map<String, dynamic>)['exercise'];
      return ex is Map ? CreatorExerciseDetail.fromJson(ex.cast<String, dynamic>()) : null;
    } catch (e) {
      appLogger.d('CreatorsService.fetchExercise skipped: $e');
      return null;
    }
  }

  /// Odošle prihlášku na DC tvorcu (`/api/dc/[id]/register`, verejný, bez Mollie).
  /// Vráti `ok=true` pri úspechu; inak `error` (napr. 'full', 'field_required'+`field`).
  Future<({bool ok, bool already, String? error, String? field})> registerExercise(
      String id, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/api/dc/$id/register'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      final d = (jsonDecode(res.body) as Map?)?.cast<String, dynamic>() ?? const {};
      if (res.statusCode == 200 && d['success'] == true) {
        // `already` = duplicita (rovnaký e-mail už prihlásený) → nič sa neuložilo/neposlalo.
        return (ok: true, already: d['already'] == true, error: null, field: null);
      }
      return (ok: false, already: false, error: d['error']?.toString() ?? 'error', field: d['field']?.toString());
    } catch (e) {
      appLogger.d('CreatorsService.registerExercise skipped: $e');
      return (ok: false, already: false, error: 'network', field: null);
    }
  }

  // Anonymné zariadenie (ako web localStorage lectio_device_key) — pri prihlásení
  // ho backend ignoruje (event sa viaže na user_id).
  static const String _deviceKeyPref = 'creator_device_key';
  String? _deviceKeyCache;
  Future<String> _deviceKey() async {
    if (_deviceKeyCache != null) return _deviceKeyCache!;
    final prefs = await SharedPreferences.getInstance();
    var k = prefs.getString(_deviceKeyPref);
    if (k == null || k.isEmpty) {
      final r = Random();
      k = 'dk_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_'
          '${List.generate(10, (_) => r.nextInt(36).toRadixString(36)).join()}';
      await prefs.setString(_deviceKeyPref, k);
    }
    _deviceKeyCache = k;
    return k;
  }

  /// Konzumačný event série tvorcu (view/play/complete) → `program_events`
  /// (creator štatistiky, Fáza 3). Fire-and-forget; zlyhanie ticho preskočí.
  Future<void> track({
    required String programId,
    String? sessionId,
    required String action, // 'view' | 'play' | 'complete'
    int? secondsListened,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final t = _token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
      final body = <String, dynamic>{
        'program_id': programId,
        'action': action,
        'device_key': await _deviceKey(),
        'session_id': ?sessionId,
        'seconds_listened': ?secondsListened,
      };
      await http
          .post(Uri.parse('$_baseUrl/api/programs/track'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      appLogger.d('CreatorsService.track skipped: $e');
    }
  }

  /// Adresár overených tvorcov s publikovaným obsahom v danom jazyku.
  Future<List<CreatorSummary>> fetchCreators(String lang) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/creators?lang=$lang&${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['creators'] as List?) ?? const [])
          .map((e) => CreatorSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      appLogger.d('CreatorsService.fetchCreators skipped: $e');
      return const [];
    }
  }

  /// Adresár tvorcov + všetok ich publikovaný obsah v jednom volaní.
  /// Nahrádza „načítaj tvorcov a potom každého zvlášť" — jeden request, CDN cache.
  Future<CreatorFeed> fetchDiscover(String lang) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/discover?lang=$lang&${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const CreatorFeed();
      return CreatorFeed.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      appLogger.d('CreatorsService.fetchDiscover skipped: $e');
      return const CreatorFeed();
    }
  }

  /// ID tvorcov, ktorých prihlásený používateľ sleduje. Bez prihlásenia prázdne
  /// — sekcia „Sledujem" sa potom len nezobrazí.
  Future<Set<String>> fetchFollowedIds() async {
    final t = _token;
    if (t == null) return const {};
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/follows'),
              headers: {'Authorization': 'Bearer $t'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const {};
      final ids = (jsonDecode(res.body) as Map<String, dynamic>)['profile_ids'] as List?;
      return (ids ?? const []).map((e) => e.toString()).toSet();
    } catch (e) {
      appLogger.d('CreatorsService.fetchFollowedIds skipped: $e');
      return const {};
    }
  }

  /// Kompletný balík jedného tvorcu (profil + série + pobožnosti) v danom jazyku.
  /// Vráti `null` ak tvorca neexistuje / nie je dostupný.
  Future<CreatorBundle?> fetchCreator(String slug, String lang) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/creator/$slug?lang=$lang&${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['creator'] == null) return null;
      return CreatorBundle.fromJson(data);
    } catch (e) {
      appLogger.d('CreatorsService.fetchCreator skipped: $e');
      return null;
    }
  }

  /// Kompletná séria tvorcu (program + časti + médiá).
  Future<CreatorSeriesDetail?> fetchSeries(String seriesId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/series/$seriesId?${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['series'] == null) return null;
      return CreatorSeriesDetail.fromJson(data);
    } catch (e) {
      appLogger.d('CreatorsService.fetchSeries skipped: $e');
      return null;
    }
  }

  /// Detail ruženca tvorcu (úvod + desiatky + záver + audio celého ruženca).
  Future<CreatorRosaryDetail?> fetchRosary(String rosaryId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/rosary/$rosaryId?${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['rosary'] == null) return null;
      return CreatorRosaryDetail.fromJson(data);
    } catch (e) {
      appLogger.d('CreatorsService.fetchRosary skipped: $e');
      return null;
    }
  }

  /// Epizódy podcastu tvorcu (z jeho RSS feedu, parsuje backend).
  Future<List<PodcastEpisodeItem>> fetchPodcastEpisodes(String podcastId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/creator-content/podcast/$podcastId/episodes?${await _appQuery()}'),
              headers: await _contentHeaders())
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['episodes'] as List?) ?? const [])
          .map((e) => PodcastEpisodeItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      appLogger.d('CreatorsService.fetchPodcastEpisodes skipped: $e');
      return const [];
    }
  }
}

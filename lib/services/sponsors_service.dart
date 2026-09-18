import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/sponsor.dart';
import '../utils/app_logger.dart';

/// Sponzori („Podporili nás") z verejného API `/api/sponsors?lang=…`.
///
/// Fail-soft: pri chybe siete vráti prázdny zoznam a sekcia sa nezobrazí.
/// Krátka pamäťová cache per jazyk, nech home aj O aplikácii nesťahujú dvakrát;
/// server má navyše CDN cache 5 min.
class SponsorsService {
  SponsorsService._();
  static final SponsorsService instance = SponsorsService._();

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  static const Duration _ttl = Duration(minutes: 5);
  final Map<String, ({DateTime at, List<Sponsor> data})> _cache = {};

  Future<List<Sponsor>> fetchSponsors(String lang, {bool force = false}) async {
    final cached = _cache[lang];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.at) < _ttl) {
      return cached.data;
    }
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/sponsors?lang=$lang'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        appLogger.w('SponsorsService: HTTP ${res.statusCode}');
        return cached?.data ?? const [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['sponsors'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Sponsor.fromJson(e.cast<String, dynamic>()))
          .where((s) => s.name.isNotEmpty)
          .toList(growable: false);
      _cache[lang] = (at: DateTime.now(), data: list);
      return list;
    } catch (e) {
      appLogger.w('SponsorsService: fetch failed: $e');
      return cached?.data ?? const [];
    }
  }
}

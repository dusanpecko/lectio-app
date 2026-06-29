import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/support_campaign.dart';
import '../utils/app_logger.dart';

/// Načíta kampaň „Podporte" z verejného API. Suma sa počíta server-side
/// (donations + bankové dary), klient dostane len agregované čísla.
class SupportCampaignService {
  SupportCampaignService._();
  static final SupportCampaignService instance = SupportCampaignService._();

  static const _baseUrl = 'https://www.lectio.one';

  // In-memory cache — aby sa kampaň nenačítavala znova pri každom otvorení
  // rozbaľovačky „Náš príbeh". Drží sa počas behu appky.
  SupportCampaign? _cache;
  bool _fetched = false;

  /// Naposledy načítaná kampaň (synchrónne, bez siete) — `null` ak ešte
  /// nebola načítaná. Umožňuje okamžité vykreslenie bez blikania.
  SupportCampaign? get cached => _cache;

  /// Vráti aktívnu kampaň, alebo `null` ak je vypnutá/nedostupná (sekcia sa
  /// jednoducho nezobrazí — fail-soft). Po prvom úspešnom načítaní vracia
  /// hodnotu z cache (bez ďalšieho sieťového volania), kým si nevyžiadaš
  /// `force: true`.
  Future<SupportCampaign?> fetch({bool force = false}) async {
    if (_fetched && !force) return _cache;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/support/campaign'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _cache;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _cache = data['active'] == true ? SupportCampaign.fromJson(data) : null;
      _fetched = true;
      return _cache;
    } catch (e) {
      appLogger.d('SupportCampaign: fetch skipped: $e');
      return _cache; // fail-soft na poslednú známu hodnotu
    }
  }
}

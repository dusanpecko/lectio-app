import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

/// Stav projektovej zbierky (seed + účelové dary vs cieľ).
class CampaignProgress {
  final double goal;
  final double raised;
  final double percent; // 0..1

  const CampaignProgress({
    required this.goal,
    required this.raised,
    required this.percent,
  });
}

/// Načíta reálny stav projektovej kampane z backendu
/// (`/api/projects/{slug}/campaign`).
class ProjectCampaignService {
  ProjectCampaignService._();
  static final ProjectCampaignService instance = ProjectCampaignService._();

  static const _baseUrl = 'https://www.lectio.one';

  Future<CampaignProgress?> fetch(String slug) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/projects/$slug/campaign'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return CampaignProgress(
        goal: (j['goal'] as num?)?.toDouble() ?? 0,
        raised: (j['raised'] as num?)?.toDouble() ?? 0,
        percent: (j['percent'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      appLogger.d('ProjectCampaign: fetch skipped: $e');
      return null;
    }
  }
}

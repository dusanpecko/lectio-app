import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'umami_analytics_service.dart';

/// Typ nahlásenej chyby → (report_type, error_severity) pre error_reports.
enum ErrorReportKind { typo, grammar, meaning, audio }

extension ErrorReportKindX on ErrorReportKind {
  String get reportType => this == ErrorReportKind.audio ? 'audio' : 'text';
  String get severity => switch (this) {
        ErrorReportKind.typo => 'low',
        ErrorReportKind.grammar => 'medium',
        ErrorReportKind.meaning => 'high',
        ErrorReportKind.audio => 'medium',
      };
  String get trKey => 'error_report.type_$name';
}

/// Nahlásenie chyby v lectiu (11.2.4) — preklep, gramatika, význam alebo zle
/// nahovorené audio. Ide na `POST /api/report-error` → tabuľka `error_reports`
/// (admin /admin/error-reports) + push adminom. V1 appke to chýbalo od v2
/// redizajnu; ľudia si to pýtali (Dušan 23. 9.).
class ErrorReportService {
  ErrorReportService._();
  static final ErrorReportService instance = ErrorReportService._();

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  Future<bool> submit({
    required ErrorReportKind kind,
    required String lang,
    required String stepKey,
    required String stepName,
    int? lectioId,
    String? lectioDate,
    String? originalText,
    String? correctedText,
    String? notes,
  }) async {
    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      final session = auth.currentSession;
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/report-error'),
            headers: {
              'Content-Type': 'application/json',
              if (session != null)
                'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'report_type': kind.reportType,
              'error_severity': kind.severity,
              'lang': lang,
              'step_key': stepKey,
              'step_name': stepName,
              'lectio_id': lectioId,
              'lectio_date': lectioDate,
              'original_text': originalText,
              'corrected_text': correctedText,
              'additional_notes': notes,
              'user_email': user?.email,
              'user_id': user?.id,
              'app_version': appVersion,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 12));
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) appLogger.w('Error report failed: ${res.statusCode} ${res.body}');
      UmamiAnalyticsService().trackEvent(
        'error_report',
        eventData: {
          'type': kind.name,
          'step': stepKey,
          'language': lang,
          'ok': ok,
        },
      );
      return ok;
    } catch (e) {
      appLogger.e('Error report exception: $e');
      return false;
    }
  }
}

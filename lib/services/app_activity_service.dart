import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Meranie retencie (11.2.4): raz za lokálny deň pošle backendu stabilné
/// anonymné ID zariadenia → DAU/WAU/MAU a kohorty D1/D7/D30 v admine.
///
/// Prečo nie Umami: Umami počíta „návštevníkov“ z odtlačku (UA + IP) a nevie
/// kohorty. Po 8 mesiacoch sme mali DAU/MAU 8 % a nevedeli, koľko nových
/// ľudí ostáva — bez toho sa nedá vyhodnotiť nič ďalšie.
///
/// Bez PII: uuid vzniká lokálne (Random.secure), žije v shared prefs
/// (prežije aktualizácie, nie preinštalovanie — reinštalácia = nové
/// zariadenie, čo je pre kohorty správne). Prihlásený používateľ pošle
/// Bearer token, backend si user_id vezme z neho, nikdy z tela.
class AppActivityService {
  AppActivityService._();
  static final AppActivityService instance = AppActivityService._();

  static const _kDeviceId = 'app_activity_device_id';
  static const _kLastDay = 'app_activity_last_day';

  String? _appLanguage;
  bool _inFlight = false;

  /// Jazyk appky (volá main.dart pri zmene locale, rovnako ako pre Umami).
  void setAppLanguage(String langCode) => _appLanguage = langCode;

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  /// Zavolať pri štarte a pri každom návrate do popredia. Idempotentné:
  /// druhé volanie v ten istý lokálny deň nič neposiela.
  Future<void> recordOpen() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(_kLastDay) == today) return;

      var deviceId = prefs.getString(_kDeviceId);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _uuidV4();
        await prefs.setString(_kDeviceId, deviceId);
      }

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      String? tz;
      try {
        // flutter_timezone 4.x vracia TimezoneInfo (identifier = IANA názov)
        tz = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {}

      final headers = <String, String>{'Content-Type': 'application/json'};
      // Pri štarte býva session ešte neobnovená (prvý test 22. 9.: prihlásený Pixel
      // sa zapísal anonymne) → chvíľu počkať, či sa objaví. Backend user_id doplní
      // aj neskôr, ale kohorty prihlásených chceme mať správne od prvého dňa.
      var token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        for (var i = 0; i < 6 && token == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          token = Supabase.instance.client.auth.currentSession?.accessToken;
        }
      }
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/app/open'),
            headers: headers,
            body: jsonEncode({
              'device_id': deviceId,
              'local_day': today,
              'platform': Platform.isIOS
                  ? 'ios'
                  : Platform.isAndroid
                      ? 'android'
                      : Platform.isMacOS
                          ? 'macos'
                          : 'unknown',
              'lang': _appLanguage ??
                  PlatformDispatcher.instance.locale.languageCode,
              'app_version': appVersion,
              'tz': tz,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(_kLastDay, today);
      } else {
        debugPrint('AppActivity: /api/app/open → ${response.statusCode}');
      }
    } catch (e) {
      // Offline alebo chyba siete: nič sa neukladá, skúsi sa pri ďalšom návrate.
      debugPrint('AppActivity: $e');
    } finally {
      _inFlight = false;
    }
  }

  /// RFC 4122 v4 bez závislosti na balíku uuid.
  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    final s = List.generate(16, h).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }
}

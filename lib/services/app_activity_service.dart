import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
  /// Bolo dnešné hlásenie odoslané s prihláseným účtom? Ak nie a používateľ sa
  /// prihlási, pošle sa znova — server doplní user_id k dnešnému dňu.
  static const _kLastDayAuthed = 'app_activity_last_day_authed';
  /// Lokálne počítadlo RÔZNYCH dní, v ktorých bola appka otvorená (aj offline,
  /// nezávisle od úspechu hlásenia). Používa ho kontextová výzva na podporu
  /// a hodnotenie (11.2.4: „po 7 rôznych dňoch používania“).
  static const _kDaysCount = 'app_activity_days_count';
  static const _kDaysCountLastDay = 'app_activity_days_count_last_day';

  /// Čas v appke (11.2.5): `{"YYYY-MM-DD": [sekundy v popredí, sekundy
  /// počúvania]}` za posledných [_usageKeepDays] dní. Posiela sa kumulatívne
  /// s `/api/app/open` (server hodnoty prepíše). Popredie a počúvanie sú dve
  /// rôzne čísla — kto si pustí lectio a zamkne telefón, počúva, ale v popredí
  /// nie je. NIKDY ich nesčítavať.
  static const _kUsage = 'app_usage_v1';
  static const _kUsageLastFlush = 'app_usage_last_flush_ms';
  static const _usageKeepDays = 7;
  static const _usageFlushEvery = Duration(minutes: 10);
  /// Strop jedného pobytu v popredí — lectio drží obrazovku zapnutú
  /// (wakelock), telefón položený na stole by inak nafúkol čas.
  static const _maxForegroundSession = Duration(hours: 3);

  DateTime? _foregroundSince;

  String? _appLanguage;
  bool _inFlight = false;
  bool _authHooked = false;

  /// Po prihlásení zopakuj dnešné hlásenie (anonymné → s účtom). Volať raz.
  void hookAuthChanges() {
    if (_authHooked) return;
    _authHooked = true;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        recordOpen();
      }
    });
  }

  /// Jazyk appky (volá main.dart pri zmene locale, rovnako ako pre Umami).
  void setAppLanguage(String langCode) => _appLanguage = langCode;

  // ── Čas v appke ───────────────────────────────────────────────────────────

  /// Appka je v popredí (štart, návrat z pozadia). Opakované volanie nič nemení.
  void onForeground() {
    // Štart na pozadí (FCM, widget) nie je pobyt v appke.
    final state = SchedulerBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _foregroundSince ??= DateTime.now();
  }

  /// Appka odišla do pozadia / zatvára sa → pripíše čas v popredí a pošle súčty.
  Future<void> onBackground() async {
    final since = _foregroundSince;
    _foregroundSince = null;
    if (since != null) {
      var spent = DateTime.now().difference(since);
      if (spent > _maxForegroundSession) spent = _maxForegroundSession;
      if (spent.inSeconds > 0) {
        await _addUsage(since, foreground: spent.inSeconds);
      }
    }
    await flushUsage();
  }

  /// Volá MediaPlayerBus počas prehrávania (aj na pozadí).
  Future<void> addListenSeconds(int seconds) async {
    if (seconds <= 0) return;
    await _addUsage(DateTime.now(), listen: seconds);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, List<int>> _readUsage(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kUsage);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).map((e) => (e as num).toInt()).toList()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _addUsage(DateTime at, {int foreground = 0, int listen = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    // Čítanie a zápis bez await medzi nimi → súbežné volania sa neprepíšu.
    final usage = _readUsage(prefs);
    final key = _dayKey(at);
    final cur = usage[key] ?? [0, 0];
    usage[key] = [cur[0] + foreground, cur[1] + listen];
    final oldest = _dayKey(DateTime.now().subtract(const Duration(days: _usageKeepDays)));
    usage.removeWhere((k, _) => k.compareTo(oldest) < 0);
    await prefs.setString(_kUsage, jsonEncode(usage));
  }

  List<Map<String, dynamic>> _usagePayload(SharedPreferences prefs) => _readUsage(prefs)
      .entries
      .map((e) => {
            'day': e.key,
            'foreground_seconds': e.value[0],
            'listen_seconds': e.value[1],
          })
      .toList();

  /// Pošle denné súčty aj keď dnešné otvorenie už bolo nahlásené
  /// (max raz za [_usageFlushEvery], ak nie [force]).
  Future<void> flushUsage({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kUsageLastFlush) ?? 0;
    if (!force &&
        DateTime.now().millisecondsSinceEpoch - last < _usageFlushEvery.inMilliseconds) {
      return;
    }
    if (_readUsage(prefs).isEmpty) return;
    await recordOpen(usageFlush: true);
  }

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  /// Počet rôznych lokálnych dní, v ktorých bola appka otvorená (od 11.2.4).
  Future<int> activeDaysCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kDaysCount) ?? 0;
  }

  /// Zavolať pri štarte a pri každom návrate do popredia. Idempotentné:
  /// druhé volanie v ten istý lokálny deň nič neposiela — okrem [usageFlush]
  /// (odoslanie času v appke, volá [flushUsage]).
  Future<void> recordOpen({bool usageFlush = false}) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(_kDaysCountLastDay) != today) {
        await prefs.setString(_kDaysCountLastDay, today);
        await prefs.setInt(_kDaysCount, (prefs.getInt(_kDaysCount) ?? 0) + 1);
      }
      final hasSessionNow =
          Supabase.instance.client.auth.currentSession?.accessToken != null;
      if (prefs.getString(_kLastDay) == today && !usageFlush) {
        // Dnes už nahlásené — znova len ak to bolo anonymne a teraz sme prihlásení.
        final authedToday = prefs.getBool(_kLastDayAuthed) ?? false;
        if (authedToday || !hasSessionNow) return;
      }

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

      final usage = _usagePayload(prefs);

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
              // 11.2.5: systémová veľkosť písma (1.0 = predvolené) — nepriamy
              // ukazovateľ veku pri porovnaní retencie iOS/Android (23. 10.)
              'text_scale': PlatformDispatcher.instance.textScaleFactor,
              if (usage.isNotEmpty) 'usage': usage,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(_kLastDay, today);
        await prefs.setBool(_kLastDayAuthed, token != null);
        if (usage.isNotEmpty) {
          await prefs.setInt(_kUsageLastFlush, DateTime.now().millisecondsSinceEpoch);
        }
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

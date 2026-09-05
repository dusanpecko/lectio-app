import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';
import 'local_notifications_service.dart';

/// Lokálny progres deviatnika (jedného používateľa na jednom zariadení).
///
/// Progres je KALENDÁRNY od štartu: deň 1 = deň začatia, deň 2 = nasledujúci
/// kalendárny deň… Aktuálny deň sa počíta z dátumu (nie z dokončených dní);
/// odmodlené dni si používateľ môže pozrieť spätne, dopredu sa nedá.
/// Ukladá sa v SharedPreferences (funguje offline aj bez prihlásenia);
/// môže bežať viac deviatnikov naraz (kľúč = baseCode deviatnika).
class NovenaProgress {
  final DateTime startedAt; // dátum (bez času) začatia — deň 1
  final Set<int> completedDays;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int totalDays;

  const NovenaProgress({
    required this.startedAt,
    required this.completedDays,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.totalDays,
  });

  /// Aktuálny deň podľa kalendára (1-based). Môže presiahnuť [totalDays]
  /// — vtedy je deviatnik dokončený.
  int get currentDay {
    final today = DateTime.now();
    final d0 = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final t0 = DateTime(today.year, today.month, today.day);
    return t0.difference(d0).inDays + 1;
  }

  /// Dokončený vzhľadom na ŽIVÝ počet dní z DB — [totalDays] uložený pri
  /// štarte sa nepoužíva na UI (admin mohol dni medzitým doplniť; uložený
  /// počet slúži len na plánovanie/zrušenie pripomienok).
  bool isFinishedFor(int liveTotalDays) => currentDay > liveTotalDays;

  /// Aktuálne dosiahnutý deň (kalendárne), ohraničený živým počtom dní.
  int unlockedDayFor(int liveTotalDays) =>
      currentDay.clamp(1, liveTotalDays < 1 ? 1 : liveTotalDays);

  Map<String, dynamic> toJson() => {
    'started_at': startedAt.toIso8601String().substring(0, 10),
    'completed_days': completedDays.toList()..sort(),
    'reminder_enabled': reminderEnabled,
    'reminder_hour': reminderHour,
    'reminder_minute': reminderMinute,
    'total_days': totalDays,
  };

  factory NovenaProgress.fromJson(Map<String, dynamic> json) {
    return NovenaProgress(
      startedAt: DateTime.parse(json['started_at'] as String),
      completedDays: ((json['completed_days'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet(),
      reminderEnabled: json['reminder_enabled'] == true,
      reminderHour: (json['reminder_hour'] as num?)?.toInt() ?? 20,
      reminderMinute: (json['reminder_minute'] as num?)?.toInt() ?? 0,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 9,
    );
  }

  NovenaProgress copyWith({
    Set<int>? completedDays,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) => NovenaProgress(
    startedAt: startedAt,
    completedDays: completedDays ?? this.completedDays,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    totalDays: totalDays,
  );
}

class NovenaProgressService {
  NovenaProgressService._();
  static final NovenaProgressService instance = NovenaProgressService._();

  static const String _prefix = 'novena_progress_v1_';

  /// Základ notifikačných ID deviatnikov — mimo rozsahov welcome (1000)
  /// a prayer reminder (3000+). Každý deviatnik dostane blok 50 ID podľa
  /// hash-u baseCode; kolízia dvoch deviatnikov je nepravdepodobná a
  /// neškodná (prepíše sa pripomienka).
  static const int _notifBase = 60000;
  static int _idBase(String baseCode) =>
      _notifBase + (baseCode.hashCode.abs() % 400) * 50;

  Future<NovenaProgress?> getProgress(String baseCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$baseCode');
    if (raw == null) return null;
    try {
      return NovenaProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      appLogger.w('⚠️ Novena progress parse failed ($baseCode): $e');
      return null;
    }
  }

  Future<void> _save(String baseCode, NovenaProgress p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$baseCode', jsonEncode(p.toJson()));
  }

  /// Začne deviatnik dnešným dňom (deň 1) + naplánuje pripomienky.
  Future<NovenaProgress> start(
    String baseCode, {
    required String novenaTitle,
    required int totalDays,
    required bool reminderEnabled,
    int reminderHour = 20,
    int reminderMinute = 0,
  }) async {
    final now = DateTime.now();
    final p = NovenaProgress(
      startedAt: DateTime(now.year, now.month, now.day),
      completedDays: {},
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      totalDays: totalDays,
    );
    await _save(baseCode, p);
    if (reminderEnabled) {
      await _scheduleReminders(baseCode, novenaTitle, p);
    }
    return p;
  }

  /// Označí deň ako odmodlený.
  Future<NovenaProgress> markCompleted(String baseCode, int day) async {
    final p = await getProgress(baseCode);
    if (p == null) throw StateError('Novena not started');
    final updated = p.copyWith(completedDays: {...p.completedDays, day});
    await _save(baseCode, updated);
    return updated;
  }

  /// Zmení nastavenie pripomienky (a preplánuje/zruší notifikácie).
  Future<NovenaProgress> setReminder(
    String baseCode, {
    required String novenaTitle,
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final p = await getProgress(baseCode);
    if (p == null) throw StateError('Novena not started');
    final updated = p.copyWith(
      reminderEnabled: enabled,
      reminderHour: hour,
      reminderMinute: minute,
    );
    await _save(baseCode, updated);
    await cancelReminders(baseCode, p.totalDays);
    if (enabled) {
      await _scheduleReminders(baseCode, novenaTitle, updated);
    }
    return updated;
  }

  /// Zruší progres (a pripomienky) — používa sa pri „Modliť sa znova".
  Future<void> reset(String baseCode, int totalDays) async {
    await cancelReminders(baseCode, totalDays);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$baseCode');
  }

  // ── Lokálne pripomienky ─────────────────────────────────────────────────────

  Future<void> _scheduleReminders(
    String baseCode,
    String novenaTitle,
    NovenaProgress p,
  ) async {
    final plugin = LocalNotificationsService.instance.plugin;
    final location = tz.getLocation(
      LocalNotificationsService.instance.currentTimezoneName,
    );
    final idBase = _idBase(baseCode);
    var scheduled = 0;

    for (int day = 1; day <= p.totalDays; day++) {
      final when = tz.TZDateTime(
        location,
        p.startedAt.year,
        p.startedAt.month,
        p.startedAt.day + (day - 1),
        p.reminderHour,
        p.reminderMinute,
      );
      if (when.isBefore(tz.TZDateTime.now(location))) continue;

      try {
        await plugin.zonedSchedule(
          id: idBase + day,
          title: 'novena.reminder_notif_title'.tr(),
          body: 'novena.reminder_notif_body'.tr(
            namedArgs: {
              'title': novenaTitle,
              'day': '$day',
              'total': '${p.totalDays}',
            },
          ),
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'novena_reminder_channel',
              'Pripomienka deviatnika',
              channelDescription: 'Denné pripomienky rozmodleného deviatnika',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'type': 'novena', 'baseCode': baseCode}),
        );
        scheduled++;
      } catch (e) {
        appLogger.w('⚠️ Novena reminder schedule failed (deň $day): $e');
      }
    }
    appLogger.i('🔔 Novena "$baseCode": naplánovaných $scheduled pripomienok');
  }

  Future<void> cancelReminders(String baseCode, int totalDays) async {
    final plugin = LocalNotificationsService.instance.plugin;
    final idBase = _idBase(baseCode);
    for (int day = 1; day <= totalDays; day++) {
      try {
        await plugin.cancel(id: idBase + day);
      } catch (_) {}
    }
  }
}

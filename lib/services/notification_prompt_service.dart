import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/notification_prompt_sheet.dart';
import 'fcm_service.dart';
import 'umami_analytics_service.dart';

/// Povolenie notifikácií v správnej chvíli (11.2.4).
///
/// Prečo: za 8 mesiacov povolilo push len ~3 % zariadení — systémový dialóg sa
/// pýtal hneď pri prvom štarte, bez kontextu. Denný push je pritom jediný
/// mechanizmus, ktorý človeka vráti do appky (september 2026: +67 % MAU).
///
/// Kedy: po PRVOM dočítanom alebo dopočúvanom lectiu (posledný krok Actio,
/// alebo dohranie kombinovaného audia). Vlastný sheet vysvetlí, čo príde
/// (ranná prvá veta evanjelia + jedno ťuknutie k audiu), nechá vybrať čas
/// a až po „Zapnúť“ ukáže systémový dialóg.
///
/// Pravidlá: nikdy, ak je povolenie už udelené; po odmietnutí znova najskôr
/// o 14 dní; najviac 3×; max 1× za deň. Meranie: Umami
/// `notification_prompt` {action: shown|accepted|declined|system_denied|blocked}.
class NotificationPromptService {
  NotificationPromptService._();
  static final NotificationPromptService instance = NotificationPromptService._();

  static const _kCount = 'notif_prompt_count';
  static const _kLastShown = 'notif_prompt_last_shown'; // yyyy-MM-dd
  static const _kDone = 'notif_prompt_done'; // povolené / už netreba
  static const int _maxAttempts = 3;
  static const int _cooldownDays = 14;

  bool _showing = false;
  bool _firedThisSession = false;

  /// Zavolať po dokončení lectia (Actio / dohrané audio). Bezpečné volať
  /// opakovane — samo si rozhodne, či má zmysel niečo ukázať.
  Future<void> onLectioFinished(BuildContext context) async {
    if (_showing || _firedThisSession) return;
    _firedThisSession = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kDone) == true) return;

      // Už povolené (napr. cez nastavenia) → hotovo, viac sa nepýtať.
      if (await FcmService.instance.hasNotificationPermissions()) {
        await prefs.setBool(_kDone, true);
        return;
      }

      final count = prefs.getInt(_kCount) ?? 0;
      if (count >= _maxAttempts) return;
      final last = prefs.getString(_kLastShown);
      if (last != null) {
        final lastDate = DateTime.tryParse(last);
        if (lastDate != null &&
            DateTime.now().difference(lastDate).inDays < _cooldownDays) {
          return;
        }
      }
      if (!context.mounted) return;

      await prefs.setInt(_kCount, count + 1);
      await prefs.setString(
        _kLastShown,
        DateTime.now().toIso8601String().substring(0, 10),
      );
      _track('shown', extra: {'attempt': count + 1});

      if (!context.mounted) return;
      _showing = true;
      final result = await showNotificationPromptSheet(context);
      _showing = false;

      if (result == null) {
        _track('declined');
        return;
      }

      // Systémový dialóg až teraz — používateľ vie, načo je.
      final granted = await FcmService.instance.requestNotificationPermissions();
      if (!granted) {
        final blocked = await FcmService.instance.isNotificationPermissionBlocked();
        _track(blocked ? 'blocked' : 'system_denied');
        if (blocked && context.mounted) {
          await _offerSystemSettings(context);
        }
        return;
      }

      _track('accepted', extra: {'hour': result.hour, 'minute': result.minute});
      await prefs.setBool(_kDone, true);
      // Token sa dá zaregistrovať až teraz (iOS APNs) + čas a zapnutý denný push.
      await FcmService.instance.refreshRegistration();
      await FcmService.instance.updatePreferredLectioTime(result);
      await FcmService.instance.setDeviceNotificationFlags(dailyLectioEnabled: true);

      if (context.mounted) {
        final hh = result.hour.toString().padLeft(2, '0');
        final mm = result.minute.toString().padLeft(2, '0');
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'notifications.permission.prompt_enabled'.tr(args: ['$hh:$mm']),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationPrompt: $e');
      _showing = false;
    }
  }

  Future<void> _offerSystemSettings(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('notifications.permission.blocked_title'.tr()),
        content: Text('notifications.permission.blocked_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('notifications.permission.open_settings'.tr()),
          ),
        ],
      ),
    );
    if (go == true) await FcmService.instance.openSystemNotificationSettings();
  }

  void _track(String action, {Map<String, dynamic>? extra}) {
    UmamiAnalyticsService().trackEvent(
      'notification_prompt',
      eventData: {
        'action': action,
        'platform': Platform.isIOS ? 'ios' : 'android',
        ...?extra,
      },
    );
  }
}

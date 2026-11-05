import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart' hide AppUpdateInfo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/notification_controller.dart';
import '../utils/app_logger.dart';
import '../widgets/app_update_dialog.dart';
import 'app_version_service.dart';
import 'umami_analytics_service.dart';

/// Výzva na aktualizáciu (11.2.5). Do 11.2.4 sa mäkká výzva ukazovala pri
/// KAŽDOM štarte bez odstupu a ľudia dávali „Neskôr“ (deň a pol po vydaní
/// 11.2.4 sa aktualizovalo ~35 %). Teraz:
///  - povinná (pod `min_version`) ostáva hneď pri štarte,
///  - odporúčaná až po dokončení lectia (`LectioCompletionService`), nie keď
///    človek appku otvára kvôli modlitbe, a po zobrazení najskôr o 3 dni,
///  - Android: Google Play aktualizácia priamo v appke (flexible) — stiahne
///    sa na pozadí, potom len „Reštartovať“; iOS / appka nie z Play →
///    dialóg s vetou „čo je nové“ a obchod,
///  - Umami `app_update_prompt {action, kind, version}`.
class AppUpdatePromptService {
  AppUpdatePromptService._();
  static final AppUpdatePromptService instance = AppUpdatePromptService._();

  static const _kLastShown = 'app_update_prompt_last_shown_ms';
  static const _cooldown = Duration(days: 3);

  StreamSubscription<InstallStatus>? _installSub;
  bool _restartOffered = false;

  /// Štart appky: povinná aktualizácia (blokujúci dialóg); na Androide
  /// ponuka reštartu, ak už je aktualizácia stiahnutá z minula.
  Future<void> onAppStart(BuildContext context) async {
    final info = await AppVersionService.instance.check();
    if (info != null && info.type == AppUpdateType.force) {
      if (!context.mounted) return;
      _track('shown', 'force', info);
      await showAppUpdateDialog(
        context,
        info,
        force: true,
        onUpdate: () async {
          _track('update', 'force', info);
          await _openStore(info);
        },
      );
      return;
    }
    if (Platform.isAndroid) {
      try {
        final play = await InAppUpdate.checkForUpdate();
        if (play.installStatus == InstallStatus.downloaded) {
          _offerRestart(info);
        }
      } catch (_) {
        // Appka nie je z Google Play (debug, sideload) — nič.
      }
    }
  }

  /// Po dokončení lectia. Vracia true, ak sa niečo ukázalo (max jedna výzva
  /// na jedno dokončenie, viď `LectioCompletionService`).
  Future<bool> onLectioFinished(BuildContext context) async {
    final info = await AppVersionService.instance.check();
    if (info == null || info.type != AppUpdateType.soft) return false;

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastShown) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _cooldown.inMilliseconds) return false;

    if (Platform.isAndroid && await _tryPlayFlexible(info, prefs, now)) {
      return true;
    }
    await prefs.setInt(_kLastShown, now);
    if (!context.mounted) return false;
    _track('shown', 'store', info);
    final updated = await showAppUpdateDialog(
      context,
      info,
      force: false,
      onUpdate: () => _openStore(info),
    );
    _track(updated ? 'update' : 'later', 'store', info);
    return true;
  }

  /// Google Play flexible: Play ukáže vlastný dialóg, po súhlase sa sťahuje
  /// na pozadí a appka beží ďalej. False = Play aktualizáciu neponúka
  /// (appka nie z Play, Play ju ešte nevidí) → ide dialóg s obchodom.
  Future<bool> _tryPlayFlexible(
    AppUpdateInfo info,
    SharedPreferences prefs,
    int now,
  ) async {
    try {
      final play = await InAppUpdate.checkForUpdate();
      if (play.installStatus == InstallStatus.downloaded) {
        _offerRestart(info);
        return true;
      }
      if (play.updateAvailability != UpdateAvailability.updateAvailable ||
          !play.flexibleUpdateAllowed) {
        return false;
      }
      await prefs.setInt(_kLastShown, now);
      _track('shown', 'play', info);
      _listenInstall(info);
      final result = await InAppUpdate.startFlexibleUpdate();
      _track(
        switch (result) {
          AppUpdateResult.success => 'update',
          AppUpdateResult.userDeniedUpdate => 'later',
          AppUpdateResult.inAppUpdateFailed => 'failed',
        },
        'play',
        info,
      );
      return true;
    } catch (e) {
      appLogger.w('⚠️ Play in-app update nedostupný: $e');
      return false;
    }
  }

  void _listenInstall(AppUpdateInfo info) {
    _installSub ??= InAppUpdate.installUpdateListener.listen((status) {
      if (status == InstallStatus.downloaded) {
        _track('downloaded', 'play', info);
        _offerRestart(info);
      }
    }, onError: (_) {});
  }

  /// Stiahnuté → nenútiť reštart (človek sa môže práve modliť / počúvať),
  /// len ponuka v spodnej lište. Raz za spustenie appky.
  void _offerRestart(AppUpdateInfo? info) {
    if (_restartOffered) return;
    final ctx = NotificationController.instance.navigatorKey.currentContext;
    final messenger = ctx == null ? null : ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    _restartOffered = true;
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('app_update.ready')),
        duration: const Duration(minutes: 5),
        action: SnackBarAction(
          label: tr('app_update.restart'),
          onPressed: () {
            _track('restart', 'play', info);
            InAppUpdate.completeFlexibleUpdate().catchError((_) {});
          },
        ),
      ),
    );
  }

  Future<void> _openStore(AppUpdateInfo info) async {
    await launchUrl(
      Uri.parse(info.storeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  void _track(String action, String kind, AppUpdateInfo? info) {
    UmamiAnalyticsService().trackEvent(
      'app_update_prompt',
      eventData: {
        'action': action,
        'kind': kind,
        'version': ?info?.latestVersion,
      },
    );
  }
}

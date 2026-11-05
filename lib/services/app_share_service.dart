import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/share_app_sheet.dart';
import 'umami_analytics_service.dart';

/// Zdieľanie aplikácie (11.2.4) — v appke dovtedy nebolo, hoci odporúčanie
/// od známeho je najlacnejší zdroj nových používateľov (Dušan 23. 9.).
///
/// Zdieľa sa JEDEN odkaz (`lectio.one/app`), ktorý sám presmeruje podľa
/// zariadenia príjemcu: iPhone → App Store, Android → Google Play, počítač →
/// stránka s dvoma tlačidlami. Na rozdiel od OneLinku (do 11.2.4) vidíme
/// vo webovom Umami (`app_link`) krajinu a znenie pozvánky a obchody dostanú
/// značku ďalej → vieme, ktoré znenie prináša inštalácie, nielen zdieľania.
class AppShareService {
  AppShareService._();
  static final AppShareService instance = AppShareService._();

  static const _appStoreId = '6443882687';
  static const androidUrl =
      'https://play.google.com/store/apps/details?id=sk.dpapp.app.android604688a88a394';
  static String get iosUrl => 'https://apps.apple.com/app/id$_appStoreId';
  static String get appStoreId => _appStoreId;

  /// Rozcestník pre všetky platformy (`backend/src/app/[locale]/app/`).
  static const shareUrl = 'https://www.lectio.one/app';

  /// Odkaz so značkou kanála a variantom pozvánky (v1–v3).
  static String shareUrlFor(int variant) =>
      '$shareUrl?z=app-share&utm_campaign=v$variant';


  /// Najprv nechá vybrať znenie pozvánky (3 varianty — Dušan 23. 9.), potom
  /// otvorí systémové zdieľanie. iOS popover sa umiestni podľa widgetu.
  Future<void> shareApp(BuildContext context, {String source = 'more_menu'}) async {
    final variant = await showShareAppSheet(
      context,
      linkPreview: shareUrl.replaceFirst('https://', ''),
    );
    if (variant == null || !context.mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    final text =
        '${'share_app.v${variant}_text'.tr()}\n\n${shareUrlFor(variant)}';
    UmamiAnalyticsService().trackEvent(
      'share_app',
      eventData: {
        'source': source,
        'variant': variant,
        'language': context.locale.languageCode,
      },
    );
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'share_app.subject'.tr(),
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  }
}

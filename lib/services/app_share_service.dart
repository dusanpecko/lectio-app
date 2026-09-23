import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'umami_analytics_service.dart';

/// Zdieľanie aplikácie (11.2.4) — v appke dovtedy nebolo, hoci odporúčanie
/// od známeho je najlacnejší zdroj nových používateľov (Dušan 23. 9.).
///
/// Zdieľa sa JEDEN odkaz na web v jazyku používateľa, nie odkaz do konkrétneho
/// obchodu: príjemca môže mať iPhone aj Android a na webe nájde oboje.
class AppShareService {
  AppShareService._();
  static final AppShareService instance = AppShareService._();

  static const _appStoreId = '6443882687';
  static const androidUrl =
      'https://play.google.com/store/apps/details?id=sk.dpapp.app.android604688a88a394';
  static String get iosUrl => 'https://apps.apple.com/app/id$_appStoreId';
  static String get appStoreId => _appStoreId;

  String webUrl(BuildContext context) =>
      'https://www.lectio.one/${context.locale.languageCode}';

  /// Otvorí systémové zdieľanie s krátkym textom a odkazom.
  /// [origin] je widget, z ktorého sa zdieľa — iOS podľa neho umiestni popover.
  Future<void> shareApp(BuildContext context, {String source = 'more_menu'}) async {
    final box = context.findRenderObject() as RenderBox?;
    final text = '${'share_app.message'.tr()}\n\n${webUrl(context)}';
    UmamiAnalyticsService().trackEvent(
      'share_app',
      eventData: {'source': source, 'language': context.locale.languageCode},
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

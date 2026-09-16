import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../controllers/notification_controller.dart';
import '../services/inbox_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_colors.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

// Ciele tlačidiel (screen_key) rieši NotificationController.navigateToKey —
// jeden register obrazoviek pre inbox aj push deep linky (predtým mal inbox
// vlastnú mapu a kľúče sa s pushom rozchádzali).

/// Zavolaj po načítaní home. Stiahne aktívnu inbox správu a ak nejaká je,
/// zobrazí popup. Ticho nič nespraví, ak nič nevyhovuje / offline.
Future<void> maybeShowInboxPopup(BuildContext context) async {
  final lang = context.locale.languageCode;
  final message = await InboxService.instance.fetchActive(lang);
  if (message == null) return;
  if (!context.mounted) return;

  // Zobrazené — zapíš + Umami
  InboxService.instance.reportSeen(message.id, 'seen');
  UmamiAnalyticsService().trackEvent('inbox_shown', eventData: {'id': message.id});

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _InboxDialog(message: message),
  );
}

class _InboxDialog extends StatelessWidget {
  final InboxMessage message;
  const _InboxDialog({required this.message});

  void _dismiss(BuildContext context) {
    InboxService.instance.reportSeen(message.id, 'dismissed');
    UmamiAnalyticsService().trackEvent('inbox_dismissed', eventData: {'id': message.id});
    Navigator.of(context).pop();
  }

  void _onButton(BuildContext context, InboxButton btn, int index) {
    InboxService.instance.reportSeen(message.id, 'clicked', buttonIndex: index);
    UmamiAnalyticsService().trackEvent('inbox_clicked', eventData: {
      'id': message.id,
      'button': index,
      'screen': btn.screenKey,
    });
    // Najprv zavri dialóg, potom naviguj cez root navigator controllera —
    // spoločná cesta s push deep linkmi (produkt podľa slug-u s fallbackom
    // na e-shop, článok podľa ID s fallbackom na zoznam atď.).
    Navigator.of(context).pop();
    NotificationController.instance.navigateToKey(
      btn.screenKey,
      param: btn.screenParam,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = HomeV2.isDark(context);
    final buttons = message.buttons;

    final surface = isDark ? AppColors.darkCard : AppColors.card;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _dismiss(context),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zatváracie X keď nie je obrázok
                if (message.imageUrl == null || message.imageUrl!.isEmpty)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => _dismiss(context),
                      icon: const Icon(Icons.close, size: 20),
                      color: isDark ? Colors.white54 : Colors.black45,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                if (message.title != null && message.title!.isNotEmpty)
                  Text(
                    message.title!,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: HomeV2.iconAccent(context),
                    ),
                  ),
                if (message.body != null && message.body!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message.body!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Tlačidlá
                ...buttons.asMap().entries.map((e) {
                  final i = e.key;
                  final b = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _onButton(context, b, i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HomeV2.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Text(
                          b.label,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ),
                  );
                }),
                // Ak nie sú tlačidlá, ponúkni „Zavrieť"
                if (buttons.isEmpty)
                  TextButton(
                    onPressed: () => _dismiss(context),
                    child: Text('common.close'.tr()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

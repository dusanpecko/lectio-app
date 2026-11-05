import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/app_version_service.dart';
import 'home_v2/home_v2_tokens.dart';

/// Dialóg aktualizácie. Logiku (kedy, odstup, Google Play v appke, meranie)
/// má `AppUpdatePromptService` — tu je len vzhľad.
///
/// [force] = blokujúci (nedá sa zavrieť, „Aktualizovať“ nechá dialóg otvorený
/// a len otvorí obchod). Inak zavrieteľný. Vracia true, ak dal „Aktualizovať“.
Future<bool> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info, {
  required bool force,
  required Future<void> Function() onUpdate,
}) async {
  // Konkrétna veta „čo je nové“ z adminu, inak všeobecný text.
  final body = force
      ? tr('app_update.force_body')
      : info.whatsNewFor(context.locale.languageCode) ??
            tr('app_update.soft_body');
  var updated = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) => PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Text(
          tr(force ? 'app_update.force_title' : 'app_update.soft_title'),
        ),
        content: Text(body),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('app_update.later')),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HomeV2.primary),
            onPressed: () async {
              updated = true;
              await onUpdate();
              // Soft: po otvorení obchodu dialóg zavrieme; force necháme otvorený.
              if (!force && ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(tr('app_update.update_button')),
          ),
        ],
      ),
    ),
  );
  return updated;
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import 'home_v2/home_v2_tokens.dart';

/// Skontroluje verziu appky a podľa potreby zobrazí force/soft update dialóg.
/// Force = blokujúci (nedá sa zavrieť, len „Aktualizovať" → store).
/// Soft = zavrieteľný („Neskôr" / „Aktualizovať").
Future<void> maybeShowAppUpdateDialog(BuildContext context) async {
  final info = await AppVersionService.instance.check();
  if (info == null || info.type == AppUpdateType.none) return;
  if (!context.mounted) return;

  final force = info.type == AppUpdateType.force;

  Future<void> openStore() async {
    final uri = Uri.parse(info.storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) => PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Text(
          tr(force ? 'app_update.force_title' : 'app_update.soft_title'),
        ),
        content: Text(
          tr(force ? 'app_update.force_body' : 'app_update.soft_body'),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('app_update.later')),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HomeV2.primary),
            onPressed: () async {
              await openStore();
              // Soft: po otvorení store dialóg zavrieme; force necháme otvorený.
              if (!force && ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(tr('app_update.update_button')),
          ),
        ],
      ),
    ),
  );
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Informačný sheet „Ochrana tvojej prípravy" — vysvetľuje spovedné tajomstvo
/// v appke (dáta len v zariadení, šifrovanie, bez záloh/mikrofónu/analytiky).
/// Otvára sa z PIN brány aj zo spovednej obrazovky (ikona štítu).
Future<void> showConfessionPrivacySheet(BuildContext context) {
  final items = <(IconData, String, String)>[
    (
      Icons.smartphone_rounded,
      'confession.info_device_title'.tr(),
      'confession.info_device_body'.tr(),
    ),
    (
      Icons.key_rounded,
      'confession.info_crypto_title'.tr(),
      'confession.info_crypto_body'.tr(),
    ),
    (
      Icons.cloud_off_rounded,
      'confession.info_backup_title'.tr(),
      'confession.info_backup_body'.tr(),
    ),
    (
      Icons.mic_off_rounded,
      'confession.info_mic_title'.tr(),
      'confession.info_mic_body'.tr(),
    ),
    (
      Icons.visibility_off_rounded,
      'confession.info_tracking_title'.tr(),
      'confession.info_tracking_body'.tr(),
    ),
    (
      Icons.delete_forever_rounded,
      'confession.info_delete_title'.tr(),
      'confession.info_delete_body'.tr(),
    ),
  ];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeV2.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          MediaQuery.of(ctx).viewPadding.bottom + AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: HomeV2.gold, size: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'confession.info_title'.tr(),
                  style: HomeV2.serifTitle(ctx, size: 22, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'confession.info_intro'.tr(),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: HomeV2.textMuted(ctx),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (icon, title, body) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: HomeV2.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HomeV2.textDark(ctx),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: HomeV2.textMuted(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: HomeV2.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: HomeV2.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              'confession.disclaimer'.tr(),
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: HomeV2.textDark(ctx),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'confession.info_footer'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: HomeV2.textMuted(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}

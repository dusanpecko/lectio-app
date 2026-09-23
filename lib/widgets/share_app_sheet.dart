import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Výber znenia pozvánky pred zdieľaním aplikácie (11.2.4).
/// Vráti číslo varianty (1–3), alebo null pri zatvorení.
Future<int?> showShareAppSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      Widget option(int i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(sheetCtx).pop(i);
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'share_app.v${i}_label'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: HomeV2.iconAccent(sheetCtx),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'share_app.v${i}_text'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: HomeV2.textDark(sheetCtx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.ios_share_rounded, size: 18, color: HomeV2.textMuted(sheetCtx)),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: HomeV2.card(sheetCtx),
            borderRadius: BorderRadius.circular(HomeV2.radius),
            boxShadow: HomeV2.softShadow(sheetCtx),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HomeV2.textMuted(sheetCtx).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HomeV2.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                      ),
                      child: Icon(Icons.ios_share_rounded, color: HomeV2.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'share_app.title'.tr(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: HomeV2.textDark(sheetCtx),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'share_app.choose'.tr(),
                            style: TextStyle(fontSize: 13, color: HomeV2.textMuted(sheetCtx)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                option(1),
                option(2),
                option(3),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  style: TextButton.styleFrom(foregroundColor: HomeV2.textMuted(sheetCtx)),
                  child: Text('cancel'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Výber znenia pozvánky pred zdieľaním aplikácie (11.2.4).
/// Vráti číslo varianty (1–3), alebo null pri zatvorení.
Future<int?> showShareAppSheet(BuildContext context, {required String linkPreview}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _ShareAppSheet(linkPreview: linkPreview),
  );
}

const _icons = <int, IconData>{
  1: Icons.volume_off_rounded,
  2: Icons.mail_outline_rounded,
  3: Icons.favorite_rounded,
};

class _ShareAppSheet extends StatelessWidget {
  const _ShareAppSheet({required this.linkPreview});
  final String linkPreview;

  @override
  Widget build(BuildContext context) {
    final accent = HomeV2.iconAccent(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radius),
          boxShadow: HomeV2.softShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hlavička s jemným prechodom ako hero v Nastaveniach
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HomeV2.primary.withValues(
                        alpha: HomeV2.isDark(context) ? 0.32 : 0.14,
                      ),
                      HomeV2.card(context),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: HomeV2.textMuted(context).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'share_app.title'.tr(),
                      style: HomeV2.serifTitle(context, size: 24, height: 1.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'share_app.choose'.tr(),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 1; i <= 3; i++) ...[
                      _VariantCard(index: i),
                      if (i < 3) const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    // Odkaz, ktorý sa pripojí ku každému zneniu
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            linkPreview,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: HomeV2.textMuted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeV2.textMuted(context),
                      ),
                      child: Text('cancel'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = HomeV2.iconAccent(context);
    return Material(
      color: HomeV2.background(context),
      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop(index);
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(_icons[index], size: 16, color: accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'share_app.v${index}_label'.tr(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: accent,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.ios_share_rounded,
                    size: 17,
                    color: HomeV2.textMuted(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'share_app.v${index}_text'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: HomeV2.textDark(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

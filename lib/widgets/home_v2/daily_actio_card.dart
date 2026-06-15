import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Karta s denným „actio" textom — duchovný impulz na dnešok.
/// Nahrádza pôvodný 2×2 quick-action grid (navigáciu rieši bottom nav + „Viac").
class DailyActioCard extends StatelessWidget {
  final String? actioText;
  final bool isLoading;
  final VoidCallback onTap;

  const DailyActioCard({
    super.key,
    required this.actioText,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        size: 22, color: HomeV2.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      tr('actio').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: HomeV2.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (isLoading)
                  const _ActioSkeleton()
                else
                  Text(
                    (actioText != null && actioText!.trim().isNotEmpty)
                        ? actioText!
                        : tr('quote_not_available'),
                    style: HomeV2.serifQuote(
                      context,
                      size: 19,
                      color: HomeV2.textDark(context),
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActioSkeleton extends StatelessWidget {
  const _ActioSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = HomeV2.primary.withValues(alpha: 0.08);
    Widget bar(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 14,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(1.0), bar(0.92), bar(0.6)],
    );
  }
}

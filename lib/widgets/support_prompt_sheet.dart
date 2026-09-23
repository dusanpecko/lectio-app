import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/support_campaign.dart';
import '../services/support_campaign_service.dart';
import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Kontextová výzva na podporu (11.2.4) — zobrazuje sa tesne po dopočúvaní
/// alebo dočítaní lectia, po 7 rôznych dňoch používania. Text: Dušan 23. 9.
/// Živý riadok (počet podporovateľov, vyzbieraná suma → dni chodu) sa berie
/// z verejného API kampane; bez siete sa jednoducho nezobrazí.
/// Vráti true, keď používateľ ťukne „Chcem podporiť“, inak null/false.
Future<bool?> showSupportPromptSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SupportPromptSheet(),
  );
}

/// Ročný rozpočet „Udržateľný chod projektu“ (kampaň, /admin/support-campaign).
/// Použije sa prvý míľnik kampane; keď chýba, táto záloha.
const double _fallbackYearlyCost = 19800;

class _SupportPromptSheet extends StatefulWidget {
  const _SupportPromptSheet();

  @override
  State<_SupportPromptSheet> createState() => _SupportPromptSheetState();
}

class _SupportPromptSheetState extends State<_SupportPromptSheet> {
  SupportCampaign? _campaign = SupportCampaignService.instance.cached;

  @override
  void initState() {
    super.initState();
    if (_campaign == null) {
      SupportCampaignService.instance.fetch().then((c) {
        if (mounted && c != null) setState(() => _campaign = c);
      });
    }
  }

  /// „Aktuálne nás podporuje 35 ľudí. Spolu 11 297 €, približne 208 dní chodu.“
  String? _liveLine() {
    final c = _campaign;
    if (c == null || !c.active || !c.showSupporters || c.supporters <= 0) {
      return null;
    }
    if (!c.showAmount || c.currentAmount <= 0) {
      return 'engagement.support.contextual_live_supporters'
          .tr(args: ['${c.supporters}']);
    }
    final yearly = c.milestones.isNotEmpty && c.milestones.first.amount > 0
        ? c.milestones.first.amount
        : _fallbackYearlyCost;
    final days = (c.currentAmount / (yearly / 365)).floor();
    return 'engagement.support.contextual_live'.tr(
      args: ['${c.supporters}', _formatEur(c.currentAmount), '$days'],
    );
  }

  static String _formatEur(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u00A0');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final live = _liveLine();
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
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radius),
          boxShadow: HomeV2.softShadowSm(context),
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
                    color: theme.dividerColor,
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
                      color: HomeV2.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: HomeV2.gold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'engagement.support.contextual_title'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('engagement.support.contextual_intro'.tr(), style: body),
              const SizedBox(height: AppSpacing.sm),
              Text('engagement.support.contextual_costs'.tr(), style: body),
              const SizedBox(height: AppSpacing.sm),
              Text('engagement.support.contextual_math'.tr(), style: body),
              if (live != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  live,
                  style: body?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'engagement.support.contextual_bonus_title'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'engagement.support.contextual_bonus'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('engagement.support.contextual_outro'.tr(), style: body),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('engagement.support.contextual_now'.tr()),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('engagement.support.contextual_later'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

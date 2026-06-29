import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/app_spacing.dart';
import '../../widgets/donation/campaign_rewards_section.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import '../donation_screen.dart';
import 'project_widgets.dart';

/// Prezentačná obrazovka projektu „Videokurz Lectio Divina" (Slovo bez hraníc).
/// Zrkadlí webovú stránku — pre náhľad v appke a fotodokumentáciu.
class KurzLectioScreen extends StatelessWidget {
  const KurzLectioScreen({super.key});

  // Ikony krokov — texty (latinský · lokalizovaný názov + popis) z prekladov.
  static const _stepIcons = <IconData>[
    Icons.volume_off_rounded,
    Icons.menu_book_rounded,
    Icons.lightbulb_rounded,
    Icons.favorite_rounded,
    Icons.local_fire_department_rounded,
    Icons.eco_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProjectHero(
            badge: 'projects.kurz.hero_badge'.tr(),
            badgeIcon: Icons.school_rounded,
            title: 'projects.kurz.hero_title'.tr(),
            subtitle: 'projects.kurz.hero_subtitle'.tr(),
            chips: [
              'projects.kurz.chip1'.tr(),
              'projects.kurz.chip2'.tr(),
              'projects.kurz.chip3'.tr(),
            ],
            imageAsset: 'assets/images/course.webp',
          ),

          const SizedBox(height: AppSpacing.xl),
          const LiveProjectFundingBar(
            slug: 'kurz_lectio',
            fallbackRaised: 3000,
            goal: 25000,
          ),

          const SizedBox(height: AppSpacing.xxl),
          ProjectSection(
            label: 'projects.kurz.about_label'.tr(),
            title: 'projects.kurz.about_title'.tr(),
            text: 'projects.kurz.about_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.lg),
          ProjectSection(
            label: 'projects.kurz.why_label'.tr(),
            title: 'projects.kurz.why_title'.tr(),
            text: 'projects.kurz.why_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.lg),
          ProjectSection(
            label: 'projects.kurz.path_label'.tr(),
            title: 'projects.kurz.path_title'.tr(),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < _stepIcons.length; i++)
            ProjectFeatureCard(
              icon: _stepIcons[i],
              title: 'projects.kurz.step${i + 1}_title'.tr(),
              text: 'projects.kurz.step${i + 1}_text'.tr(),
            ),

          const SizedBox(height: AppSpacing.lg),
          ProjectSection(
            label: 'projects.kurz.format_label'.tr(),
            title: 'projects.kurz.format_title'.tr(),
          ),
          const SizedBox(height: AppSpacing.md),
          ProjectAudienceCard(
            icon: Icons.play_circle_fill_rounded,
            title: 'projects.kurz.fmt1_title'.tr(),
            highlight: true,
            text: 'projects.kurz.fmt1_text'.tr(),
          ),
          ProjectAudienceCard(
            icon: Icons.translate_rounded,
            title: 'projects.kurz.fmt2_title'.tr(),
            text: 'projects.kurz.fmt2_text'.tr(),
          ),
          ProjectAudienceCard(
            icon: Icons.groups_rounded,
            title: 'projects.kurz.fmt3_title'.tr(),
            text: 'projects.kurz.fmt3_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.xl),
          ProjectSection(
            label: 'projects.kurz.help_label'.tr(),
            title: 'projects.kurz.help_title'.tr(),
            text: 'projects.kurz.help_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DonationScreen(
                      campaign: 'kurz_lectio',
                      campaignTitle: 'projects.kurz.hero_title'.tr(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.favorite_rounded, size: 20),
                label: Text('projects.support_button'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'projects.support_note'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const CampaignRewardsSection(campaign: 'kurz_lectio'),

          const SizedBox(height: AppSpacing.xl),
          const ProjectFooterNote(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

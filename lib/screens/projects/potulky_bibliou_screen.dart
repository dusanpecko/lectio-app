import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/app_spacing.dart';
import '../../widgets/donation/campaign_rewards_section.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import '../donation_screen.dart';
import 'project_widgets.dart';

/// Prezentačná obrazovka projektu „Potulky Bibliou" (Slovo bez hraníc).
/// Zrkadlí webovú stránku — pre náhľad v appke a fotodokumentáciu.
class PotulkyBibliouScreen extends StatelessWidget {
  const PotulkyBibliouScreen({super.key});

  // Ikony funkcií — texty sa berú z prekladov (projects.potulky.featureN_*).
  static const _featureIcons = <IconData>[
    Icons.movie_rounded,
    Icons.menu_book_rounded,
    Icons.videogame_asset_rounded,
    Icons.family_restroom_rounded,
    Icons.card_giftcard_rounded,
    Icons.church_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProjectHero(
            badge: 'projects.potulky.hero_badge'.tr(),
            badgeIcon: Icons.auto_awesome_rounded,
            title: 'projects.potulky.hero_title'.tr(),
            subtitle: 'projects.potulky.hero_subtitle'.tr(),
            chips: [
              'projects.potulky.chip1'.tr(),
              'projects.potulky.chip2'.tr(),
              'projects.potulky.chip3'.tr(),
            ],
            imageAsset: 'assets/images/potulky_hero.webp',
          ),

          const SizedBox(height: AppSpacing.xl),
          const LiveProjectFundingBar(
            slug: 'potulky',
            fallbackRaised: 2000,
            goal: 10000,
          ),

          const SizedBox(height: AppSpacing.xxl),
          ProjectSection(
            label: 'projects.potulky.about_label'.tr(),
            title: 'projects.potulky.about_title'.tr(),
            text: 'projects.potulky.about_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.lg),
          ProjectSection(
            label: 'projects.potulky.why_label'.tr(),
            title: 'projects.potulky.why_title'.tr(),
            text: 'projects.potulky.why_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _featureIcons.length; i++)
            ProjectFeatureCard(
              icon: _featureIcons[i],
              title: 'projects.potulky.feature${i + 1}_title'.tr(),
              text: 'projects.potulky.feature${i + 1}_text'.tr(),
            ),

          const SizedBox(height: AppSpacing.xl),
          const _StopsGrid(),

          const SizedBox(height: AppSpacing.xxl),
          ProjectSection(
            label: 'projects.potulky.audience_label'.tr(),
            title: 'projects.potulky.audience_title'.tr(),
          ),
          ProjectAudienceCard(
            icon: Icons.family_restroom_rounded,
            title: 'projects.potulky.aud1_title'.tr(),
            text: 'projects.potulky.aud1_text'.tr(),
          ),
          ProjectAudienceCard(
            icon: Icons.menu_book_rounded,
            title: 'projects.potulky.aud2_title'.tr(),
            highlight: true,
            text: 'projects.potulky.aud2_text'.tr(),
          ),
          ProjectAudienceCard(
            icon: Icons.star_rounded,
            title: 'projects.potulky.aud3_title'.tr(),
            text: 'projects.potulky.aud3_text'.tr(),
          ),

          const SizedBox(height: AppSpacing.xl),
          ProjectSection(
            label: 'projects.potulky.help_label'.tr(),
            title: 'projects.potulky.help_title'.tr(),
            text: 'projects.potulky.help_text'.tr(),
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
                      campaign: 'potulky',
                      campaignTitle: 'projects.potulky.hero_title'.tr(),
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
          const CampaignRewardsSection(campaign: 'potulky'),

          const SizedBox(height: AppSpacing.xl),
          const ProjectFooterNote(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Mriežka 26 zastávok.
class _StopsGrid extends StatelessWidget {
  const _StopsGrid();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF40467b), Color(0xFF5a6191), Color(0xFF40467b)],
        ),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'projects.potulky.stops_label'.tr(),
            style: TextStyle(
              color: HomeV2.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'projects.potulky.stops_title'.tr(),
            style: HomeV2.serifTitle(context, size: 24, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'projects.potulky.stops_text'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(26, (i) {
              final n = i + 1;
              return Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: n % 13 == 0 ? HomeV2.gold : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// Krátka „Čo je nové" obrazovka pre existujúcich používateľov po update.
/// Zobrazí sa raz (gate v `main.dart` podľa `onboarding_version`).
/// Bez výberu jazyka — existujúci používateľ ho už má nastavený (mení sa
/// v Nastaveniach); nové jazyky oznamuje feature karta.
class OnboardingUpdateScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingUpdateScreen({super.key, required this.onComplete});

  @override
  State<OnboardingUpdateScreen> createState() => _OnboardingUpdateScreenState();
}

class _OnboardingUpdateScreenState extends State<OnboardingUpdateScreen> {
  // Novinky AKTUÁLNEJ verzie (v11.2) — pri ďalšom update uprav (staré presuň
  // pod oddeľovač do [_featuresPrev], alebo ich vymeň úplne). Nezabudni zvýšiť
  // `kCurrentOnboardingVersion` v main.dart, inak sa obrazovka nikomu neukáže.
  static const _featuresNew = [
    (icon: Icons.auto_awesome_rounded, key: 'devotions_v2'),
    (icon: Icons.headphones_rounded, key: 'full_audio'),
    (icon: Icons.replay_rounded, key: 'novena_v2'),
    (icon: Icons.alarm_on_rounded, key: 'push_anon'),
    (icon: Icons.spellcheck_rounded, key: 'lectio_fix'),
  ];

  // Novinky predchádzajúcej verzie (v11.1) — pod oddeľovačom.
  static const _featuresPrev = [
    (icon: Icons.local_fire_department_rounded, key: 'novenas'),
    (icon: Icons.favorite_border_rounded, key: 'confession'),
    (icon: Icons.church_rounded, key: 'devotions_home'),
    (icon: Icons.notifications_active_rounded, key: 'intentions'),
    (icon: Icons.bolt_rounded, key: 'audio'),
    (icon: Icons.local_shipping_rounded, key: 'cod'),
  ];

  /// E-shopové karty sú len pre SK mutáciu (e-shop zatiaľ len SK; keď pribudne
  /// CZ mutácia appky, rozšír podmienku o 'cs').
  bool _showFeature(String key) =>
      !{'eshop', 'cod'}.contains(key) || context.locale.languageCode == 'sk';

  @override
  Widget build(BuildContext context) {
    final isDark = HomeV2.isDark(context);
    final mq = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/pozadie_slide.png',
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.12 : 0.20),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 30,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            tr('onboarding_update.title'),
                            style: HomeV2.serifTitle(context, size: 28, height: 1.1),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            tr('onboarding_update.subtitle'),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: HomeV2.textMuted(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Novinky aktuálnej verzie (v11.1)
                          ..._featuresNew.where((f) => _showFeature(f.key)).map(
                                (f) => _FeatureCard(
                                  icon: f.icon,
                                  title: tr(
                                      'onboarding_update.feat_${f.key}_title'),
                                  description: tr(
                                      'onboarding_update.feat_${f.key}_desc'),
                                ),
                              ),

                          // Oddeľovač — novinky predchádzajúcej verzie
                          _SectionDivider(
                            label: tr('onboarding_update.prev_section'),
                          ),

                          ..._featuresPrev.where((f) => _showFeature(f.key)).map(
                                (f) => _FeatureCard(
                                  icon: f.icon,
                                  title: tr(
                                      'onboarding_update.feat_${f.key}_title'),
                                  description: tr(
                                      'onboarding_update.feat_${f.key}_desc'),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),

                  // Pokračovať
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.sm,
                      AppSpacing.xl,
                      mq.padding.bottom + AppSpacing.md,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onComplete();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: Text(
                          tr('onboarding_update.continue'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oddeľovač sekcie „predchádzajúca verzia" — čiara s textom v strede.
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(
        height: 1,
        color: HomeV2.textMuted(context).withValues(alpha: 0.3),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: HomeV2.iconAccent(context)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

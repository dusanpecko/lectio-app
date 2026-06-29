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
  // Novinky tejto verzie (parametrický zoznam — pri ďalšom update uprav).
  static const _features = [
    (icon: Icons.palette_rounded, key: 'redesign'),
    (icon: Icons.translate_rounded, key: 'languages'),
    (icon: Icons.auto_stories_rounded, key: 'lectio'),
    (icon: Icons.widgets_rounded, key: 'widget'),
    (icon: Icons.graphic_eq_rounded, key: 'spotify'),
    (icon: Icons.menu_book_rounded, key: 'prayers'),
    (icon: Icons.help_outline_rounded, key: 'help'),
    (icon: Icons.brightness_high_rounded, key: 'screen'),
    (icon: Icons.shopping_bag_rounded, key: 'eshop'),
    (icon: Icons.system_update_rounded, key: 'updates'),
  ];

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

                          // Novinky. E-shop je len pre SK → kartu ukáž iba
                          // v slovenskej jazykovej mutácii. (Keď pribudne CZ
                          // mutácia appky, rozšír podmienku o 'cs'.)
                          ..._features
                              .where((f) =>
                                  f.key != 'eshop' ||
                                  context.locale.languageCode == 'sk')
                              .map(
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'intro_step_screen.dart';
import 'intro_translations.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final IntroTranslations translations = IntroTranslations();

  static const Color _stepLight = Color(0xFF6B73A8);

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final t = translations.getTranslations(lang);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHero(t),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero description
                  _v2Card(
                    child: Text(
                      t['heroDescription'],
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: HomeV2.textDark(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _primaryButton(
                    t['startLectio'],
                    Icons.play_arrow_rounded,
                    () => _navigateToStep(context, 'silencio'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  _section(
                    title: t['whatIs'],
                    icon: Icons.lightbulb_outline_rounded,
                    children: [
                      _body(t['whatIsText1']),
                      const SizedBox(height: AppSpacing.md),
                      _body(t['whatIsText2']),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _section(
                    title: t['fiveStepsTitle'],
                    icon: Icons.stairs_rounded,
                    children: [
                      _body(t['fiveStepsText']),
                      const SizedBox(height: AppSpacing.lg),
                      _buildStepsList(t),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _section(
                    title: t['benefitsTitle'],
                    icon: Icons.favorite_rounded,
                    children: [
                      _body(t['benefitsText']),
                      const SizedBox(height: AppSpacing.lg),
                      _buildBenefitsList(t),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _section(
                    title: t['howToTitle'],
                    icon: Icons.rocket_launch_rounded,
                    children: [
                      _body(t['howToText']),
                      const SizedBox(height: AppSpacing.lg),
                      _buildGuideList(t),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Closing quote
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(
                          alpha: HomeV2.isDark(context) ? 0.16 : 0.07),
                      borderRadius: BorderRadius.circular(HomeV2.radius),
                      border: Border.all(
                          color: HomeV2.primary.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.format_quote_rounded,
                            size: 40, color: HomeV2.iconAccent(context)),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          t['closingQuote'],
                          style: HomeV2.serifQuote(context, size: 19, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          t['closingText'],
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            color: HomeV2.textMuted(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _primaryButton(
                    t['startFirstStep'],
                    Icons.auto_stories_rounded,
                    () => _navigateToStep(context, 'silencio'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero(Map<String, dynamic> t) {
    final topPad = MediaQuery.of(context).padding.top;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final bg = HomeV2.background(context);
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: isTablet ? 340 : 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Image.asset(
              'assets/images/intro_about_bg.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: HomeV2.primary.withValues(alpha: 0.4)),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.10),
                    HomeV2.primary.withValues(alpha: 0.55),
                    bg,
                  ],
                  stops: const [0.0, 0.35, 0.85, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t['heroTitle'],
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 36 : 30,
                    color: Colors.white,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
                const SizedBox(height: 4),
                Text(
                  t['heroSubtitle'],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: halo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stavebné prvky ──────────────────────────────────────────────────────────
  Widget _v2Card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: child,
    );
  }

  Widget _body(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: HomeV2.textDark(context),
        ),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return _v2Card(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: HomeV2.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: HomeV2.iconAccent(context), size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: HomeV2.serifTitle(context, size: 20, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }

  // ── Kroky ─────────────────────────────────────────────────────────────────
  Widget _buildStepsList(Map<String, dynamic> t) {
    final steps = t['steps'] as List<dynamic>;
    return Column(
      children: steps.map<Widget>((step) {
        final s = step as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: HomeV2.primary.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _navigateToStep(context, s['slug']);
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [HomeV2.primary, _stepLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: Icon(_getStepIcon(s['slug']),
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t['stepLabel']} ${s['number']} • ${s['duration']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: HomeV2.textMuted(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s['title'],
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: HomeV2.textDark(context),
                            ),
                          ),
                          Text(
                            s['subtitle'],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: HomeV2.iconAccent(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s['description'],
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: HomeV2.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: HomeV2.textMuted(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitsList(Map<String, dynamic> t) {
    final benefits = t['benefits'] as List<dynamic>;
    final icons = [
      Icons.hearing_rounded,
      Icons.favorite_rounded,
      Icons.refresh_rounded,
      Icons.people_rounded,
    ];
    return Column(
      children: List.generate(benefits.length, (index) {
        final b = benefits[index] as Map<String, dynamic>;
        return _infoRow(
          icon: icons[index % icons.length],
          title: b['title'],
          description: b['description'],
        );
      }),
    );
  }

  Widget _buildGuideList(Map<String, dynamic> t) {
    final guide = t['guide'] as List<dynamic>;
    final icons = [
      Icons.access_time_filled_rounded,
      Icons.bookmark_rounded,
      Icons.favorite_rounded,
      Icons.verified_user_rounded,
    ];
    return Column(
      children: List.generate(guide.length, (index) {
        final g = guide[index] as Map<String, dynamic>;
        return _infoRow(
          icon: icons[index % icons.length],
          title: g['title'],
          description: g['description'],
        );
      }),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: HomeV2.iconAccent(context), size: 20),
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
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
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

  IconData _getStepIcon(String slug) {
    switch (slug) {
      case 'silencio':
        return Icons.hearing_rounded;
      case 'lectio':
        return Icons.menu_book_rounded;
      case 'meditatio':
        return Icons.psychology_rounded;
      case 'oratio':
        return Icons.favorite_rounded;
      case 'contemplatio':
        return Icons.visibility_rounded;
      case 'actio':
        return Icons.directions_run_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  void _navigateToStep(BuildContext context, String step) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IntroStepScreen(step: step)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

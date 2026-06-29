import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'intro_step_translations.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class IntroStepScreen extends StatefulWidget {
  final String step;

  const IntroStepScreen({super.key, required this.step});

  @override
  State<IntroStepScreen> createState() => _IntroStepScreenState();
}

class _IntroStepScreenState extends State<IntroStepScreen> {
  final IntroStepTranslations translations = IntroStepTranslations();

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final t = translations.getTranslations(lang, widget.step);

    if (t == null) {
      final errorT = translations.getErrorTranslations(lang);
      return Scaffold(
        backgroundColor: HomeV2.background(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: HomeV2.primary,
          title: Text(errorT['notFoundTitle']!),
        ),
        body: Center(
          child: Text('${errorT['notFoundMessage']}: "${widget.step}"'),
        ),
      );
    }

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
                  // Quote
                  if (t['quoteText'] != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
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
                              size: 34, color: HomeV2.iconAccent(context)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            t['quoteText'],
                            style:
                                HomeV2.serifQuote(context, size: 19, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          if (t['quoteReference'] != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              t['quoteReference'],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: HomeV2.textMuted(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  _buildNavigationButtons(context, t),
                  const SizedBox(height: AppSpacing.xl),

                  if (t['introParagraph'] != null) ...[
                    _v2Card(child: _body(t['introParagraph'])),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (t['whatIsTitle'] != null) ...[
                    _section(
                      title: t['whatIsTitle'],
                      icon: Icons.lightbulb_outline_rounded,
                      children: [
                        if (t['whatIsContent'] != null) _body(t['whatIsContent']),
                        if (t['whatIsContent1'] != null) ...[
                          _body(t['whatIsContent1']),
                          if (t['whatIsContent2'] != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _body(t['whatIsContent2']),
                          ],
                        ],
                        if (t['whatIsQuote'] != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _tintBox(
                            child: Text(
                              t['whatIsQuote'],
                              style: HomeV2.serifQuote(context, size: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (t['howToTitle'] != null) ...[
                    _section(
                      title: t['howToTitle'],
                      icon: Icons.help_outline_rounded,
                      children: [
                        if (t['howToList'] != null)
                          _buildList(context, t['howToList']),
                        if (t['howToSteps'] != null)
                          _buildStepsList(context, t['howToSteps']),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (t['practicalTips'] != null) ...[
                    _section(
                      title: t['practicalTipsTitle'] ?? 'Praktické návody',
                      icon: Icons.tips_and_updates_rounded,
                      children: [_buildTipsList(context, t['practicalTips'])],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (t['exampleTitle'] != null) ...[
                    _section(
                      title: t['exampleTitle'],
                      icon: Icons.lightbulb_rounded,
                      children: [_buildExample(context, t)],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (t['closingTitle'] != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: HomeV2.primary,
                        borderRadius: BorderRadius.circular(HomeV2.radius),
                        boxShadow: HomeV2.softShadow(context),
                      ),
                      child: Column(
                        children: [
                          Text(
                            t['closingTitle'],
                            style: HomeV2.serifTitle(context,
                                size: 20, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          if (t['closingText'] != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              t['closingText'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (t['closingQuote'] != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(HomeV2.radiusSm),
                              ),
                              child: Text(
                                t['closingQuote'],
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  _buildNavigationButtons(context, t),
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
      height: isTablet ? 320 : 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Image.asset(
              _getStepBackgroundImage(widget.step),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStepIcon(widget.step),
                              size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            t['stepIndicator'] ?? 'Krok',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  t['stepTitle'] ?? 'Lectio Divina',
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 36 : 30,
                    color: Colors.white,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stavebné prvky ──────────────────────────────────────────────────────────
  Widget _v2Card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: child,
    );
  }

  Widget _tintBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        border: Border.all(color: HomeV2.primary.withValues(alpha: 0.12)),
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

  Widget _buildList(BuildContext context, List<dynamic> items) {
    return Column(
      children: items.map<Widget>((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(
                  color: HomeV2.iconAccent(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _body(item.toString())),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList(BuildContext context, List<dynamic> steps) {
    return Column(
      children: steps.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final step = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: HomeV2.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step is Map && step['title'] != null) ...[
                      Text(
                        step['title'],
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (step['items'] != null)
                        ...((step['items'] as List).map<Widget>((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text(
                              '• $item',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: HomeV2.textMuted(context),
                              ),
                            ),
                          );
                        })),
                    ] else
                      _body(step.toString()),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTipsList(BuildContext context, List<dynamic> tips) {
    return Column(
      children: tips.map<Widget>((tip) {
        if (tip is! Map) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: HomeV2.primary.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tip['title'] != null) ...[
                Text(
                  tip['title'],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (tip['description'] != null) ...[
                Text(
                  tip['description'],
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.iconAccent(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (tip['content'] != null)
                Text(
                  tip['content'],
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: HomeV2.textMuted(context),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExample(BuildContext context, Map<String, dynamic> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t['exampleVerse'] != null) ...[
          _tintBox(
            child: Text(
              t['exampleVerse'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeV2.textDark(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (t['exampleSteps'] != null) ...[
          ...((t['exampleSteps'] as List).map<Widget>((step) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              ),
              child: Text(
                step.toString(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: HomeV2.textDark(context),
                ),
              ),
            );
          })),
        ],
        if (t['exampleSummary'] != null) ...[
          _tintBox(
            child: Text(
              t['exampleSummary'],
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: HomeV2.iconAccent(context),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context, Map<String, dynamic> t) {
    final previousStep = _getPreviousStep(widget.step);
    final nextStep = _getNextStep(widget.step);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (previousStep != null) {
                _navigateToStep(context, previousStep);
              } else {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            icon: Icon(
              previousStep != null
                  ? Icons.arrow_back_rounded
                  : Icons.home_rounded,
              size: 18,
            ),
            label: Text(
              previousStep != null
                  ? (t['back'] ?? 'Späť')
                  : (t['backToOverview'] ?? 'Späť na prehľad'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeV2.iconAccent(context),
              side: BorderSide(
                color: HomeV2.primary.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (nextStep != null) {
                _navigateToStep(context, nextStep);
              } else {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            icon: Icon(
              nextStep != null
                  ? Icons.arrow_forward_rounded
                  : Icons.home_rounded,
              size: 18,
            ),
            label: Text(
              nextStep != null
                  ? (t['next'] ?? 'Ďalej')
                  : (t['backToOverview'] ?? 'Späť na prehľad'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeV2.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStepIcon(String step) {
    switch (step) {
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

  String _getStepBackgroundImage(String step) {
    switch (step) {
      case 'silencio':
        return 'assets/images/intro_silencio_bg.webp';
      case 'lectio':
        return 'assets/images/intro_lectio_bg.webp';
      case 'contemplatio':
        return 'assets/images/intro_contemplatio_bg.webp';
      default:
        return 'assets/images/intro_about_bg.webp';
    }
  }

  String? _getPreviousStep(String currentStep) {
    const steps = [
      'silencio',
      'lectio',
      'meditatio',
      'oratio',
      'contemplatio',
      'actio',
    ];
    final currentIndex = steps.indexOf(currentStep);
    if (currentIndex <= 0) return null;
    return steps[currentIndex - 1];
  }

  String? _getNextStep(String currentStep) {
    const steps = [
      'silencio',
      'lectio',
      'meditatio',
      'oratio',
      'contemplatio',
      'actio',
    ];
    final currentIndex = steps.indexOf(currentStep);
    if (currentIndex < 0 || currentIndex >= steps.length - 1) return null;
    return steps[currentIndex + 1];
  }

  void _navigateToStep(BuildContext context, String step) {
    Navigator.pushReplacement(
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

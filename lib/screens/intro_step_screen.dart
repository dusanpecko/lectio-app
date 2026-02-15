import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import 'intro_step_translations.dart';
import '../shared/app_spacing.dart';

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
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final t = translations.getTranslations(lang, widget.step);

    if (t == null) {
      final errorT = translations.getErrorTranslations(lang);
      return Scaffold(
        appBar: AppBar(title: Text(errorT['notFoundTitle']!)),
        body: Center(
          child: Text('${errorT['notFoundMessage']}: "${widget.step}"'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar with step indicator
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width >= 600
                ? 450.0
                : 300.0,
            floating: false,
            pinned: true,
            backgroundColor: _getStepColor(widget.step),
            title: Text(
              t['stepTitle'] ?? 'Lectio Divina',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: null, // Disable default title to avoid overlap
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.asset(
                    _getStepBackgroundImage(widget.step),
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _getStepColor(widget.step).withValues(alpha: 0.6),
                          _getStepColor(widget.step).withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width >= 600
                            ? AppSpacing.xxl * 1.5
                            : AppSpacing.xxl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Step indicator
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width >= 600
                                  ? 24
                                  : 16,
                              vertical: MediaQuery.of(context).size.width >= 600
                                  ? 12
                                  : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: Text(
                              t['stepIndicator'] ?? 'Krok',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize:
                                    MediaQuery.of(context).size.width >= 600
                                    ? 18
                                    : 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.width >= 600
                                ? AppSpacing.xl
                                : AppSpacing.lg,
                          ),

                          // Step icon
                          Container(
                            padding: EdgeInsets.all(
                              MediaQuery.of(context).size.width >= 600
                                  ? AppSpacing.xl
                                  : AppSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: Icon(
                              _getStepIcon(widget.step),
                              size: MediaQuery.of(context).size.width >= 600
                                  ? 64
                                  : 48,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.width >= 600
                                ? AppSpacing.xl
                                : AppSpacing.lg,
                          ),

                          // Step title
                          Text(
                            t['stepTitle'] ?? 'Step Title',
                            style:
                                (MediaQuery.of(context).size.width >= 600
                                        ? theme.textTheme.headlineMedium
                                        : theme.textTheme.headlineSmall)
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Quote section
                  if (t['quoteText'] != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: SizedBox(
                        width: double.infinity,
                        child: Card(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 24.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  t['quoteText'],
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (t['quoteReference'] != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    t['quoteReference'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Navigation buttons (top)
                  _buildNavigationButtons(context, t),
                  const SizedBox(height: AppSpacing.xxl),

                  // Introduction paragraph
                  if (t['introParagraph'] != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          t['introParagraph'],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // What is section
                  if (t['whatIsTitle'] != null) ...[
                    _buildSection(
                      context,
                      title: t['whatIsTitle'],
                      icon: Icons.lightbulb_outline_rounded,
                      children: [
                        if (t['whatIsContent'] != null)
                          Text(
                            t['whatIsContent'],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        if (t['whatIsContent1'] != null) ...[
                          Text(
                            t['whatIsContent1'],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                          if (t['whatIsContent2'] != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              t['whatIsContent2'],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                        if (t['whatIsQuote'] != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              t['whatIsQuote'],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // How to section
                  if (t['howToTitle'] != null) ...[
                    _buildSection(
                      context,
                      title: t['howToTitle'],
                      icon: Icons.help_outline_rounded,
                      children: [
                        if (t['howToList'] != null)
                          _buildList(context, t['howToList']),
                        if (t['howToSteps'] != null)
                          _buildStepsList(context, t['howToSteps']),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Practical tips
                  if (t['practicalTips'] != null) ...[
                    _buildSection(
                      context,
                      title: t['practicalTipsTitle'] ?? 'Praktické návody',
                      icon: Icons.tips_and_updates_rounded,
                      children: [_buildTipsList(context, t['practicalTips'])],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Example section
                  if (t['exampleTitle'] != null) ...[
                    _buildSection(
                      context,
                      title: t['exampleTitle'],
                      icon: Icons.lightbulb_rounded,
                      children: [_buildExample(context, t)],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Closing section
                  if (t['closingTitle'] != null) ...[
                    Card(
                      color: _getStepColor(widget.step),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          children: [
                            Text(
                              t['closingTitle'],
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (t['closingText'] != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                t['closingText'],
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
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
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: Text(
                                  t['closingQuote'],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Navigation buttons (bottom)
                  _buildNavigationButtons(context, t),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> items) {
    final theme = Theme.of(context);

    return Column(
      children: items.map<Widget>((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.toString(),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList(BuildContext context, List<dynamic> steps) {
    final theme = Theme.of(context);

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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step is Map && step['title'] != null) ...[
                      Text(
                        step['title'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (step['items'] != null)
                        ...((step['items'] as List).map<Widget>((item) {
                          final theme = Theme.of(context);
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              '• $item',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          );
                        }).toList()),
                    ] else ...[
                      Text(
                        step.toString(),
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
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
    final theme = Theme.of(context);

    return Column(
      children: tips.map<Widget>((tip) {
        if (tip is! Map) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Card(
            elevation: AppElevation.low,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tip['title'] != null) ...[
                    Text(
                      tip['title'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (tip['description'] != null) ...[
                    Text(
                      tip['description'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (tip['content'] != null)
                    Text(
                      tip['content'],
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExample(BuildContext context, Map<String, dynamic> t) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t['exampleVerse'] != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              t['exampleVerse'],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (t['exampleSteps'] != null) ...[
          ...((t['exampleSteps'] as List).map<Widget>((step) {
            final theme = Theme.of(context);
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                step.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            );
          }).toList()),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (t['exampleSummary'] != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: _getStepColor(widget.step).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _getStepColor(widget.step).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              t['exampleSummary'],
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: _getStepColor(widget.step),
                fontWeight: FontWeight.w500,
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
        // Left button: previous step or back to overview
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
            ),
            label: Text(
              previousStep != null
                  ? (t['back'] ?? 'Späť')
                  : (t['backToOverview'] ?? 'Späť na prehľad'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.isDark(context)
                  ? AppColors.darkPrimaryLight
                  : AppColors.primary,
              side: BorderSide(
                color: AppColors.isDark(context)
                    ? AppColors.darkPrimaryLight
                    : AppColors.primary,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        // Right button: next step or back to overview
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
            ),
            label: Text(
              nextStep != null
                  ? (t['next'] ?? 'Ďalej')
                  : (t['backToOverview'] ?? 'Späť na prehľad'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStepColor(widget.step),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStepColor(String step) {
    return AppColors.primary;
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

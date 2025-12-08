import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'intro_step_translations.dart';

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
            expandedHeight: 280,
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getStepGradient(widget.step),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Step indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t['stepIndicator'] ?? 'Krok',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Step icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getStepIcon(widget.step),
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Step title
                        Text(
                          t['stepTitle'] ?? 'Step Title',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Quote section
                  if (t['quoteText'] != null) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t['quoteText'],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (t['quoteReference'] != null) ...[
                              const SizedBox(height: 8),
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
                    const SizedBox(height: 24),
                  ],

                  // Introduction paragraph
                  if (t['introParagraph'] != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          t['introParagraph'],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                            Text(
                              t['whatIsContent2'],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                        if (t['whatIsQuote'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                  ],

                  // Practical tips
                  if (t['practicalTips'] != null) ...[
                    _buildSection(
                      context,
                      title: t['practicalTipsTitle'] ?? 'Praktické návody',
                      icon: Icons.tips_and_updates_rounded,
                      children: [_buildTipsList(context, t['practicalTips'])],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Example section
                  if (t['exampleTitle'] != null) ...[
                    _buildSection(
                      context,
                      title: t['exampleTitle'],
                      icon: Icons.lightbulb_rounded,
                      children: [_buildExample(context, t)],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Closing section
                  if (t['closingTitle'] != null) ...[
                    Card(
                      color: _getStepColor(widget.step),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
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
                              const SizedBox(height: 16),
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
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 24),
                  ],

                  // Navigation buttons
                  Row(
                    children: [
                      if (_getPreviousStep(widget.step) != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToStep(
                              context,
                              _getPreviousStep(widget.step)!,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: Text(t['back'] ?? 'Späť'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (_getPreviousStep(widget.step) != null &&
                          _getNextStep(widget.step) != null)
                        const SizedBox(width: 16),
                      if (_getNextStep(widget.step) != null)
                        Expanded(
                          flex: _getPreviousStep(widget.step) == null ? 1 : 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToStep(
                              context,
                              _getNextStep(widget.step)!,
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(t['next'] ?? 'Ďalej'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStepColor(widget.step),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (_getNextStep(widget.step) == null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            ),
                            icon: const Icon(Icons.home_rounded),
                            label: Text(
                              t['backToOverview'] ?? 'Späť na prehľad',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStepColor(widget.step),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
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
            const SizedBox(height: 20),
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
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
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
          margin: const EdgeInsets.only(bottom: 16),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      if (step['items'] != null)
                        ...((step['items'] as List).map<Widget>((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
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
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                    const SizedBox(height: 8),
                  ],
                  if (tip['description'] != null) ...[
                    Text(
                      tip['description'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              t['exampleVerse'],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (t['exampleSteps'] != null) ...[
          ...((t['exampleSteps'] as List).map<Widget>((step) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                step.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
        ],

        if (t['exampleSummary'] != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStepColor(widget.step).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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

  Color _getStepColor(String step) {
    switch (step) {
      case 'lectio':
        return Colors.blue.shade700;
      case 'meditatio':
        return Colors.green.shade700;
      case 'oratio':
        return Colors.amber.shade700;
      case 'contemplatio':
        return Colors.red.shade700;
      case 'actio':
        return Colors.purple.shade700;
      default:
        return Colors.indigo.shade700;
    }
  }

  List<Color> _getStepGradient(String step) {
    switch (step) {
      case 'lectio':
        return [
          Colors.blue.shade900,
          Colors.indigo.shade900,
          Colors.purple.shade900,
        ];
      case 'meditatio':
        return [
          Colors.green.shade900,
          Colors.teal.shade900,
          Colors.cyan.shade900,
        ];
      case 'oratio':
        return [
          Colors.amber.shade900,
          Colors.orange.shade900,
          Colors.red.shade900,
        ];
      case 'contemplatio':
        return [
          Colors.red.shade900,
          Colors.pink.shade900,
          Colors.purple.shade900,
        ];
      case 'actio':
        return [
          Colors.purple.shade900,
          Colors.deepPurple.shade900,
          Colors.indigo.shade900,
        ];
      default:
        return [
          Colors.indigo.shade900,
          Colors.purple.shade900,
          Colors.blue.shade900,
        ];
    }
  }

  IconData _getStepIcon(String step) {
    switch (step) {
      case 'lectio':
        return Icons.menu_book_rounded;
      case 'meditatio':
        return Icons.psychology_rounded;
      case 'oratio':
        return Icons.favorite_rounded;
      case 'contemplatio':
        return Icons.self_improvement_rounded;
      case 'actio':
        return Icons.directions_run_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  String? _getPreviousStep(String currentStep) {
    const steps = ['lectio', 'meditatio', 'oratio', 'contemplatio', 'actio'];
    final currentIndex = steps.indexOf(currentStep);
    if (currentIndex <= 0) return null;
    return steps[currentIndex - 1];
  }

  String? _getNextStep(String currentStep) {
    const steps = ['lectio', 'meditatio', 'oratio', 'contemplatio', 'actio'];
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

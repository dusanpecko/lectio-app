import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'intro_step_screen.dart';
import 'intro_translations.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final IntroTranslations translations = IntroTranslations();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final t = translations.getTranslations(lang);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar
          SliverAppBar(
            expandedHeight: 320,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                      Colors.deepPurple.shade900,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t['heroTitle'],
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t['heroSubtitle'],
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.yellow.shade200,
                            fontWeight: FontWeight.w600,
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

                  // Hero Description
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        t['heroDescription'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToStep(context, 'lectio'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(
                        t['startLectio'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade600,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // What is Lectio Divina section
                  _buildSection(
                    context,
                    title: t['whatIs'],
                    icon: Icons.lightbulb_outline_rounded,
                    children: [
                      Text(
                        t['whatIsText1'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t['whatIsText2'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Five Steps section
                  _buildSection(
                    context,
                    title: t['fiveStepsTitle'],
                    icon: Icons.stairs_rounded,
                    children: [
                      Text(
                        t['fiveStepsText'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      _buildStepsGrid(context, t),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Benefits section
                  _buildSection(
                    context,
                    title: t['benefitsTitle'],
                    icon: Icons.favorite_rounded,
                    children: [
                      Text(
                        t['benefitsText'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      _buildBenefitsGrid(context, t),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // How to start section
                  _buildSection(
                    context,
                    title: t['howToTitle'],
                    icon: Icons.rocket_launch_rounded,
                    children: [
                      Text(
                        t['howToText'],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      _buildGuideGrid(context, t),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Closing Quote
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 48,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t['closingQuote'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onPrimaryContainer,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t['closingText'],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Final CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToStep(context, 'lectio'),
                      icon: const Icon(Icons.auto_stories_rounded, size: 24),
                      label: Text(
                        t['startFirstStep'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
                    style: theme.textTheme.headlineSmall?.copyWith(
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

  Widget _buildStepsGrid(BuildContext context, Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final steps = t['steps'] as List<dynamic>;

    return Column(
      children: steps.map<Widget>((step) {
        final stepData = step as Map<String, dynamic>;
        final stepColors = [
          [Colors.blue.shade500, Colors.indigo.shade600],
          [Colors.green.shade500, Colors.teal.shade600],
          [Colors.amber.shade500, Colors.orange.shade600],
          [Colors.red.shade500, Colors.pink.shade600],
          [Colors.purple.shade500, Colors.deepPurple.shade600],
        ];
        final colorIndex = (stepData['number'] as int) - 1;
        final colors = stepColors[colorIndex];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            child: InkWell(
              onTap: () => _navigateToStep(context, stepData['slug']),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _getStepIcon(stepData['slug']),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Krok ${stepData['number']} • ${stepData['duration']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stepData['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stepData['subtitle'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stepData['description'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitsGrid(BuildContext context, Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final benefits = t['benefits'] as List<dynamic>;

    return Column(
      children: benefits.map<Widget>((benefit) {
        final benefitData = benefit as Map<String, dynamic>;
        final icons = [
          Icons.hearing_rounded,
          Icons.favorite_rounded,
          Icons.refresh_rounded,
          Icons.people_rounded,
        ];
        final colors = [
          theme.colorScheme.primary,
          Colors.green.shade600,
          Colors.purple.shade600,
          Colors.orange.shade600,
        ];
        final index = benefits.indexOf(benefit);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors[index].withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icons[index], color: colors[index], size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefitData['title'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          benefitData['description'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuideGrid(BuildContext context, Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final guide = t['guide'] as List<dynamic>;

    return Column(
      children: guide.map<Widget>((item) {
        final itemData = item as Map<String, dynamic>;
        final icons = [
          Icons.access_time_filled,
          Icons.bookmark_rounded,
          Icons.favorite_rounded,
          Icons.verified_user_rounded,
        ];
        final index = guide.indexOf(item);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icons[index],
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemData['title'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itemData['description'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getStepIcon(String slug) {
    switch (slug) {
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

  void _navigateToStep(BuildContext context, String step) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IntroStepScreen(step: step)),
    );
  }
}

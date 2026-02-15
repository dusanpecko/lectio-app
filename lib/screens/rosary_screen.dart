// lib/screens/rosary_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../shared/app_colors.dart';
import '../shared/rosary_constants.dart';
import 'rosary_category_screen.dart';
import '../shared/app_spacing.dart';

class RosaryScreen extends StatefulWidget {
  const RosaryScreen({super.key});

  @override
  State<RosaryScreen> createState() => _RosaryScreenState();
}

class _RosaryScreenState extends State<RosaryScreen> {
  final RosaryService _rosaryService = RosaryService();
  List<RosaryCategoryStats> _categoryStats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = context.locale.languageCode;
      final stats = await _rosaryService.getCategoryStats(lang);

      if (mounted) {
        setState(() {
          _categoryStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCategory(RosaryCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RosaryCategoryScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? _buildLoadingState(theme)
          : _error != null
          ? _buildErrorState(theme)
          : CustomScrollView(
              slivers: [
                // Hero App Bar s obrázkom
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.width >= 600
                      ? 450.0
                      : 300.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  title: Text(
                    tr('rosary_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _loadData,
                      tooltip: tr('refresh'),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/rosary_backround.webp',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.6),
                                AppColors.primary.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
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
                                Container(
                                  padding: EdgeInsets.all(
                                    MediaQuery.of(context).size.width >= 600
                                        ? AppSpacing.xl
                                        : AppSpacing.lg,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    size:
                                        MediaQuery.of(context).size.width >= 600
                                        ? 64
                                        : 48,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width >= 600
                                      ? AppSpacing.xl
                                      : AppSpacing.lg,
                                ),
                                Text(
                                  tr('rosary_main_title'),
                                  style:
                                      (MediaQuery.of(context).size.width >= 600
                                              ? theme.textTheme.headlineLarge
                                              : theme.textTheme.headlineMedium)
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width >= 600
                                      ? AppSpacing.md
                                      : AppSpacing.sm,
                                ),
                                Text(
                                  tr('rosary_main_subtitle'),
                                  style:
                                      (MediaQuery.of(context).size.width >= 600
                                              ? theme.textTheme.headlineMedium
                                              : theme.textTheme.titleLarge)
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
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
                SliverToBoxAdapter(child: _buildContentBody(theme)),
              ],
            ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('loading_rosary'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tr('error_loading_rosary'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? tr('unknown_error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('try_again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _buildHowToSection(theme),
          const SizedBox(height: AppSpacing.xxxl),
          _buildCategoriesSection(theme),
          const SizedBox(height: AppSpacing.xxxl),
          _buildBenefitsSection(theme),
        ],
      ),
    );
  }

  Widget _buildHowToSection(ThemeData theme) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Hlavička
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    tr('how_to_pray_rosary'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FAQ - Tradičný ruženec
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              leading: Text('📿', style: theme.textTheme.headlineSmall),
              title: Text(
                tr('traditional_rosary'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                _buildHowToItem(theme, tr('opening_prayers')),
                _buildHowToItem(theme, tr('five_decades')),
                _buildHowToItem(theme, tr('decade_structure')),
              ],
            ),
          ),

          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),

          // FAQ - Lectio Divina kroky
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              leading: Text('📖', style: theme.textTheme.headlineSmall),
              title: Text(
                tr('lectio_divina_steps'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: RosaryConstants.lectioDivinaSteps
                  .map((step) => _buildLectioDivinaStep(theme, step))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToItem(ThemeData theme, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectioDivinaStep(ThemeData theme, Map<String, dynamic> step) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.md),
            decoration: BoxDecoration(
              color: RosaryConstants.hexToColor(step['color']),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${step['title']}: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: step['description'],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(ThemeData theme) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('select_mystery_category'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Changed from GridView to Column with individual cards
        Column(
          children: RosaryCategory.values.map((category) {
            final categoryInfo = RosaryConstants.getCategoryInfo(category);
            final stats = _categoryStats.firstWhere(
              (s) => s.category == category,
              orElse: () => RosaryCategoryStats(
                category: category,
                totalCount: 0,
                withAudio: 0,
                withImages: 0,
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildCategoryCard(theme, category, categoryInfo, stats),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    ThemeData theme,
    RosaryCategory category,
    RosaryCategoryInfo categoryInfo,
    RosaryCategoryStats stats,
  ) {
    final color = RosaryConstants.hexToColor(categoryInfo.color);

    return GestureDetector(
      onTap: () => _navigateToCategory(category),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background gradient
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [color.withValues(alpha: 0.1), Colors.transparent],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikona
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      categoryInfo.icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Názov
                  Text(
                    categoryInfo.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Popis
                  Text(
                    categoryInfo.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Štatistiky
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.book_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${stats.totalCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (stats.withAudio > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.headphones_rounded,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${stats.withAudio}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsSection(ThemeData theme) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spiritual Benefits Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tr('spiritual_benefits'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildBenefitItem(
                theme,
                Icons.auto_stories_rounded,
                tr('deeper_understanding'),
              ),
              _buildBenefitItem(
                theme,
                Icons.visibility_rounded,
                tr('peaceful_prayer'),
              ),
              _buildBenefitItem(
                theme,
                Icons.directions_walk_rounded,
                tr('practical_application'),
              ),
              _buildBenefitItem(
                theme,
                Icons.trending_up_rounded,
                tr('spiritual_growth'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // App Features Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tr('app_features'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildBenefitItem(
                theme,
                Icons.headphones_rounded,
                tr('audio_recordings'),
              ),
              _buildBenefitItem(
                theme,
                Icons.schedule_rounded,
                tr('time_guidance'),
              ),
              _buildBenefitItem(
                theme,
                Icons.book_rounded,
                tr('complete_texts'),
              ),
              _buildBenefitItem(
                theme,
                Icons.navigation_rounded,
                tr('step_by_step'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(ThemeData theme, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

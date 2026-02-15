// lib/screens/adoration_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/adoration_model.dart';
import '../services/adoration_service.dart';
import '../shared/app_colors.dart';
import 'adoration_detail_screen.dart';
import '../shared/app_spacing.dart';

class AdorationScreen extends StatefulWidget {
  const AdorationScreen({super.key});

  @override
  State<AdorationScreen> createState() => _AdorationScreenState();
}

class _AdorationScreenState extends State<AdorationScreen> {
  final AdorationService _adorationService = AdorationService();
  List<Adoration> _adorations = [];
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
      final adorations = await _adorationService.getAdorations(lang);

      if (mounted) {
        setState(() {
          _adorations = adorations;
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

  void _navigateToAdoration(Adoration adoration) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdorationDetailScreen(
          adorationId: adoration.id,
          initialAdoration: adoration,
        ),
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
                // Hero App Bar
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.width >= 600
                      ? 450.0
                      : 300.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  title: Text(
                    tr('adoration_title'),
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
                          'assets/images/adoration-background.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: AppColors.primary);
                          },
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
                                    Icons.favorite_rounded,
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
                                  tr('adoration_main_title'),
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
                                  tr('adoration_main_subtitle'),
                                  style:
                                      (MediaQuery.of(context).size.width >= 600
                                              ? theme.textTheme.headlineMedium
                                              : theme.textTheme.titleMedium)
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
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

                // Adoration List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final adoration = _adorations[index];
                      return _buildAdorationCard(theme, adoration, index);
                    }, childCount: _adorations.length),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
            tr('loading_adorations'),
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
              tr('error_loading_adorations'),
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

  Widget _buildAdorationCard(ThemeData theme, Adoration adoration, int index) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: AppElevation.none,
        child: InkWell(
          onTap: () => _navigateToAdoration(adoration),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Number Badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adoration.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          adoration.biblicalText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (adoration.author != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            adoration.author!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (adoration.hasAudio)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.headphones_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      tr('audio'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            if (adoration.hasImage) ...[
                              if (adoration.hasAudio)
                                const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_rounded,
                                      size: 14,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      tr('image'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow Icon
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

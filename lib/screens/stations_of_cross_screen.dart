// lib/screens/stations_of_cross_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/stations_of_cross_model.dart';
import '../services/stations_of_cross_service.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import 'stations_of_cross_detail_screen.dart';

class StationsOfCrossScreen extends StatefulWidget {
  const StationsOfCrossScreen({super.key});

  @override
  State<StationsOfCrossScreen> createState() => _StationsOfCrossScreenState();
}

class _StationsOfCrossScreenState extends State<StationsOfCrossScreen> {
  final StationsOfCrossService _service = StationsOfCrossService();
  List<StationsOfCross> _items = [];
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
      final items = await _service.getStationsOfCross(lang);

      if (mounted) {
        setState(() {
          _items = items;
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

  void _navigateToDetail(StationsOfCross item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StationsOfCrossDetailScreen(
          stationsOfCrossId: item.id,
          initialData: item,
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
                _buildHeroAppBar(theme),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _items[index];
                      return _buildItemCard(theme, item, index);
                    }, childCount: _items.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildHeroAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width >= 600 ? 450.0 : 300.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      title: Text(
        tr('stations_of_cross_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadData,
          tooltip: tr('refresh'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero background image
            Image.asset(
              'assets/images/station_cross_backround.webp',
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
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Icon(
                        Icons.add_rounded, // Cross icon
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
                    Text(
                      tr('stations_of_cross_main_title'),
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
                      height: MediaQuery.of(context).size.width >= 600
                          ? AppSpacing.md
                          : AppSpacing.sm,
                    ),
                    Text(
                      tr('stations_of_cross_subtitle'),
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
    );
  }

  Widget _buildItemCard(ThemeData theme, StationsOfCross item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: AppElevation.none,
        child: InkWell(
          onTap: () => _navigateToDetail(item),
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
                  // Thumbnail or number badge
                  if (item.hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CachedNetworkImage(
                        imageUrl: item.illustrationImage!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildNumberBadge(theme, index),
                      ),
                    )
                  else
                    _buildNumberBadge(theme, index),
                  const SizedBox(width: AppSpacing.lg),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.subtitle != null &&
                            item.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.author != null && item.author!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.author!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Arrow
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

  Widget _buildNumberBadge(ThemeData theme, int index) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
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
            tr('loading'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
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
              tr('error_loading'),
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
}

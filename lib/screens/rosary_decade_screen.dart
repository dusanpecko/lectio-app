// lib/screens/rosary_decade_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../shared/app_colors.dart';
import '../shared/rosary_constants.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';
import '../shared/app_spacing.dart';

class RosaryDecadeScreen extends StatefulWidget {
  final RosaryCategory category;
  final int decadeOrder;

  const RosaryDecadeScreen({
    super.key,
    required this.category,
    required this.decadeOrder,
  });

  @override
  State<RosaryDecadeScreen> createState() => _RosaryDecadeScreenState();
}

class _RosaryDecadeScreenState extends State<RosaryDecadeScreen> {
  final RosaryService _rosaryService = RosaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  RosaryDecade? _decade;
  RosaryNavigation? _navigation;
  bool _isLoading = true;
  String? _error;
  // bool _isBookmarked = false; // TODO: záložka - zatiaľ zakomentované

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDecade();
  }

  Future<void> _loadDecade() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = context.locale.languageCode;

      // Načítanie desiatka
      final decade = await _rosaryService.getDecade(
        widget.category,
        widget.decadeOrder,
        lang,
      );

      if (decade == null) {
        throw Exception('Desiatka nenájdený');
      }

      // Načítanie navigácie
      final navigation = await _rosaryService.getDecadeNavigation(
        widget.category,
        widget.decadeOrder,
        lang,
      );

      if (mounted) {
        setState(() {
          _decade = decade;
          _navigation = navigation;
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

  void _handlePreviousDecade() {
    if (_navigation?.canGoToPrevious == true &&
        _navigation!.previousDecade != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RosaryDecadeScreen(
            category: widget.category,
            decadeOrder: _navigation!.previousDecade!.order,
          ),
        ),
      );
    }
  }

  void _handleNextDecade() {
    if (_navigation?.canGoToNext == true && _navigation!.nextDecade != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RosaryDecadeScreen(
            category: widget.category,
            decadeOrder: _navigation!.nextDecade!.order,
          ),
        ),
      );
    }
  }

  // TODO: záložka a zdieľať - zatiaľ zakomentované
  // void _handleShare() async {
  //   if (_decade != null) {
  //     final categoryInfo = RosaryConstants.getCategoryInfo(widget.category);
  //     final shareText =
  //         '${categoryInfo.name} - ${_decade!.title}\n\n${_decade!.introduction}';
  //     try {
  //       await Clipboard.setData(ClipboardData(text: shareText));
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(tr('copied_to_clipboard')),
  //             duration: const Duration(seconds: 2),
  //             action: SnackBarAction(label: tr('ok'), onPressed: () {}),
  //           ),
  //         );
  //       }
  //     } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(tr('share_error')),
  //             duration: const Duration(seconds: 2),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  // void _handleBookmark() {
  //   setState(() {
  //     _isBookmarked = !_isBookmarked;
  //   });
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         _isBookmarked
  //             ? tr('added_to_bookmarks')
  //             : tr('removed_from_bookmarks'),
  //       ),
  //       duration: const Duration(seconds: 2),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildLoadingScreen(theme);
    }

    if (_error != null || _decade == null) {
      return _buildErrorScreen(theme);
    }

    final categoryInfo = RosaryConstants.getCategoryInfo(widget.category);
    final categoryColor = RosaryConstants.hexToColor(categoryInfo.color);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              categoryColor.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              categoryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(theme, categoryInfo, categoryColor),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Univerzálny audio widget
                  if (_decade!.hasAudio)
                    UniversalAudioPlayer.rosary(
                      audioUrl: _decade?.audioRecording,
                      title: _decade!.title,
                      author: _decade!.author ?? 'Neznámy autor',
                      albumName: categoryInfo.name,
                      artworkUrl: _decade!.hasImage
                          ? _decade!.illustrationImage
                          : null,
                      id: '${widget.category.name}_${widget.decadeOrder}',
                      categoryColor: categoryColor,
                      audioPlayer: _audioPlayer,
                      config: AudioPlayerConfig.rosary.copyWith(
                        showTitle: false,
                        showAuthor: true,
                      ),
                    ),

                  // Existujúci obsah
                  Column(
                    children: [
                      _buildBiblicalText(theme, categoryColor),
                      _buildIntroduction(theme, categoryColor),
                      _buildLectioDivinaSections(theme, categoryColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: _buildNavigationButtons(theme, categoryColor),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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

  Widget _buildLoadingScreen(ThemeData theme) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                  strokeWidth: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  tr('loading_mystery'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr('preparing_spiritual_journey'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(ThemeData theme) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(tr('mystery_not_found'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                tr('mystery_not_found'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error ?? tr('requested_mystery_not_found'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(tr('back_to_category')),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _loadDecade,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr('try_again')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
    ThemeData theme,
    RosaryCategoryInfo categoryInfo,
    Color categoryColor,
  ) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return SliverAppBar(
      expandedHeight: isTablet ? 450.0 : 300.0,
      floating: false,
      pinned: true,
      backgroundColor: categoryColor,
      foregroundColor: Colors.white,
      title: Text(
        _decade!.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_decade!.hasImage)
              CachedNetworkImage(
                imageUrl: _decade!.illustrationImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: categoryColor),
                errorWidget: (context, url, error) =>
                    Container(color: categoryColor),
              )
            else
              Container(color: categoryColor),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    categoryColor.withValues(alpha: 0.5),
                    categoryColor.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(
                  isTablet ? AppSpacing.xxl * 1.5 : AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        isTablet ? AppSpacing.xl : AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Icon(
                        categoryInfo.icon,
                        size: isTablet ? 64 : 48,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isTablet ? AppSpacing.xl : AppSpacing.lg),
                    Text(
                      _decade!.title,
                      style:
                          (isTablet
                                  ? theme.textTheme.headlineLarge
                                  : theme.textTheme.headlineMedium)
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isTablet ? AppSpacing.md : AppSpacing.sm),
                    Text(
                      '${categoryInfo.name} · ${widget.decadeOrder}/5',
                      style:
                          (isTablet
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

  // TODO: záložka a zdieľať - zatiaľ zakomentované
  // Widget _buildActionButtons(ThemeData theme, Color categoryColor) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //     children: [
  //       OutlinedButton.icon(
  //         onPressed: _handleBookmark,
  //         icon: Icon(
  //           _isBookmarked
  //               ? Icons.bookmark_rounded
  //               : Icons.bookmark_border_rounded,
  //         ),
  //         label: Text(tr('bookmark')),
  //         style: OutlinedButton.styleFrom(
  //           foregroundColor: categoryColor,
  //           side: BorderSide(color: categoryColor),
  //         ),
  //       ),
  //       OutlinedButton.icon(
  //         onPressed: _handleShare,
  //         icon: const Icon(Icons.share_rounded),
  //         label: Text(tr('share')),
  //         style: OutlinedButton.styleFrom(
  //           foregroundColor: categoryColor,
  //           side: BorderSide(color: categoryColor),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildBiblicalText(ThemeData theme, Color categoryColor) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
        elevation: AppElevation.medium,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('gods_word'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: _decade!.biblicalText,
                style: {
                  "body": Style(
                    lineHeight: const LineHeight(1.6),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme, Color categoryColor) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
        elevation: AppElevation.medium,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('mystery_introduction'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: _decade!.introduction,
                style: {
                  "body": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectioDivinaSections(ThemeData theme, Color categoryColor) {
    final sections = <String, String>{
      if (_decade!.lectioText?.isNotEmpty == true)
        'lectio_text': _decade!.lectioText!,
      if (_decade!.meditatioText?.isNotEmpty == true)
        'meditatio_text': _decade!.meditatioText!,
      if (_decade!.oratioHtml?.isNotEmpty == true)
        'oratio_html': _decade!.oratioHtml!,
      if (_decade!.contemplatioText?.isNotEmpty == true)
        'contemplatio_text': _decade!.contemplatioText!,
      if (_decade!.actioText?.isNotEmpty == true)
        'actio_text': _decade!.actioText!,
    };

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sections.entries.map((entry) {
        final sectionInfo = _getSectionInfo(entry.key);
        return _buildSection(theme, sectionInfo, entry.value);
      }).toList(),
    );
  }

  Map<String, dynamic> _getSectionInfo(String key) {
    final lectioDivinaSteps = {
      'lectio_text': {
        'name': 'Lectio',
        'subtitle': _decade!.author?.isNotEmpty == true
            ? _decade!.author!
            : tr('reading'),
        'color': '#4A5085',
      },
      'meditatio_text': {
        'name': 'Meditatio',
        'subtitle': tr('meditation'),
        'color': '#4A5085',
      },
      'oratio_html': {
        'name': 'Oratio',
        'subtitle': tr('prayer'),
        'color': '#4A5085',
      },
      'contemplatio_text': {
        'name': 'Contemplatio',
        'subtitle': tr('contemplation'),
        'color': '#4A5085',
      },
      'silencio_text': {
        'name': 'Silencio',
        'subtitle': tr('silence'),
        'color': '#4A5085',
      },
      'actio_text': {
        'name': 'Actio',
        'subtitle': tr('action'),
        'color': '#4A5085',
      },
    };

    return lectioDivinaSteps[key] ??
        {'name': key, 'subtitle': '', 'color': '#666666'};
  }

  Widget _buildSection(
    ThemeData theme,
    Map<String, dynamic> sectionInfo,
    String content,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
        elevation: AppElevation.medium,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionInfo['name'],
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (sectionInfo['subtitle'].isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  sectionInfo['subtitle'],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: content,
                style: {
                  "body": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, Color categoryColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous button
          _buildNavButton(
            icon: Icons.arrow_back_rounded,
            isEnabled: _navigation?.canGoToPrevious == true,
            onPressed: _handlePreviousDecade,
            categoryColor: categoryColor,
            theme: theme,
          ),

          // All mysteries button
          _buildNavButton(
            icon: Icons.list_rounded,
            isEnabled: true,
            onPressed: () => Navigator.of(context).pop(),
            categoryColor: categoryColor,
            theme: theme,
          ),

          // Next button
          _buildNavButton(
            icon: Icons.arrow_forward_rounded,
            isEnabled: _navigation?.canGoToNext == true,
            onPressed: _handleNextDecade,
            categoryColor: categoryColor,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback? onPressed,
    required Color categoryColor,
    required ThemeData theme,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEnabled
            ? categoryColor.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: isEnabled
              ? categoryColor
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: 20),
        color: isEnabled
            ? categoryColor
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

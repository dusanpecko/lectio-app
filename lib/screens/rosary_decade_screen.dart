// lib/screens/rosary_decade_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../shared/rosary_constants.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';

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
  bool _isBookmarked = false;

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

  void _handleShare() async {
    if (_decade != null) {
      final categoryInfo = RosaryConstants.getCategoryInfo(widget.category);
      final shareText =
          '${categoryInfo.name} - ${_decade!.title}\n\n${_decade!.introduction}';

      try {
        await Clipboard.setData(ClipboardData(text: shareText));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('copied_to_clipboard')),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(label: tr('ok'), onPressed: () {}),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('share_error')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _handleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked
              ? tr('added_to_bookmarks')
              : tr('removed_from_bookmarks'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildActionButtons(theme, categoryColor),
                        const SizedBox(height: 20),
                        _buildMainContent(theme, categoryColor),
                        const SizedBox(height: 20),
                        _buildNavigationButtons(theme, categoryColor),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildLoadingScreen(ThemeData theme) {
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 20),
                Text(
                  tr('loading_mystery'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(tr('mystery_not_found'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                tr('mystery_not_found'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? tr('requested_mystery_not_found'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(tr('back_to_category')),
                  ),
                  const SizedBox(width: 16),
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
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: categoryColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _decade!.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [categoryColor, categoryColor.withValues(alpha: 0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              if (_decade!.hasImage)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: _decade!.illustrationImage!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        categoryColor.withValues(alpha: 0.7),
                        categoryColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                right: 20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.decadeOrder}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, Color categoryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          onPressed: _handleBookmark,
          icon: Icon(
            _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
          ),
          label: Text(tr('bookmark')),
          style: OutlinedButton.styleFrom(
            foregroundColor: categoryColor,
            side: BorderSide(color: categoryColor),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _handleShare,
          icon: const Icon(Icons.share_rounded),
          label: Text(tr('share')),
          style: OutlinedButton.styleFrom(
            foregroundColor: categoryColor,
            side: BorderSide(color: categoryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(ThemeData theme, Color categoryColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBiblicalText(theme, categoryColor),
          _buildIntroduction(theme, categoryColor),
          _buildLectioDivinaSections(theme, categoryColor),
          _buildMetadata(theme),
        ],
      ),
    );
  }

  Widget _buildBiblicalText(ThemeData theme, Color categoryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.1),
            categoryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(left: BorderSide(color: categoryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book_rounded, color: categoryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                tr('gods_word'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Html(
            data: _decade!.biblicalText,
            style: {
              "body": Style(
                fontSize: FontSize(18),
                lineHeight: const LineHeight(1.6),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme, Color categoryColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor,
                      categoryColor.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                tr('mystery_introduction'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Html(
            data: _decade!.introduction,
            style: {
              "body": Style(
                fontSize: FontSize(16),
                lineHeight: const LineHeight(1.6),
                color: theme.colorScheme.onSurface,
              ),
            },
          ),
        ],
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
        'subtitle': tr('reading'),
        'color': '#4CAF50',
      },
      'meditatio_text': {
        'name': 'Meditatio',
        'subtitle': tr('meditation'),
        'color': '#FF9800',
      },
      'oratio_html': {
        'name': 'Oratio',
        'subtitle': tr('prayer'),
        'color': '#9C27B0',
      },
      'contemplatio_text': {
        'name': 'Contemplatio',
        'subtitle': tr('contemplation'),
        'color': '#2196F3',
      },
      'actio_text': {
        'name': 'Actio',
        'subtitle': tr('action'),
        'color': '#F44336',
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
    final sectionColor = RosaryConstants.hexToColor(sectionInfo['color']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [sectionColor, sectionColor.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionInfo['name'],
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: sectionColor,
                    ),
                  ),
                  if (sectionInfo['subtitle'].isNotEmpty)
                    Text(
                      sectionInfo['subtitle'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Html(
            data: content,
            style: {
              "body": Style(
                fontSize: FontSize(16),
                lineHeight: const LineHeight(1.6),
                color: theme.colorScheme.onSurface,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          if (_decade!.author?.isNotEmpty == true) ...[
            Icon(
              Icons.person_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              _decade!.author!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('d.M.yyyy').format(_decade!.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '~${RosaryConstants.averageDecadeMinutes} min',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, Color categoryColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

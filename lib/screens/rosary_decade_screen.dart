// lib/screens/rosary_decade_screen.dart

import 'dart:async';
import '../services/audio_exclusive.dart';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_colors.dart';
import '../shared/rosary_constants.dart';
import '../widgets/collapsible_hero_app_bar.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../shared/audio_player_factory.dart';

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
  final AudioPlayer _audioPlayer = createAppAudioPlayer();

  RosaryDecade? _decade;
  RosaryNavigation? _navigation;
  bool _isLoading = true;
  String? _error;
  Timer? _heartbeatTimer;
  StreamSubscription<PlayerState>? _playerStateSub;
  // bool _isBookmarked = false; // TODO: záložka - zatiaľ zakomentované

  @override
  void initState() {
    super.initState();
    _setupHeartbeat();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _playerStateSub?.cancel();
    AudioExclusive.release(_audioPlayer);
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupHeartbeat() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      if (playing) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
    });
  }

  void _startHeartbeat() {
    if (_heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lang = context.locale.languageCode;
      UmamiAnalyticsService().trackEvent(
        'audio_heartbeat',
        eventData: {
          'content_type': 'rosary',
          'content_id':
              '${widget.category.name}_${widget.decadeOrder}',
          'language': lang,
          'position_seconds': _audioPlayer.position.inSeconds,
        },
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
      backgroundColor: HomeV2.background(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              categoryColor.withValues(alpha: 0.1),
              HomeV2.background(context),
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
                      SizedBox(
                        height:
                            AppSpacing.xl +
                            MediaQuery.of(context).viewPadding.bottom,
                      ),
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
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(HomeV2.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              tr('loading_mystery'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: HomeV2.textDark(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('preparing_spiritual_journey'),
              style: TextStyle(color: HomeV2.textMuted(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(ThemeData theme) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.sm, topPad + AppSpacing.sm, AppSpacing.sm, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC0392B).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded,
                          size: 52, color: Color(0xFFC0392B)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      tr('mystery_not_found'),
                      style: HomeV2.serifTitle(context, size: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error ?? tr('requested_mystery_not_found'),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: HomeV2.textMuted(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(tr('back_to_category')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HomeV2.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        TextButton.icon(
                          onPressed: _loadDecade,
                          icon:
                              Icon(Icons.refresh_rounded, color: HomeV2.primary),
                          label: Text(
                            tr('try_again'),
                            style: TextStyle(
                                color: HomeV2.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    ThemeData theme,
    RosaryCategoryInfo categoryInfo,
    Color categoryColor,
  ) {
    // Jednotný zbaliteľný hero (vzor krížové cesty) — CollapsibleHeroAppBar.
    return CollapsibleHeroAppBar(
      collapsedTitle: _decade!.title,
      imageUrl: _decade!.hasImage ? _decade!.illustrationImage : null,
      accentColor: categoryColor,
      expandedContent: HeroCenteredContent(
        title: _decade!.title,
        subtitle: _decade!.author,
        icon: categoryInfo.icon,
      ),
    );
  }

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
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

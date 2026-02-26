// lib/screens/stations_of_cross_detail_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import '../models/stations_of_cross_model.dart';
import '../services/stations_of_cross_service.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';

class StationsOfCrossDetailScreen extends StatefulWidget {
  final String stationsOfCrossId;
  final StationsOfCross? initialData;

  const StationsOfCrossDetailScreen({
    super.key,
    required this.stationsOfCrossId,
    this.initialData,
  });

  @override
  State<StationsOfCrossDetailScreen> createState() =>
      _StationsOfCrossDetailScreenState();
}

class _StationsOfCrossDetailScreenState
    extends State<StationsOfCrossDetailScreen> {
  final StationsOfCrossService _service = StationsOfCrossService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StationsOfCross? _data;
  bool _isLoading = true;
  String? _error;
  StationsOfCross? _nextItem;
  StationsOfCross? _previousItem;

  // Track which stations are expanded
  final Set<int> _expandedStations = {};

  // Colors for Stations of the Cross theme
  static const Color _stationsColor = Color(0xFF5C1018);
  static const Color _stationsColorLight = Color(0xFF8B2030);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = context.locale.languageCode;

      // Always load full detail (with all station content)
      final detail =
          await _service.getStationsOfCrossDetail(widget.stationsOfCrossId);
      if (detail == null) {
        throw Exception(tr('stations_not_found'));
      }

      // Load navigation (next/previous)
      final next = await _service.getNext(detail.order, lang);
      final previous = await _service.getPrevious(detail.order, lang);

      if (mounted) {
        setState(() {
          _data = detail;
          _nextItem = next;
          _previousItem = previous;
          _isLoading = false;
          // Expand intro by default
          if (detail.stations.isNotEmpty) {
            _expandedStations.add(0);
          }
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

  void _navigateToItem(String id, StationsOfCross item) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => StationsOfCrossDetailScreen(
          stationsOfCrossId: id,
          initialData: item,
        ),
      ),
    );
  }

  void _toggleStation(int index) {
    setState(() {
      if (_expandedStations.contains(index)) {
        _expandedStations.remove(index);
      } else {
        _expandedStations.add(index);
      }
    });
  }

  void _expandAll() {
    setState(() {
      for (int i = 0; i < (_data?.stations.length ?? 0); i++) {
        _expandedStations.add(i);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedStations.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildLoadingScreen(theme);
    }

    if (_error != null || _data == null) {
      return _buildErrorScreen(theme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _stationsColor.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(theme),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Expand/Collapse All buttons
                  if (_data!.stations.length > 1) _buildExpandCollapseBar(theme),

                  // Stations list
                  ..._data!.stations.asMap().entries.map(
                        (entry) => _buildStationCard(theme, entry.value, entry.key),
                      ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: _buildNavigationButtons(theme),
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
              _stationsColor.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              AppColors.primary.withValues(alpha: 0.1),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_stationsColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  tr('loading'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr('stations_of_cross_loading_detail'),
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
      appBar: AppBar(title: Text(tr('stations_not_found'))),
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
                tr('stations_not_found'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error ?? tr('error_loading'),
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
                    label: Text(tr('back_to_list')),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _loadDetail,
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

  Widget _buildAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight:
          MediaQuery.of(context).size.width >= 600 ? 450.0 : 300.0,
      floating: false,
      pinned: true,
      backgroundColor: _stationsColor,
      foregroundColor: Colors.white,
      title: Text(
        _data!.title,
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
            if (_data!.hasImage)
              CachedNetworkImage(
                imageUrl: _data!.illustrationImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: _stationsColor),
                errorWidget: (context, url, error) =>
                    Container(color: _stationsColor),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _stationsColor,
                      AppColors.primary,
                      const Color(0xFF2D1B4E),
                    ],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _stationsColor.withValues(alpha: 0.5),
                    _stationsColor.withValues(alpha: 0.85),
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
                        Icons.add_rounded,
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
                      _data!.title,
                      style: (MediaQuery.of(context).size.width >= 600
                              ? theme.textTheme.headlineLarge
                              : theme.textTheme.headlineMedium)
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_data!.author?.isNotEmpty == true) ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.width >= 600
                            ? AppSpacing.md
                            : AppSpacing.sm,
                      ),
                      Text(
                        _data!.author!,
                        style: (MediaQuery.of(context).size.width >= 600
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_data!.subtitle?.isNotEmpty == true) ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.width >= 600
                            ? AppSpacing.sm
                            : AppSpacing.xs,
                      ),
                      Text(
                        _data!.subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandCollapseBar(ThemeData theme) {
    final allExpanded =
        _expandedStations.length == (_data?.stations.length ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: allExpanded ? _collapseAll : _expandAll,
            icon: Icon(
              allExpanded
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              size: 18,
              color: _stationsColor,
            ),
            label: Text(
              allExpanded
                  ? tr('stations_collapse_all')
                  : tr('stations_expand_all'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _stationsColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(ThemeData theme, Station station, int index) {
    final isExpanded = _expandedStations.contains(index);

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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station header (always visible, tappable)
            _buildStationHeader(theme, station, index, isExpanded),

            // Station content (expanded)
            if (isExpanded) ...[
              // Image
              if (station.hasImage) _buildStationImage(theme, station),

              // HTML content
              if (station.hasText) _buildStationContent(theme, station),

              // Audio player
              if (station.hasAudio) _buildStationAudio(theme, station),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationHeader(
    ThemeData theme,
    Station station,
    int index,
    bool isExpanded,
  ) {
    // Determine header color based on type
    Color headerColor;
    IconData headerIcon;
    String headerLabel;

    if (station.isIntro) {
      headerColor = _stationsColor;
      headerIcon = Icons.play_arrow_rounded;
      headerLabel = station.title.isNotEmpty
          ? station.title
          : tr('station_intro');
    } else if (station.isConclusion) {
      headerColor = _stationsColor;
      headerIcon = Icons.stop_rounded;
      headerLabel = station.title.isNotEmpty
          ? station.title
          : tr('station_conclusion');
    } else {
      headerColor = _stationsColorLight;
      headerIcon = Icons.add_rounded;
      final roman = station.romanNumeral;
      headerLabel = station.title.isNotEmpty
          ? '$roman. ${station.title}'
          : '${tr('station_number')} $roman';
    }

    return InkWell(
      onTap: () => _toggleStation(index),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isExpanded
              ? headerColor.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: headerColor,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // Station number badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: station.isStation
                    ? Text(
                        station.romanNumeral,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      )
                    : Icon(
                        headerIcon,
                        size: 20,
                        color: headerColor,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isExpanded
                          ? headerColor
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Indicator badges
                  if (!isExpanded) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (station.hasText)
                          _buildMiniIndicator(
                            Icons.text_fields_rounded,
                            theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        if (station.hasImage)
                          _buildMiniIndicator(
                            Icons.image_rounded,
                            theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        if (station.hasAudio)
                          _buildMiniIndicator(
                            Icons.headphones_rounded,
                            AppColors.accent.withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Expand/collapse icon
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniIndicator(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildStationImage(ThemeData theme, Station station) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CachedNetworkImage(
          imageUrl: station.image!,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: _stationsColor.withValues(alpha: 0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildStationContent(ThemeData theme, Station station) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Html(
        data: station.content,
        style: {
          "body": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "p": Style(
            lineHeight: const LineHeight(1.6),
            color: theme.colorScheme.onSurface,
            margin: Margins.only(top: 0, bottom: 4),
          ),
          "div": Style(
            lineHeight: const LineHeight(1.6),
            color: theme.colorScheme.onSurface,
            margin: Margins.zero,
          ),
          "strong": Style(
            fontWeight: FontWeight.bold,
            color: _stationsColor,
          ),
          "em": Style(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          "hr": Style(
            margin: Margins.only(top: 8, bottom: 8),
            border: const Border(
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
        },
      ),
    );
  }

  Widget _buildStationAudio(ThemeData theme, Station station) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: UniversalAudioPlayer.rosary(
        audioUrl: station.audio,
        title: station.title.isNotEmpty
            ? station.title
            : '${tr('station_number')} ${station.romanNumeral}',
        author: _data?.author ?? tr('unknown_author'),
        albumName: _data?.title ?? tr('stations_of_cross_title'),
        artworkUrl: station.hasImage
            ? station.image
            : (_data?.hasImage == true ? _data!.illustrationImage : null),
        id: 'station_${station.id}',
        categoryColor: _stationsColor,
        audioPlayer: _audioPlayer,
        config: AudioPlayerConfig.rosary.copyWith(
          showTitle: false,
          showAuthor: true,
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    final hasPrevious = _previousItem != null;
    final hasNext = _nextItem != null;

    if (!hasPrevious && !hasNext) {
      return const SizedBox.shrink();
    }

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          if (hasPrevious)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToItem(
                  _previousItem!.id,
                  _previousItem!,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  tr('previous'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _stationsColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          if (hasPrevious && hasNext) const SizedBox(width: AppSpacing.md),

          // Next Button
          if (hasNext)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _navigateToItem(_nextItem!.id, _nextItem!),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  tr('next'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

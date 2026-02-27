// lib/screens/stations_of_cross_detail_screen.dart

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stations_of_cross_model.dart';
import '../services/stations_of_cross_service.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_constants.dart';
import '../widgets/lectio_floating_audio_player.dart';

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

// ── Audio constants ──
const _kStationsMusicUrl1 =
    'https://core.lectio.one/storage/v1/object/public/rosary/lectio-divina-audios/freepik-dramatic-signals.mp3';
const _kStationsMusicUrl2 =
    'https://core.lectio.one/storage/v1/object/public/rosary/lectio-divina-audios/audio_krizova_cesta.mp3';
const _kPrefKeyStationsAudioMode = 'stations_of_cross_audio_mode';

class _StationsOfCrossDetailScreenState
    extends State<StationsOfCrossDetailScreen> {
  final StationsOfCrossService _service = StationsOfCrossService();

  StationsOfCross? _data;
  bool _isLoading = true;
  String? _error;

  late PageController _pageController;
  int _currentPage = 0;

  // ── Audio (lectio-style floating player) ──
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showAudioPlayer = false;
  bool _isMinimized = false;
  bool _isPlaying = false;
  bool _isPlayingInterlude = false;
  String? _currentAudioSection; // e.g. 'station_0', 'station_1'
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  // 'none' = no music, 'short' = music 1, 'long' = music 2
  String _audioMode = 'short';

  late PageController _playlistPageController;
  List<Map<String, dynamic>> _tracks = [];
  // Maps native source index → {type: 'track'|'interlude', trackIndex: int}
  List<Map<String, dynamic>> _sourceMap = [];

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<int?>? _indexSub;

  /// Artwork URI for lock screen / notification
  Uri? get _artUri {
    final img = _data?.illustrationImage;
    if (img != null && img.isNotEmpty) return Uri.tryParse(img);
    return Uri.parse(AudioConstants.defaultArtworkUrl);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _playlistPageController = PageController(viewportFraction: 0.85);
    if (widget.initialData != null) {
      _data = widget.initialData;
      _isLoading = false;
    }
    _setupAudioListeners();
    _restoreAudioMode();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _indexSub?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    _playlistPageController.dispose();
    super.dispose();
  }

  // ── Audio setup ──

  void _setupAudioListeners() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final isComplete = state.processingState == ProcessingState.completed;
      setState(() {
        _isPlaying = state.playing && !isComplete;
      });
    });

    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _totalDuration = dur ?? Duration.zero);
    });

    // Track which native source is playing → update station & interlude state
    _indexSub = _audioPlayer.currentIndexStream.listen((nativeIdx) {
      if (!mounted || nativeIdx == null) return;
      if (nativeIdx < 0 || nativeIdx >= _sourceMap.length) return;

      final entry = _sourceMap[nativeIdx];
      final trackIdx = entry['trackIndex'] as int;
      final isInterlude = entry['type'] == 'interlude';

      setState(() {
        _isPlayingInterlude = isInterlude;
        _currentAudioSection = 'station_$trackIdx';
      });

      // Sync PageView + playlist carousel to the current station
      if (trackIdx != _currentPage) {
        _pageController.animateToPage(
          trackIdx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (_playlistPageController.hasClients) {
        _playlistPageController.animateToPage(
          trackIdx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _restoreAudioMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKeyStationsAudioMode);
    if (saved != null && mounted) {
      setState(() => _audioMode = saved);
    }
  }

  Future<void> _saveAudioMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKeyStationsAudioMode, mode);
    if (mounted) setState(() => _audioMode = mode);

    if (mode == 'none') {
      await _audioPlayer.stop();
    } else if (_showAudioPlayer) {
      // Rebuild playlist with new interlude music & start playing
      await _buildAndPlayPlaylist(fromStation: _currentPage);
    }
  }

  String _getInterludeUrl() {
    switch (_audioMode) {
      case 'short':
        return _kStationsMusicUrl1;
      case 'long':
        return _kStationsMusicUrl2;
      default:
        return '';
    }
  }

  /// Build ConcatenatingAudioSource from stations + interludes and start
  Future<void> _buildAndPlayPlaylist({int fromStation = 0}) async {
    if (_data == null) return;
    final stations = _data!.stations;
    final interludeUrl = _getInterludeUrl();

    final sources = <AudioSource>[];
    _sourceMap = [];

    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      if (!station.hasAudio) continue;

      // Station audio
      final stationLabel = _tracks.length > i
          ? (_tracks[i]['label'] as String? ?? 'Zastavenie')
          : 'Zastavenie';
      sources.add(
        AudioSource.uri(
          Uri.parse(station.audio!),
          tag: MediaItem(
            id: 'station_$i',
            album: 'Krížová cesta',
            title: stationLabel,
            artist: _data?.author ?? 'Krížová cesta',
            artUri: _artUri,
          ),
        ),
      );
      _sourceMap.add({'type': 'track', 'trackIndex': i});

      // Interlude after this station (if mode != none)
      if (interludeUrl.isNotEmpty) {
        sources.add(
          AudioSource.uri(
            Uri.parse(interludeUrl),
            tag: MediaItem(
              id: 'interlude_$i',
              album: 'Krížová cesta',
              title: 'Meditačná hudba',
              artist: 'MudiG',
              artUri: _artUri,
            ),
          ),
        );
        _sourceMap.add({'type': 'interlude', 'trackIndex': i});
      }
    }

    if (sources.isEmpty) {
      debugPrint('No station audio sources available');
      return;
    }

    try {
      await _audioPlayer.stop();
      final playlist = ConcatenatingAudioSource(children: sources);
      await _audioPlayer.setAudioSource(playlist);

      // Seek to the requested station
      if (fromStation > 0) {
        final nativeIdx = _sourceMap.indexWhere(
          (e) => e['type'] == 'track' && e['trackIndex'] == fromStation,
        );
        if (nativeIdx >= 0) {
          await _audioPlayer.seek(Duration.zero, index: nativeIdx);
        }
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error building stations playlist: $e');
    }
  }

  void _onPlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle ||
          _audioPlayer.processingState == ProcessingState.completed) {
        _buildAndPlayPlaylist(fromStation: _currentPage);
      } else {
        _audioPlayer.play();
      }
    }
  }

  void _onSkipNext() {
    if (_data == null) return;
    // Find next track (not interlude) after current native index
    final currentNative = _audioPlayer.currentIndex ?? 0;
    for (int i = currentNative + 1; i < _sourceMap.length; i++) {
      if (_sourceMap[i]['type'] == 'track') {
        _audioPlayer.seek(Duration.zero, index: i);
        return;
      }
    }
    // Fallback: scroll page
    final max = _data!.stations.length - 1;
    if (_currentPage < max) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSkipPrevious() {
    if (_data == null) return;
    final currentNative = _audioPlayer.currentIndex ?? 0;
    for (int i = currentNative - 1; i >= 0; i--) {
      if (_sourceMap[i]['type'] == 'track') {
        _audioPlayer.seek(Duration.zero, index: i);
        return;
      }
    }
    // Fallback: scroll page
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      if (_showAudioPlayer) {
        _currentAudioSection = 'station_$index';
      }
    });
    if (_showAudioPlayer && _playlistPageController.hasClients) {
      _playlistPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _buildTracks() {
    if (_data == null) return;
    _tracks = List.generate(_data!.stations.length, (i) {
      final station = _data!.stations[i];
      final String label;
      final IconData icon;

      if (station.isIntro) {
        label = tr('station_intro');
        icon = Icons.play_circle_outline;
      } else if (station.isConclusion) {
        label = tr('station_conclusion');
        icon = Icons.flag_outlined;
      } else {
        label = station.title.isNotEmpty
            ? station.title
            : '${tr('station_number')} ${station.romanNumeral}';
        icon = Icons.church_outlined;
      }

      return <String, dynamic>{
        'key': 'station_$i',
        'label': label,
        'url': station.audio ?? '',
        'icon': icon,
        'color': AppColors.primary,
      };
    });
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
      final detail = await _service.getStationsOfCrossDetail(
        widget.stationsOfCrossId,
      );
      if (detail == null) {
        throw Exception(tr('stations_not_found'));
      }

      if (mounted) {
        setState(() {
          _data = detail;
          _isLoading = false;
        });
        _buildTracks();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return _buildLoadingScreen(theme);
    if (_error != null || _data == null) return _buildErrorScreen(theme);

    final stations = _data!.stations;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: stations.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildStationPage(theme, stations[index], index);
            },
          ),
          // Lectio-style floating audio player
          if (_showAudioPlayer && _tracks.isNotEmpty)
            LectioFloatingAudioPlayer(
              tracks: _tracks,
              currentAudioSection: _currentAudioSection,
              isPlaying: _isPlaying,
              isPlayingInterlude: _isPlayingInterlude,
              isMinimized: _isMinimized,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              audioMode: _audioMode,
              playlistPageController: _playlistPageController,
              onPlayPause: _onPlayPause,
              onSkipPrevious: _currentPage > 0 ? _onSkipPrevious : null,
              onSkipNext: _currentPage < stations.length - 1
                  ? _onSkipNext
                  : null,
              onSeekStart: () {},
              onSeekChanged: (pos) {
                setState(() => _currentPosition = pos);
              },
              onSeekEnd: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
              onPlayTrack: (url, key) {
                // Find station index from key
                final idx = _tracks.indexWhere((t) => t['key'] == key);
                if (idx >= 0) {
                  // If playlist is active, seek to that track's native index
                  final nativeIdx = _sourceMap.indexWhere(
                    (e) => e['type'] == 'track' && e['trackIndex'] == idx,
                  );
                  if (nativeIdx >= 0 &&
                      _audioPlayer.processingState != ProcessingState.idle) {
                    _audioPlayer.seek(Duration.zero, index: nativeIdx);
                  } else {
                    _buildAndPlayPlaylist(fromStation: idx);
                  }
                }
              },
              onAudioModeChanged: _saveAudioMode,
              onMinimize: () {
                setState(() => _isMinimized = !_isMinimized);
              },
              onClose: () async {
                await _audioPlayer.stop();
                if (mounted) {
                  setState(() {
                    _showAudioPlayer = false;
                    _isPlaying = false;
                    _currentAudioSection = null;
                  });
                }
              },
            ),
          // FAB to open player when closed
          if (!_showAudioPlayer)
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.xxl,
              child: FloatingActionButton(
                heroTag: 'stations_open_player',
                backgroundColor: AppColors.primary,
                onPressed: () {
                  setState(() {
                    _showAudioPlayer = true;
                    _currentAudioSection = 'station_$_currentPage';
                  });
                  _buildAndPlayPlaylist(fromStation: _currentPage);
                },
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStationPage(ThemeData theme, Station station, int index) {
    return _StationPageView(
      station: station,
      data: _data!,
      pageController: _pageController,
      currentPage: _currentPage,
      onPageDotTap: (i) => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              tr('stations_of_cross_loading_detail'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
}

// ---------------------------------------------------------------------------
// _StationPageView — one page inside the PageView with collapsible hero
// ---------------------------------------------------------------------------
class _StationPageView extends StatefulWidget {
  final Station station;
  final StationsOfCross data;
  final PageController pageController;
  final int currentPage;
  final void Function(int) onPageDotTap;

  const _StationPageView({
    required this.station,
    required this.data,
    required this.pageController,
    required this.currentPage,
    required this.onPageDotTap,
  });

  @override
  State<_StationPageView> createState() => _StationPageViewState();
}

class _StationPageViewState extends State<_StationPageView> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final expandedHeight = isTablet ? 450.0 : 300.0;
    final collapsed =
        _scrollController.hasClients &&
        _scrollController.offset > expandedHeight - kToolbarHeight;
    if (collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  Widget _buildDotIndicators(ThemeData theme, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) {
                  final isActive = i == widget.currentPage;
                  return GestureDetector(
                    onTap: () => widget.onPageDotTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final station = widget.station;

    final heroImage = station.hasImage
        ? station.image
        : (widget.data.hasImage ? widget.data.illustrationImage : null);
    final heroFallbackAsset = 'assets/images/station_cross_backround.webp';

    final String stationLabel;
    if (station.isIntro) {
      stationLabel = tr('station_intro');
    } else if (station.isConclusion) {
      stationLabel = tr('station_conclusion');
    } else {
      stationLabel = station.title.isNotEmpty
          ? station.title
          : '${tr('station_number')} ${station.romanNumeral}';
    }

    final content = station.content;
    final hasBlockTags = RegExp(
      r'<(p|div|br|h[1-6]|ul|ol|li)',
      caseSensitive: false,
    ).hasMatch(content);
    final processedContent = hasBlockTags
        ? content
        : content.replaceAll('\n', '<br>');

    final baseFontSize = theme.textTheme.bodyLarge?.fontSize ?? 16.0;
    final labelFontSize = baseFontSize * 1.4;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: isTablet ? 450.0 : 300.0,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: AnimatedOpacity(
            opacity: _isCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              stationLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          actions: [
            if (station.isStation)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: Text(
                    station.romanNumeral,
                    style: TextStyle(
                      fontSize: isTablet ? 48 : 36,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (heroImage != null)
                  CachedNetworkImage(
                    imageUrl: heroImage,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.primary),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.primary),
                  )
                else
                  Image.asset(heroFallbackAsset, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                if (station.isIntro)
                  Positioned(
                    left: AppSpacing.xxl,
                    right: AppSpacing.xxl,
                    bottom: AppSpacing.lg,
                    child: Text(
                      widget.data.title,
                      style:
                          (isTablet
                                  ? theme.textTheme.headlineLarge
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.data.stations.length > 1)
          SliverToBoxAdapter(
            child: _buildDotIndicators(theme, widget.data.stations.length),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Text(
              stationLabel,
              style: TextStyle(
                fontSize: labelFontSize,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 120,
          ),
          sliver: SliverToBoxAdapter(
            child: station.hasText
                ? Html(
                    data: processedContent,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                      "p": Style(
                        lineHeight: const LineHeight(1.6),
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize(
                          theme.textTheme.bodyLarge?.fontSize ?? 16,
                        ),
                        margin: Margins.only(top: 0, bottom: 12),
                        textAlign: TextAlign.justify,
                      ),
                      "div": Style(
                        lineHeight: const LineHeight(1.6),
                        color: theme.colorScheme.onSurface,
                        margin: Margins.only(top: 0, bottom: 4),
                      ),
                      "br": Style(lineHeight: const LineHeight(1.6)),
                      "strong": Style(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      "em": Style(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      "ul": Style(
                        margin: Margins.only(top: 4, bottom: 12),
                        padding: HtmlPaddings.only(left: 16),
                      ),
                      "ol": Style(
                        margin: Margins.only(top: 4, bottom: 12),
                        padding: HtmlPaddings.only(left: 16),
                      ),
                      "li": Style(
                        lineHeight: const LineHeight(1.6),
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize(
                          theme.textTheme.bodyLarge?.fontSize ?? 16,
                        ),
                        margin: Margins.only(bottom: 4),
                      ),
                      "hr": Style(
                        margin: Margins.only(top: 12, bottom: 12),
                        border: const Border(
                          bottom: BorderSide(color: Colors.grey, width: 1),
                        ),
                      ),
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

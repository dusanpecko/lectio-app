// lib/screens/adoration_detail_screen.dart

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adoration_model.dart';
import '../services/adoration_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_colors.dart';
import '../shared/audio_constants.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/collapsible_hero_app_bar.dart';
import '../widgets/lectio_floating_audio_player.dart';
import '../shared/audio_player_factory.dart';

class AdorationDetailScreen extends StatefulWidget {
  final String adorationId;
  final Adoration? initialAdoration;

  const AdorationDetailScreen({
    super.key,
    required this.adorationId,
    this.initialAdoration,
  });

  @override
  State<AdorationDetailScreen> createState() => _AdorationDetailScreenState();
}

// ── Audio constants ──
const _kAdorationMusicUrl1 =
    'https://core.lectio.one/storage/v1/object/public/rosary/lectio-divina-audios/freepik-pure-beauty.mp3';
const _kAdorationMusicUrl2 =
    'https://core.lectio.one/storage/v1/object/public/rosary/lectio-divina-audios/freepik-seamlessly-loved.mp3';
const _kPrefKeyAdorationAudioMode = 'adoration_audio_mode';

class _AdorationDetailScreenState extends State<AdorationDetailScreen> {
  final AdorationService _adorationService = AdorationService();
  final AudioPlayer _audioPlayer = createAppAudioPlayer();

  Adoration? _adoration;
  bool _isLoading = true;
  String? _error;
  Adoration? _nextAdoration;
  Adoration? _previousAdoration;

  // ── Audio (lectio-style floating player) ──
  bool _showAudioPlayer = false;
  bool _isMinimized = false;
  bool _isPlaying = false;
  bool _isPlayingInterlude = false;
  String? _currentAudioSection;
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
  Timer? _heartbeatTimer;

  /// Artwork URI for lock screen / notification
  Uri? get _artUri {
    final img = _adoration?.illustrationImage;
    // Zmenši pre media notifikáciu (nenačítavaj plné rozlíšenie do pamäte).
    if (img != null && img.isNotEmpty) {
      return Uri.tryParse(AudioConstants.sizedArtwork(img)!);
    }
    return Uri.parse(AudioConstants.defaultArtworkUrl);
  }

  @override
  void initState() {
    super.initState();
    _playlistPageController = PageController(viewportFraction: 0.85);
    if (widget.initialAdoration != null) {
      _adoration = widget.initialAdoration;
      _isLoading = false;
    }
    _setupAudioListeners();
    _restoreAudioMode();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _indexSub?.cancel();
    _audioPlayer.dispose();
    _playlistPageController.dispose();
    super.dispose();
  }

  // ── Audio setup ──

  void _setupAudioListeners() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final isComplete = state.processingState == ProcessingState.completed;
      final playing = state.playing && !isComplete;
      setState(() {
        _isPlaying = playing;
      });
      if (playing) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
    });

    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _totalDuration = dur ?? Duration.zero);
    });

    _indexSub = _audioPlayer.currentIndexStream.listen((nativeIdx) {
      if (!mounted || nativeIdx == null) return;
      if (nativeIdx < 0 || nativeIdx >= _sourceMap.length) return;

      final entry = _sourceMap[nativeIdx];
      final trackIdx = entry['trackIndex'] as int;
      final isInterlude = entry['type'] == 'interlude';

      setState(() {
        _isPlayingInterlude = isInterlude;
        if (!isInterlude && trackIdx < _tracks.length) {
          _currentAudioSection = _tracks[trackIdx]['key'] as String;
        }
      });

      if (_playlistPageController.hasClients) {
        _playlistPageController.animateToPage(
          trackIdx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
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
          'content_type': 'adoration',
          'content_id': widget.adorationId,
          'language': lang,
          'position_seconds': _currentPosition.inSeconds,
        },
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _restoreAudioMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKeyAdorationAudioMode);
    if (saved != null && mounted) {
      setState(() => _audioMode = saved);
    }
  }

  Future<void> _saveAudioMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKeyAdorationAudioMode, mode);
    if (mounted) setState(() => _audioMode = mode);

    if (mode == 'none') {
      await _audioPlayer.stop();
    } else if (_showAudioPlayer) {
      await _buildAndPlayPlaylist();
    }
  }

  String _getInterludeUrl() {
    switch (_audioMode) {
      case 'short':
        return _kAdorationMusicUrl1;
      case 'long':
        return _kAdorationMusicUrl2;
      default:
        return '';
    }
  }

  void _buildTracks() {
    if (_adoration == null) return;
    final a = _adoration!;
    _tracks = [];

    // Build track list from available audio sections
    final sections = <Map<String, dynamic>>[
      if (a.introAudio?.isNotEmpty == true)
        {
          'key': 'intro',
          'label': tr('audio_intro'),
          'url': a.introAudio!,
          'icon': Icons.play_circle_outline,
          'color': AppColors.primary,
        },
      if (a.introductoryPrayersAudio?.isNotEmpty == true)
        {
          'key': 'introductory_prayers',
          'label': tr('introductory_prayers'),
          'url': a.introductoryPrayersAudio!,
          'icon': Icons.auto_stories_outlined,
          'color': AppColors.primary,
        },
      if (a.lectioAudio?.isNotEmpty == true)
        {
          'key': 'lectio',
          'label': 'Lectio',
          'url': a.lectioAudio!,
          'icon': Icons.menu_book_rounded,
          'color': AppColors.primary,
        },
      if (a.commentaryAudio?.isNotEmpty == true)
        {
          'key': 'commentary',
          'label': tr('comment'),
          'url': a.commentaryAudio!,
          'icon': Icons.comment_outlined,
          'color': AppColors.accent,
        },
      if (a.meditatioAudio?.isNotEmpty == true)
        {
          'key': 'meditatio',
          'label': 'Meditatio',
          'url': a.meditatioAudio!,
          'icon': Icons.self_improvement,
          'color': AppColors.primary,
        },
      if (a.oratioAudio?.isNotEmpty == true)
        {
          'key': 'oratio',
          'label': 'Oratio',
          'url': a.oratioAudio!,
          'icon': Icons.favorite_rounded,
          'color': AppColors.primary,
        },
      if (a.contemplatioAudio?.isNotEmpty == true)
        {
          'key': 'contemplatio',
          'label': 'Contemplatio',
          'url': a.contemplatioAudio!,
          'icon': Icons.visibility_rounded,
          'color': AppColors.primary,
        },
      if (a.actioAudio?.isNotEmpty == true)
        {
          'key': 'actio',
          'label': 'Actio',
          'url': a.actioAudio!,
          'icon': Icons.directions_run_rounded,
          'color': AppColors.primary,
        },
    ];

    _tracks = sections;
  }

  /// Build ConcatenatingAudioSource from section audios + interludes
  Future<void> _buildAndPlayPlaylist({int fromTrack = 0}) async {
    if (_adoration == null || _tracks.isEmpty) return;
    final interludeUrl = _getInterludeUrl();

    final sources = <AudioSource>[];
    _sourceMap = [];

    final albumName = tr('eucharistic_adoration');
    final artist = _adoration?.author ?? albumName;

    for (int i = 0; i < _tracks.length; i++) {
      final track = _tracks[i];
      final url = track['url'] as String;
      final label = track['label'] as String;
      final key = track['key'] as String;

      sources.add(
        // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
        LockCachingAudioSource(
          Uri.parse(url),
          tag: MediaItem(
            id: key,
            album: albumName,
            title: label,
            artist: artist,
            artUri: _artUri,
          ),
        ),
      );
      _sourceMap.add({'type': 'track', 'trackIndex': i});

      // Interlude between sections (if mode != none)
      if (interludeUrl.isNotEmpty && i < _tracks.length - 1) {
        final interludeArtist = _audioMode == 'short' ? 'MudiG' : 'Off Beat';
        sources.add(
          // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
          LockCachingAudioSource(
            Uri.parse(interludeUrl),
            tag: MediaItem(
              id: 'interlude_$i',
              album: albumName,
              title: 'Meditačná hudba',
              artist: interludeArtist,
              artUri: _artUri,
            ),
          ),
        );
        _sourceMap.add({'type': 'interlude', 'trackIndex': i});
      }
    }

    if (sources.isEmpty) return;

    try {
      await _audioPlayer.stop();
      final playlist = ConcatenatingAudioSource(children: sources);
      await _audioPlayer.setAudioSource(playlist);

      if (fromTrack > 0) {
        final nativeIdx = _sourceMap.indexWhere(
          (e) => e['type'] == 'track' && e['trackIndex'] == fromTrack,
        );
        if (nativeIdx >= 0) {
          await _audioPlayer.seek(Duration.zero, index: nativeIdx);
        }
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error building adoration playlist: $e');
    }
  }

  void _onPlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle ||
          _audioPlayer.processingState == ProcessingState.completed) {
        _buildAndPlayPlaylist();
      } else {
        _audioPlayer.play();
      }
    }
  }

  void _onSkipNext() {
    final currentNative = _audioPlayer.currentIndex ?? 0;
    for (int i = currentNative + 1; i < _sourceMap.length; i++) {
      if (_sourceMap[i]['type'] == 'track') {
        _audioPlayer.seek(Duration.zero, index: i);
        return;
      }
    }
  }

  void _onSkipPrevious() {
    final currentNative = _audioPlayer.currentIndex ?? 0;
    for (int i = currentNative - 1; i >= 0; i--) {
      if (_sourceMap[i]['type'] == 'track') {
        _audioPlayer.seek(Duration.zero, index: i);
        return;
      }
    }
  }

  int get _currentTrackIndex {
    final nativeIdx = _audioPlayer.currentIndex ?? 0;
    if (nativeIdx < _sourceMap.length) {
      return _sourceMap[nativeIdx]['trackIndex'] as int;
    }
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdoration();
  }

  Future<void> _loadAdoration() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = context.locale.languageCode;

      // Load adoration if not provided initially
      Adoration? adoration = _adoration;
      if (adoration == null) {
        adoration = await _adorationService.getAdoration(widget.adorationId);
        if (adoration == null) {
          throw Exception(tr('adoration_not_found'));
        }
      }

      // Load navigation (next/previous)
      final next = await _adorationService.getNextAdoration(
        adoration.order,
        lang,
      );
      final previous = await _adorationService.getPreviousAdoration(
        adoration.order,
        lang,
      );

      if (mounted) {
        setState(() {
          _adoration = adoration;
          _nextAdoration = next;
          _previousAdoration = previous;
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

  void _navigateToAdoration(String adorationId, Adoration adoration) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: RouteSettings(name: '/adoration/$adorationId'),
        builder: (context) => AdorationDetailScreen(
          adorationId: adorationId,
          initialAdoration: adoration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildLoadingScreen(theme);
    }

    if (_error != null || _adoration == null) {
      return _buildErrorScreen(theme);
    }

    final hasSectionAudios = _tracks.isNotEmpty;

    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  HomeV2.background(context),
                  AppColors.accent.withValues(alpha: 0.05),
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
                      // Content
                      Column(
                        children: [
                          _buildBiblicalText(theme),
                          _buildIntroduction(theme),
                          if (_adoration!.introductoryPrayers?.isNotEmpty ==
                              true)
                            _buildIntroductoryPrayers(theme),
                          _buildLectioDivinaSections(theme),
                          if (_adoration!.commentary?.isNotEmpty == true)
                            _buildComment(theme),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: _buildNavigationButtons(theme),
                          ),
                          // Bottom padding for floating player + nav bar
                          SizedBox(
                            height:
                                (_showAudioPlayer
                                    ? 120 + AppSpacing.xl
                                    : AppSpacing.xl) +
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
              onSkipPrevious: _currentTrackIndex > 0 ? _onSkipPrevious : null,
              onSkipNext: _currentTrackIndex < _tracks.length - 1
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
                final idx = _tracks.indexWhere((t) => t['key'] == key);
                if (idx >= 0) {
                  final nativeIdx = _sourceMap.indexWhere(
                    (e) => e['type'] == 'track' && e['trackIndex'] == idx,
                  );
                  if (nativeIdx >= 0 &&
                      _audioPlayer.processingState != ProcessingState.idle) {
                    _audioPlayer.seek(Duration.zero, index: nativeIdx);
                  } else {
                    _buildAndPlayPlaylist(fromTrack: idx);
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
          // FAB to open player when closed (only if there are section audios)
          if (!_showAudioPlayer && hasSectionAudios)
            Positioned(
              right: AppSpacing.lg,
              bottom:
                  AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
              child: FloatingActionButton(
                heroTag: 'adoration_open_player',
                backgroundColor: AppColors.primary,
                onPressed: () {
                  setState(() {
                    _showAudioPlayer = true;
                    if (_tracks.isNotEmpty) {
                      _currentAudioSection = _tracks[0]['key'] as String;
                    }
                  });
                  _buildAndPlayPlaylist();
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
              tr('loading_adoration'),
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
                      tr('adoration_not_found'),
                      style: HomeV2.serifTitle(context, size: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error ?? tr('requested_adoration_not_found'),
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
                          label: Text(tr('back_to_list')),
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
                          onPressed: _loadAdoration,
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

  Widget _buildAppBar(ThemeData theme) {
    // Jednotný zbaliteľný hero (vzor krížové cesty) — CollapsibleHeroAppBar.
    return CollapsibleHeroAppBar(
      collapsedTitle: _adoration!.title,
      imageUrl: _adoration!.hasImage ? _adoration!.illustrationImage : null,
      expandedContent: HeroCenteredContent(
        title: _adoration!.title,
        subtitle: _adoration!.author,
        icon: Icons.favorite_rounded,
      ),
    );
  }

  Widget _buildBiblicalText(ThemeData theme) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        elevation: AppElevation.medium,
        color: AppColors.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _adoration!.biblicalText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme) {
    final theme = Theme.of(context);
    if (_adoration!.introduction.isEmpty) {
      return const SizedBox.shrink();
    }

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
                tr('audio_intro'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: _adoration!.introduction,
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
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroductoryPrayers(ThemeData theme) {
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
                tr('introductory_prayers'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: _adoration!.introductoryPrayers!,
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
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectioDivinaSections(ThemeData theme) {
    final sections = <String, String>{
      if (_adoration!.lectioText?.isNotEmpty == true)
        'lectio': _adoration!.lectioText!,
      if (_adoration!.meditatioText?.isNotEmpty == true)
        'meditatio': _adoration!.meditatioText!,
      if (_adoration!.oratioHtml?.isNotEmpty == true)
        'oratio': _adoration!.oratioHtml!,
      if (_adoration!.contemplatioText?.isNotEmpty == true)
        'contemplatio': _adoration!.contemplatioText!,
      if (_adoration!.actioText?.isNotEmpty == true)
        'actio': _adoration!.actioText!,
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
      'lectio': {
        'name': 'Lectio',
        'subtitle': tr('reading'),
        'color': AppColors.primary,
      },
      'meditatio': {
        'name': 'Meditatio',
        'subtitle': tr('meditation'),
        'color': AppColors.primary,
      },
      'oratio': {
        'name': 'Oratio',
        'subtitle': tr('prayer'),
        'color': AppColors.primary,
      },
      'contemplatio': {
        'name': 'Contemplatio',
        'subtitle': tr('contemplation'),
        'color': AppColors.primary,
      },
      'actio': {
        'name': 'Actio',
        'subtitle': tr('action'),
        'color': AppColors.primary,
      },
    };

    return lectioDivinaSteps[key] ??
        {'name': key, 'subtitle': '', 'color': AppColors.primary};
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
                  color: sectionInfo['color'],
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
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComment(ThemeData theme) {
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
                tr('comment'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Html(
                data: _adoration!.commentary!,
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
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    final hasPrevious = _previousAdoration != null;
    final hasNext = _nextAdoration != null;

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
                onPressed: () => _navigateToAdoration(
                  _previousAdoration!.id,
                  _previousAdoration!,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  tr('previous'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
                    _navigateToAdoration(_nextAdoration!.id, _nextAdoration!),
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

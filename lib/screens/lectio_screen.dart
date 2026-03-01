import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lectio_audio_state.dart';
import '../models/lectio_audio_track.dart';
import '../helpers/dnd_helper.dart';
import '../services/audio_download_service.dart';
import '../services/background_audio_manager.dart';
import '../services/connectivity_service.dart';
import '../services/lectio_cache_service.dart';
import '../shared/audio_constants.dart';
import '../services/do_not_disturb_service.dart';
import '../services/prayer_focus_service.dart';
import '../shared/app_colors.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../widgets/download_indicator.dart';
import '../widgets/global_mini_player.dart';
import '../widgets/lectio_floating_audio_player.dart';
import '../widgets/lectio_section_card.dart';
import '../widgets/lectio_speed_dial_fab.dart';
import '../widgets/prayer_focus_indicator.dart';
import 'note_detail_screen.dart';
import '../shared/app_spacing.dart';

class LectioScreen extends StatefulWidget {
  const LectioScreen({
    super.key,
    this.selectedLang,
    this.selectedDate, // ← NOVÝ parameter
  });

  final String? selectedLang;
  final DateTime? selectedDate; // ← NOVÝ parameter

  @override
  State<LectioScreen> createState() => _LectioScreenState();
}

class _LectioScreenState extends State<LectioScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PrayerFocusService _prayerFocusService = PrayerFocusService();
  final BackgroundAudioManager _backgroundAudioManager =
      BackgroundAudioManager();
  final DoNotDisturbService _dndService = DoNotDisturbService();
  final AudioDownloadService _audioDownloadService =
      AudioDownloadService.instance;

  Map<String, dynamic>? lectioData;
  bool isLoading = true;
  bool _dataLoaded = false;
  DateTime selectedDate = DateTime.now();
  String _selectedBible = 'biblia_1'; // Názov stĺpca v lectio_sources

  // Audio player state - s enum pre hlavný stav
  LectioPlaybackState _playbackState = LectioPlaybackState.idle;
  bool _showAudioPlayer = false;
  bool _isMinimized = false;
  String? _currentAudioSection;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String _audioMode = 'short'; // 'none', 'short', 'long'
  Map<String, dynamic>? _nextTrackAfterInterlude;
  bool _audioPlayerClosed = false;
  bool _isProcessingInterludeCompletion = false;
  bool _usingFallbackPlayer = false;
  StreamSubscription? _fallbackPlayerSubscription;
  bool _isPlayingInterlude = false; // Track if meditation music is playing
  bool _isPlayAudioInProgress =
      false; // Guard against concurrent _playAudio calls
  Completer<void>? _playAudioCompleter; // For awaiting current _playAudio
  DateTime? _lastSkipTime; // Debounce for skip buttons

  // Do Not Disturb state
  bool _isDndActive = false;
  bool _dndEnabled = false;

  // Offline mode state
  bool _isDownloading = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  // Audio download state
  bool _isDownloadingAudio = false;
  int _audioDownloadCurrent = 0;
  int _audioDownloadTotal = 0;
  double _audioDownloadProgress = 0.0;

  // Cache pre tracks
  List<Map<String, dynamic>>? _cachedTracks;
  String? _lastCachedBible;
  Map<String, dynamic>? _lastCachedLectioData;

  // PageView controller
  final PageController _playlistPageController = PageController();

  // Timer pre pravidelnú aktualizáciu pozície
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Skry globálny mini player (LectioScreen má vlastný plný prehrávač)
    GlobalMiniPlayer.hideOnCurrentScreen.value = true;
    _setupAudioListeners();
    _initializeDndService();
    _initializeBackgroundAudio();
    _startPositionTimer();
    _initializeConnectivity();
    _restoreAudioPlayerState();

    // Callback sa zaregistruje v _playBackgroundAudio po inicializácii

    // Notifikuj Prayer Focus Service o vstupe do Lectio screen
    _prayerFocusService.onSpiritualScreenEntered(SpiritualScreen.lectio);
  }

  /// Obnoví stav audio prehrávača ak sa vracia na LectioScreen a audio stále hrá
  void _restoreAudioPlayerState() {
    final player = _backgroundAudioManager;
    if (player.isInitialized && player.playlist.isNotEmpty) {
      final isPlaying = player.isPlaying;
      final currentIndex = player.currentTrackIndex;
      final tracks = player.playlist;

      if (currentIndex >= 0 && currentIndex < tracks.length) {
        final currentTrack = tracks[currentIndex];
        appLogger.i(
          '🔄 Restoring audio player state: ${currentTrack['key']}, playing=$isPlaying',
        );

        setState(() {
          _showAudioPlayer = true;
          _currentAudioSection = currentTrack['key'] as String;
          _isPlaying = isPlaying;
          _isPlayingInterlude = player.isPlayingInterlude;
          _playbackState = isPlaying
              ? LectioPlaybackState.playing
              : LectioPlaybackState.paused;
          _currentPosition = player.currentPosition;
          _totalDuration = player.totalDuration ?? Duration.zero;
        });

        // Animuj na správny track v playlistu
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_playlistPageController.hasClients && mounted) {
            _playlistPageController.jumpToPage(currentIndex);
          }
        });

        // Re-registruj callbacks
        _setupBackgroundCallbacks();
      }
    }
  }

  /// Registruje callbacks pre BackgroundAudioManager
  void _setupBackgroundCallbacks() {
    final tracks = _getAvailableAudioTracks();

    _backgroundAudioManager.setOnTrackChanged((trackKey, index) {
      appLogger.d('🎵 onTrackChanged: trackKey=$trackKey, index=$index');
      if (mounted) {
        setState(() {
          if (trackKey == 'interlude') {
            _isPlayingInterlude = true;
            _playbackState = LectioPlaybackState.playingInterlude;
          } else if (index >= 0 && index < tracks.length) {
            _isPlayingInterlude = false;
            _currentAudioSection = tracks[index]['key'];
            _playbackState = LectioPlaybackState.playing;
            if (_playlistPageController.hasClients) {
              _playlistPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          }
        });
      }
    });

    _backgroundAudioManager.setOnPlaylistCompleted(() {
      appLogger.d('🎵 Playlist completed');
      if (mounted) {
        setState(() {
          _playbackState = LectioPlaybackState.stopped;
          _isPlaying = false;
          _isPlayingInterlude = false;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
        });
      }
    });

    _backgroundAudioManager.setOnSectionCompleted(() {
      appLogger.d('🎵 Section completed callback');
      if (mounted) {
        appLogger.d('🎵 UI will be updated via stream listeners');
      }
    });
  }

  /// Inicializácia sledovania pripojenia
  void _initializeConnectivity() {
    _isOffline = !ConnectivityService.instance.isOnline;
    _connectivitySubscription = ConnectivityService
        .instance
        .onConnectivityChanged
        .listen((isOnline) {
          if (mounted) {
            setState(() {
              _isOffline = !isOnline;
            });
            // Ak sa pripojíme, automaticky cache dnes + zajtra
            if (isOnline) {
              _autoCacheBackground();
            }
          }
        });
  }

  /// Automatický cache dnes + zajtra na pozadí
  Future<void> _autoCacheBackground() async {
    final locale = context.locale.languageCode;
    await LectioCacheService.instance.autoCache(locale);
  }

  Future<void> _initializeBackgroundAudio() async {
    try {
      await _backgroundAudioManager.initialize();
      appLogger.i('✅ BackgroundAudioManager initialized in initState');
    } catch (e) {
      appLogger.e('❌ Error initializing BackgroundAudioManager: $e');
    }
  }

  Future<void> _initializeDndService() async {
    await _dndService.initialize();
    if (mounted) {
      setState(() {
        _dndEnabled = _dndService.isEnabled;
        _isDndActive = _dndService.isDndActive;
      });
    }
  }

  /// Aktualizuje hlavný playback stav
  void _setPlaybackState(LectioPlaybackState state) {
    if (mounted) {
      setState(() {
        _playbackState = state;
        // Synchronizuj boolean premenné s enum stavom
        _isPlaying = state.isPlaying;
        _isProcessingInterludeCompletion =
            state == LectioPlaybackState.processingInterludeTransition;
      });
      appLogger.d('🎵 Playback state: $state');
    }
  }

  Future<void> _playBackgroundAudio(String url, String sectionKey) async {
    try {
      // Reset fallback flag - budeme skúšať hlavný prehrávač
      _usingFallbackPlayer = false;

      // Initialize if needed
      if (!_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.initialize();
        appLogger.i('✅ BackgroundAudioManager initialized');

        // Register media item listener for duration updates (only once)
        if (_backgroundAudioManager.audioHandler != null) {
          _backgroundAudioManager.audioHandler!.mediaItem.listen((item) {
            if (!mounted || item == null) return;

            if (item.duration != null && !_isPlayingInterlude) {
              setState(() {
                _totalDuration = item.duration!;
              });
              appLogger.d(
                '🎵 Duration updated from mediaItem: ${item.duration}',
              );
            }
          });
          appLogger.i('✅ Media item listener registered');
        }
      }

      // 🎯 Nastaviť playlist do BackgroundAudioManager
      // Len ak sa playlist zmenil (napr. nový deň) alebo po interlude
      final tracks = _getAvailableAudioTracks();
      final currentIndex = tracks.indexWhere((t) => t['key'] == sectionKey);

      // Skontroluj či treba rebuildiť playlist
      final existingPlaylist = _backgroundAudioManager.playlist;
      final playlistChanged =
          existingPlaylist.length != tracks.length ||
          !tracks.every(
            (t) => existingPlaylist.any(
              (e) =>
                  e['key'] == t['key'] &&
                  e['url'] == t['url'] &&
                  e['localPath'] == t['localPath'],
            ),
          );
      // Rebuild ak sa zmenil playlist alebo je prázdny
      final needsRebuild = playlistChanged || existingPlaylist.isEmpty;

      if (needsRebuild) {
        // Nastaviť playlist a audio mode (NOW ASYNC)
        await _backgroundAudioManager.setPlaylist(tracks, _audioMode);
        appLogger.d(
          '🎵 Playlist rebuilt: ${tracks.length} tracks, current: $currentIndex',
        );
      } else {
        // Len aktualizuj audio mode
        _backgroundAudioManager.setAudioMode(_audioMode);
        appLogger.d('🎵 Playlist unchanged, seeking to track: $currentIndex');
      }

      // Callback pre UI update keď sa zmení track (pre prípad keď je widget mounted)
      _backgroundAudioManager.setOnTrackChanged((trackKey, index) {
        appLogger.d('🎵 onTrackChanged: trackKey=$trackKey, index=$index');
        if (mounted) {
          // Poznámka: NERUŠÍME _fallbackPlayerSubscription tu,
          // lebo callback môže prísť aj keď BAM nefunguje (Android)
          // Subscription sa ruší v _playBackgroundAudio pri novom prehrávaní

          setState(() {
            if (trackKey == 'interlude') {
              // During interlude, keep _currentAudioSection on previous track
              // Only set the interlude flag
              _isPlayingInterlude = true;
              _playbackState = LectioPlaybackState.playingInterlude;
              appLogger.d(
                '🎵 Interlude started - keeping carousel on current track',
              );
            } else if (index >= 0 && index < tracks.length) {
              _isPlayingInterlude = false;
              _currentAudioSection = tracks[index]['key'];
              _playbackState = LectioPlaybackState.playing;
              // Animovať na nový track
              if (_playlistPageController.hasClients) {
                _playlistPageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
              appLogger.d('🎵 Track changed to: ${tracks[index]['key']}');
            }
          });
        }
      });

      // Callback keď sa playlist dokončí
      _backgroundAudioManager.setOnPlaylistCompleted(() {
        appLogger.d('🎵 Playlist completed');
        if (mounted) {
          setState(() {
            _playbackState = LectioPlaybackState.stopped;
            _isPlaying = false;
            _isPlayingInterlude = false;
            _currentPosition = Duration.zero;
            _totalDuration = Duration.zero;
          });
        }
      });

      // Callback when track section completes (for UI update only)
      // NOTE: Auto-progression is handled internally by LectioAudioPlayer
      _backgroundAudioManager.setOnSectionCompleted(() {
        appLogger.d('🎵 🚀 Section completed callback from LectioAudioPlayer');
        appLogger.d(
          '🎵 mounted=$mounted, _currentAudioSection=$_currentAudioSection',
        );
        // Only update UI state, don't call _onAudioCompleted
        // LectioAudioPlayer handles auto-progression internally
        if (mounted) {
          appLogger.d('🎵 UI will be updated via stream listeners');
        }
      });
      appLogger.i('✅ Section completed callback registered (UI only)');

      // Get section title for media notification
      String title = _getSectionTitle(sectionKey);
      String subtitle = 'Lectio Divina';

      if (lectioData != null) {
        subtitle = lectioData?['hlava'] ?? 'Lectio Divina';
      }

      // Nastaviť current track index v BackgroundAudioManager
      _backgroundAudioManager.setCurrentTrackByKey(sectionKey);

      await _backgroundAudioManager.play(url, title: title, artist: subtitle);

      appLogger.d('🎵 Background audio started: $title');
    } catch (e) {
      appLogger.e('❌ Error playing background audio: $e');

      // Ak je error o offline dostupnosti, ukáž užívateľovi
      if (e.toString().contains('not available offline')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Audio nie je dostupné offline. Najprv si ho stiahnite.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Stiahnuť',
                textColor: Colors.white,
                onPressed: _showDownloadDialog,
              ),
            ),
          );
        }
        return; // Neskúšaj fallback ak je offline problém
      }

      // Fallback to regular audio player pre iné errory
      _usingFallbackPlayer = true;
      appLogger.d(
        '🎵 🔄 Using fallback player, _usingFallbackPlayer=$_usingFallbackPlayer',
      );

      // Zrušiť predchádzajúcu subscription ak existuje
      await _fallbackPlayerSubscription?.cancel();
      _fallbackPlayerSubscription = null;
      appLogger.d('🎵 Previous fallback subscription cancelled');

      // Skontroluj lokálny súbor pre offline prehrávanie
      final localPathOrNull = _audioDownloadService.getLocalPath(url);
      final useLocalFile =
          localPathOrNull != null && File(localPathOrNull).existsSync();
      final localPath = localPathOrNull ?? '';

      final audioSource = useLocalFile
          ? AudioSource.file(
              localPath,
              tag: MediaItem(
                id: sectionKey,
                album: 'Lectio Divina',
                title: _getSectionTitle(sectionKey),
                artist: 'Lectio Divina',
                artUri: _isOffline
                    ? null
                    : Uri.parse(AudioConstants.defaultArtworkUrl),
              ),
            )
          : AudioSource.uri(
              Uri.parse(url),
              tag: MediaItem(
                id: sectionKey,
                album: 'Lectio Divina',
                title: _getSectionTitle(sectionKey),
                artist: 'Lectio Divina',
                artUri: _isOffline
                    ? null
                    : Uri.parse(AudioConstants.defaultArtworkUrl),
              ),
            );
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      appLogger.d('🎵 Fallback player started playing');

      // Listen for completion on fallback player
      _fallbackPlayerSubscription = _audioPlayer.playerStateStream.listen((
        state,
      ) {
        appLogger.d(
          '🎵 📡 Fallback listener: processingState=${state.processingState}, _usingFallbackPlayer=$_usingFallbackPlayer, section=$_currentAudioSection',
        );
        if (state.processingState == ProcessingState.completed &&
            _usingFallbackPlayer &&
            !_isPlayingInterlude) {
          appLogger.d('🎵 ✅ Fallback player completed, triggering next');
          _onAudioCompleted();
        }
      });
      appLogger.d('🎵 ✅ New fallback subscription created');
    }
  }

  String _getSectionTitle(String sectionKey) {
    switch (sectionKey) {
      case 'biblia_1':
      case 'biblia_2':
      case 'biblia_3':
        return lectioData?['nazov_$sectionKey'] ?? 'Biblický text';
      case 'lectio':
        return 'LECTIO - Čítanie';
      case 'meditatio':
        return 'MEDITATIO - Rozjímanie';
      case 'oratio':
        return 'ORATIO - Modlitba';
      case 'contemplatio':
        return 'CONTEMPLATIO - Rozjímanie';
      case 'actio':
        return 'ACTIO - Konanie';
      default:
        return 'Lectio Divina Audio';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      // Nastaviť selectedDate ak je poskytnutý z HomeScreen
      if (widget.selectedDate != null) {
        selectedDate = widget.selectedDate!;
      }

      _loadSelectedBible().then((_) => fetchLectioData());
      _dataLoaded = true;
    }
  }

  void _startPositionTimer() {
    // Timer pre pravidelnú aktualizáciu pozície (každých 200ms)
    _positionUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _updatePositionFromPlayer(),
    );
  }

  void _updatePositionFromPlayer() {
    if (!mounted || _currentAudioSection == null) return;

    // Neaktualizuj ak je playback stopped/completed - zabráni overridu _isPlaying
    if (_playbackState == LectioPlaybackState.stopped ||
        _playbackState == LectioPlaybackState.idle) {
      return;
    }

    // Ak používame fallback player (Android keď BAM zlyhá)
    if (_usingFallbackPlayer) {
      final position = _audioPlayer.position;
      final duration = _audioPlayer.duration;
      final isPlaying = _audioPlayer.playing;

      // Debug výpis každú sekundu
      if (position.inMilliseconds % 1000 < 250) {
        appLogger.d(
          '🎵 Fallback timer: pos=${position.inSeconds}s, dur=${duration?.inSeconds}s, playing=$isPlaying',
        );
      }

      if (position != _currentPosition ||
          (duration != null && duration != _totalDuration) ||
          isPlaying != _isPlaying) {
        setState(() {
          _currentPosition = position;
          _isPlaying = isPlaying;
          if (duration != null) {
            _totalDuration = duration;
          }
        });
      }
    }
    // Pre BackgroundAudioManager (vrátane interlude na iOS)
    else if (_backgroundAudioManager.isInitialized) {
      final position = _backgroundAudioManager.currentPosition;
      final duration = _backgroundAudioManager.totalDuration;
      final isPlaying = _backgroundAudioManager.isPlaying;
      final isInterlude = _backgroundAudioManager.isPlayingInterlude;

      // Sync interlude state from BAM to UI
      if (isInterlude != _isPlayingInterlude) {
        appLogger.d(
          '🎵 Timer: interlude state sync: BAM=$isInterlude, UI=$_isPlayingInterlude',
        );
        setState(() {
          _isPlayingInterlude = isInterlude;
          if (isInterlude) {
            _playbackState = LectioPlaybackState.playingInterlude;
          }
        });
      }

      // 🎯 Safety net: sync current track from BAM to UI
      // Handles cases where onTrackChanged callback was missed
      final bamTrackIndex = _backgroundAudioManager.currentTrackIndex;
      final bamTrackKey = _backgroundAudioManager.lectioPlayer.currentTrackKey;
      if (!isInterlude &&
          bamTrackKey != null &&
          bamTrackKey != 'interlude' &&
          bamTrackKey != _currentAudioSection &&
          bamTrackIndex >= 0) {
        appLogger.d(
          '🎵 Timer: track sync safety net: BAM=$bamTrackKey (idx=$bamTrackIndex), UI=$_currentAudioSection',
        );
        setState(() {
          _currentAudioSection = bamTrackKey;
          _playbackState = isPlaying
              ? LectioPlaybackState.playing
              : LectioPlaybackState.paused;
        });
        // Animate slide to correct track
        if (_playlistPageController.hasClients) {
          _playlistPageController.animateToPage(
            bamTrackIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }

      // Sync playbackState when playing (timer catches loading→playing transition)
      if (isPlaying && _playbackState == LectioPlaybackState.loading) {
        setState(() {
          _playbackState = LectioPlaybackState.playing;
        });
      }

      // Debug výpis každú sekundu
      if (position.inMilliseconds % 1000 < 250) {
        appLogger.d(
          '🎵 Timer update: pos=${position.inSeconds}s, dur=${duration?.inSeconds}s, playing=$isPlaying, _isPlaying=$_isPlaying, interlude=$_isPlayingInterlude',
        );
      }

      // Aktualizuj stav ak sa zmenil
      if (position != _currentPosition ||
          (duration != null && duration != _totalDuration) ||
          isPlaying != _isPlaying) {
        setState(() {
          _currentPosition = position;
          _isPlaying = isPlaying;
          if (duration != null) {
            _totalDuration = duration;
          }
        });
      }
    }
  }

  /// Zobrazí dialóg pre stiahnutie Lectio na offline použitie
  void _showDownloadDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.download_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tr('offline.download_for_offline'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('offline.download_description'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Stiahnutie textov
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadLectioForDays(7);
                },
                icon: const Icon(Icons.article_rounded),
                label: Text(tr('offline.download_texts', args: ['7'])),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Stiahnutie audio pre dnešok
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: lectioData == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _downloadAudioForToday();
                      },
                icon: const Icon(Icons.music_note_rounded),
                label: Text(tr('offline.download_audio_today')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Stiahnutie textov + audio
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadLectioWithAudio(7);
                },
                icon: const Icon(Icons.cloud_download_rounded),
                label: Text(tr('offline.download_all', args: ['7'])),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Správa úložiska
            if (_audioDownloadService.downloadedFilesCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${_audioDownloadService.downloadedFilesCount} ${tr('offline.files')} • ${_audioDownloadService.formattedStorageSize}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showStorageManagement();
                      },
                      child: Text(
                        tr('offline.manage'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
          ],
        ),
      ),
    );
  }

  /// Stiahne audio nahrávky pre dnešný deň
  Future<void> _downloadAudioForToday() async {
    if (_isDownloadingAudio || lectioData == null) return;

    setState(() {
      _isDownloadingAudio = true;
      _audioDownloadProgress = 0.0;
      _audioDownloadCurrent = 0;
      _audioDownloadTotal = 0;
    });

    // Invalidate tracks cache - lokálne cesty sa zmenia
    _invalidateTracksCache();

    try {
      final today = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Stiahni interlude hudbu (ak ešte nie je stiahnutá)
      await _audioDownloadService.downloadInterlude();

      await _audioDownloadService.downloadAllForDay(
        lectioData: lectioData!,
        date: today,
        selectedBible: _selectedBible,
        onProgress: (current, total, progress) {
          if (mounted) {
            setState(() {
              _audioDownloadCurrent = current;
              _audioDownloadTotal = total;
              _audioDownloadProgress = progress;
            });
          }
        },
      );

      // Invalidate tracks cache opäť - teraz budú nové lokálne cesty
      _invalidateTracksCache();

      if (mounted) {
        _showSuccessIndicator();
      }
    } catch (e) {
      appLogger.e('❌ Audio download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('offline.audio_download_error')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAudio = false;
        });
      }
    }
  }

  /// Stiahne audio pre N dní (použije cached lectio data)
  Future<void> _downloadAudioForDays(int days) async {
    if (_isDownloadingAudio) return;

    setState(() {
      _isDownloadingAudio = true;
      _audioDownloadProgress = 0.0;
      _audioDownloadCurrent = 0;
      _audioDownloadTotal = 0;
    });

    try {
      final locale = context.locale.languageCode;
      final now = DateTime.now();
      int totalSuccess = 0;
      int totalCount = 0;

      // Stiahni interlude hudbu (ak ešte nie je stiahnutá)
      await _audioDownloadService.downloadInterlude();

      for (int i = 0; i < days; i++) {
        final date = now.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);

        // Načítaj cached lectio data
        final cachedData = await LectioCacheService.instance.getCachedLectio(
          dateString,
          locale,
        );

        if (cachedData == null || cachedData.rawLectioSource == null) {
          appLogger.w('⚠️ Žiadne cached data pre $dateString - preskakujem');
          continue;
        }

        // Stiahni audio pre tento deň
        final result = await _audioDownloadService.downloadAllForDay(
          lectioData: cachedData.rawLectioSource!,
          date: dateString,
          selectedBible: _selectedBible,
          onProgress: (current, total, progress) {
            if (mounted) {
              setState(() {
                _audioDownloadCurrent = totalSuccess + current;
                _audioDownloadTotal = totalCount + total;
                _audioDownloadProgress = _audioDownloadTotal > 0
                    ? _audioDownloadCurrent / _audioDownloadTotal
                    : 0.0;
              });
            }
          },
        );

        totalSuccess += result.successCount;
        totalCount += result.totalCount;
      }

      // Invalidate tracks cache
      _invalidateTracksCache();

      if (mounted) {
        _showSuccessIndicator();
      }
    } catch (e) {
      appLogger.e('❌ Audio download for days failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('offline.audio_download_error')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAudio = false;
        });
      }
    }
  }

  /// Stiahne texty + audio na N dní
  Future<void> _downloadLectioWithAudio(int days) async {
    // Najprv stiahni texty
    await _downloadLectioForDays(days);

    // Potom stiahni audio pre všetkých N dní
    await _downloadAudioForDays(days);
  }

  /// Zobrazí dialóg správy úložiska
  void _showStorageManagement() async {
    await showDialog(
      context: context,
      builder: (context) =>
          AudioStorageDialog(downloadService: _audioDownloadService),
    );
    if (mounted) {
      _invalidateTracksCache(); // Clear cache to refresh offline status
      setState(() {}); // Refresh UI after dialog closes
    }
  }

  /// Zobrazí jednoducho indikátor úspechu (zelená fajka v kruhu)
  void _showSuccessIndicator() {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Automaticky odstrán po 1.5 sekundách
    Future.delayed(const Duration(milliseconds: 1500), () {
      overlayEntry.remove();
    });
  }

  // Removed obsolete _handleDeleteAllOfflineData (logic is in AudioStorageDialog)

  /// Stiahne Lectio pre zadaný počet dní
  Future<void> _downloadLectioForDays(int days) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final locale = context.locale.languageCode;
      await LectioCacheService.instance.downloadLectioForDays(
        locale: locale,
        days: days,
        onProgress: (current, total) {
          // Progress tracking - could be displayed in a future update
        },
      );

      if (mounted) {
        _showSuccessIndicator();
      }
    } catch (e) {
      appLogger.e('❌ Download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('offline.download_error')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Zobraz globálny mini player (opúšťame LectioScreen)
    GlobalMiniPlayer.hideOnCurrentScreen.value = false;

    // Zrušiť position timer
    _positionUpdateTimer?.cancel();

    // Zrušiť connectivity subscription
    _connectivitySubscription?.cancel();

    // Zrušiť fallback player subscription
    _fallbackPlayerSubscription?.cancel();

    // Clear background audio callback
    _backgroundAudioManager.clearOnSectionCompleted();

    // Notifikuj Prayer Focus Service o opustení Lectio screen
    _prayerFocusService.onSpiritualScreenExited(SpiritualScreen.lectio);

    // End DND session ak je aktívne
    if (_isDndActive) {
      _dndService.endReadingSession();
    }

    _audioPlayer.dispose();
    _playlistPageController.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    // NOTE: Auto-progression is handled internally by LectioAudioPlayer
    // These listeners are only for UI updates

    // Listen to player state changes from BackgroundAudioManager
    _backgroundAudioManager.playerStateStream.listen((state) {
      if (!mounted) return;

      appLogger.d(
        '🎵 AudioPlayer state changed: playing=${state.playing}, processingState=${state.processingState}',
      );
      appLogger.d('🎵 Current _currentAudioSection: $_currentAudioSection');

      // Update playing state
      setState(() {
        _isPlaying = state.playing;
      });
      appLogger.d('🎵 ✅ State updated: _isPlaying=$_isPlaying');

      // NOTE: Don't call _onAudioCompleted here!
      // Auto-progression is handled by LectioAudioPlayer._onTrackCompletedAsync
    });

    // Listen to position changes
    _backgroundAudioManager.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _backgroundAudioManager.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Also listen to the fallback player for when BAM is not initialized
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      // Only process if we're using fallback player
      if (_usingFallbackPlayer) {
        appLogger.d(
          '🎵 Fallback AudioPlayer state: playing=${state.playing}, processingState=${state.processingState}',
        );
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _onAudioCompleted() async {
    appLogger.d('🎵 ═══════════════════════════════════════════════════════');
    appLogger.d('🎵 🟢 _onAudioCompleted() STARTED');
    appLogger.d('🎵 ═══════════════════════════════════════════════════════');
    appLogger.d('🎵 Audio dokončené: $_currentAudioSection');
    appLogger.d('🎵 Playback state: $_playbackState');
    appLogger.d('🎵 _isPlaying: $_isPlaying');

    // Ignoruj completed stav ak nie sme v stave keď môžeme reagovať
    if (_playbackState == LectioPlaybackState.seeking) {
      appLogger.d('🛑 Prebieha seeking, ignorujem completed stav');
      return;
    }

    // Ak bol prehrávač zatvorený (stopped), nič nerob
    if (_playbackState == LectioPlaybackState.stopped ||
        _playbackState == LectioPlaybackState.idle) {
      appLogger.d('🛑 Prehrávač bol zatvorený, zastavujem playback');
      return;
    }

    // Ak nie je nastavená sekcia, nič nerob
    if (_currentAudioSection == null) {
      appLogger.d('🛑 _currentAudioSection je null, zastavujem');
      return;
    }

    // Ak skončila meditačná hudba, prehraj uloženú nahrávku
    if (_playbackState == LectioPlaybackState.playingInterlude ||
        _isPlayingInterlude) {
      if (_nextTrackAfterInterlude != null &&
          _playbackState != LectioPlaybackState.processingInterludeTransition) {
        // Zabráň dvojitému volaniu
        setState(() {
          _playbackState = LectioPlaybackState.processingInterludeTransition;
          _isProcessingInterludeCompletion = true;
        });
        final next = _nextTrackAfterInterlude!;
        _nextTrackAfterInterlude = null;
        appLogger.i('✅ Meditácia skončila → ${next['key']}');
        appLogger.d('🔄 Zavolam _playAudio pre ďalší track po interlude');

        // Spustíme ďalší track - animácia sa spustí hneď
        await _playAudio(next['url'], next['key']);

        // Reset flag po dokončení spracovania
        _isProcessingInterludeCompletion = false;
      } else if (_isPlayingInterlude && _nextTrackAfterInterlude == null) {
        // Už spracované alebo žiadna ďalšia nahrávka
        appLogger.d(
          '🛑 Interlude completion: _nextTrackAfterInterlude=null, _isProcessingInterludeCompletion=$_isProcessingInterludeCompletion',
        );
        if (!_isProcessingInterludeCompletion) {
          appLogger.d('🛑 Zastavujem audio - žiadna ďalšia nahrávka');
          _stopAudio();
        } else {
          appLogger.d(
            '🛑 Preskakujem stop audio - práve sa spracováva interlude completion',
          );
        }
      } else {
        // Žiadna ďalšia nahrávka
        appLogger.d(
          '🛑 Iný prípad: _currentAudioSection=$_currentAudioSection, _nextTrackAfterInterlude=$_nextTrackAfterInterlude',
        );
        if (!_isProcessingInterludeCompletion) {
          _stopAudio();
        }
      }
      return;
    }

    // Normálna nahrávka skončila → pokračuj na ďalšiu
    await _playNextTrack();
  }

  Future<void> fetchLectioData() async {
    setState(() => isLoading = true);
    final today = DateFormat('yyyy-MM-dd').format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;

    // Cache-first logika: ak sme offline, načítaj z cache
    if (_isOffline) {
      appLogger.d('📦 Offline mód - načítavam z cache pre dátum: $today');
      final cachedData = await LectioCacheService.instance.getCachedLectio(
        today,
        lang,
      );
      if (cachedData != null) {
        appLogger.i('✅ Lectio načítané z cache');
        if (mounted) {
          setState(() {
            lectioData = cachedData.rawData;
            isLoading = false;
          });
          _invalidateTracksCache();
        }
        return;
      } else {
        appLogger.w('⚠️ Cache prázdny pre dátum $today');
        if (mounted) {
          setState(() {
            lectioData = null;
            isLoading = false;
          });
        }
        return;
      }
    }

    final supabase = Supabase.instance.client;

    try {
      appLogger.d('🔍 Načítavam lectio pre dátum: $today, jazyk: $lang');

      // 1. NAJPRV nájdeme správny liturgický rok na základe dátumu
      // (nie z calendar entry, ale priamo podľa date range)
      final liturgicalYearsResponse = await supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', lang)
          .lte('start_date', today)
          .gte('end_date', today);

      Map<String, dynamic>? correctLiturgicalYear;
      final liturgicalYearsList = liturgicalYearsResponse as List;
      if (liturgicalYearsList.isNotEmpty) {
        final yearData = liturgicalYearsList[0] as Map<String, dynamic>;
        correctLiturgicalYear = yearData;
        appLogger.i(
          '✅ Nájdený liturgický rok: ${yearData['year']} '
          '(${yearData['start_date']} - ${yearData['end_date']}), '
          'cyklus: ${yearData['lectionary_cycle']}',
        );
      } else {
        // Fallback na slovenčinu ak aktuálny jazyk nemá liturgický rok
        if (lang != 'sk') {
          appLogger.d('🔄 Hľadám liturgický rok v slovenčine...');
          final skYearsResponse = await supabase
              .from('liturgical_years')
              .select()
              .eq('locale_code', 'sk')
              .lte('start_date', today)
              .gte('end_date', today);

          final skYearsList = skYearsResponse as List;
          if (skYearsList.isNotEmpty) {
            final skYearData = skYearsList[0] as Map<String, dynamic>;
            correctLiturgicalYear = skYearData;
            appLogger.i(
              '✅ Nájdený SK liturgický rok: ${skYearData['year']} '
              '(${skYearData['start_date']} - ${skYearData['end_date']}), '
              'cyklus: ${skYearData['lectionary_cycle']}',
            );
          }
        }
      }

      // 2. Nájdi deň v liturgical_calendar
      var calendarResponse = await supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', today)
          .eq('locale_code', lang)
          .maybeSingle();

      // Fallback na slovenčinu ak kalendár pre aktuálny jazyk neexistuje
      if (calendarResponse == null && lang != 'sk') {
        appLogger.d('🔄 Skúšam načítať kalendár pre slovenčinu...');
        calendarResponse = await supabase
            .from('liturgical_calendar')
            .select()
            .eq('datum', today)
            .eq('locale_code', 'sk')
            .maybeSingle();
      }

      if (calendarResponse == null) {
        appLogger.e('❌ Liturgický kalendár nenájdený pre dátum $today');
        if (mounted) {
          setState(() {
            lectioData = null;
            isLoading = false;
          });
          _invalidateTracksCache();
        }
        return;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      if (lectioHlava == null) {
        appLogger.e('❌ Tento deň nemá priradenú lectio hlavičku');
        if (mounted) {
          setState(() {
            lectioData = null;
            isLoading = false;
          });
        }
        return;
      }

      appLogger.i(
        '✅ Kalendárny deň nájdený: ${calendarResponse['celebration_title']}',
      );
      appLogger.d(
        '🔍 Debug kalendárny deň: datum=${calendarResponse['datum']}, '
        'celebration_title=${calendarResponse['celebration_title']}, '
        'celebration_rank_num=${calendarResponse['celebration_rank_num']}, '
        'lectio_hlava=$lectioHlava',
      );

      // 3. Určíme či použiť cyklus (A/B/C) alebo 'N' pre všedné dni
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      // Pre všedné dni (pondelok-sobota v cezročnom období) používame 'N'
      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota).+týždňa v Cezročnom období',
      ).hasMatch(celebrationTitle);

      // Pre nedele a sviatky používame A/B/C
      final isSpecialDay =
          !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      // POUŽIJEME správny liturgický rok (nájdený podľa dátumu, nie z calendar entry)
      final lectionaryCycle = correctLiturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      appLogger.d(
        '🔍 Hľadám rok: "$rokToSearch" (všedný deň: ${isWeekday ? "ÁNO" : "NIE"}, '
        'špeciálny deň: $isSpecialDay, liturgický cyklus: $lectionaryCycle)',
      );

      // 4. Nájdi zodpovedajúci záznam v lectio_sources
      var lectioSource = await supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', lang)
          .eq('rok', rokToSearch)
          .maybeSingle();

      // Fallback logika
      if (lectioSource == null) {
        appLogger.e('❌ Lectio source nenájdený pre $lang, rok $rokToSearch');

        // Pre sviatky: skús rok 'N'
        if (isSpecialDay && rokToSearch != 'N') {
          appLogger.d('🔄 Sviatok nenájdený s rokom A/B/C, skúšam rok N...');
          lectioSource = await supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', lang)
              .eq('rok', 'N')
              .maybeSingle();

          if (lectioSource != null) {
            appLogger.i(
              '✅ Lectio source nájdený s rokom N: ${lectioSource['hlava']}',
            );
          }
        }

        // Fallback na slovenčinu
        if (lectioSource == null && lang != 'sk') {
          appLogger.d('🔄 Skúšam načítať lectio source pre slovenčinu...');
          lectioSource = await supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', 'sk')
              .eq('rok', rokToSearch)
              .maybeSingle();

          // Pre sviatky v slovenčine: aj tu skús 'N'
          if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
            appLogger.d('🔄 Skúšam slovenčinu s rokom N...');
            lectioSource = await supabase
                .from('lectio_sources')
                .select()
                .eq('hlava', lectioHlava)
                .eq('lang', 'sk')
                .eq('rok', 'N')
                .maybeSingle();
          }

          if (lectioSource != null) {
            appLogger.i(
              '✅ Lectio source nájdený v slovenčine: ${lectioSource['hlava']}',
            );
          }
        }
      }

      if (lectioSource != null) {
        appLogger.i(
          '✅ Lectio source nájdený: ${lectioSource['hlava']}, rok: ${lectioSource['rok']}',
        );
        // Ulož do cache pre offline použitie
        final cachedData = CachedLectioData(
          date: today,
          locale: lang,
          celebrationTitle: calendarResponse['celebration_title'],
          lectioHlava: lectioSource['hlava'],
          actioText: lectioSource['actio_text'],
          lectioText: lectioSource['lectio_text'],
          meditatioText: lectioSource['meditatio_text'],
          oratioText: lectioSource['oratio_text'],
          contemplatioText: lectioSource['contemplatio_text'],
          reference: lectioSource['reference'],
          audioUrl: lectioSource['audio_url'],
          cachedAt: DateTime.now(),
          rawLectioSource: lectioSource,
        );
        await LectioCacheService.instance.cacheLectio(cachedData);
      } else {
        appLogger.e('❌ Lectio source neexistuje pre žiadny jazyk');
      }

      if (mounted) {
        setState(() {
          lectioData = lectioSource;
          isLoading = false;
        });
        _invalidateTracksCache();
      }
    } catch (e) {
      appLogger.e('❌ Chyba pri načítavaní Lectio dát: $e');

      // Ak je to sieťová chyba, označ ako offline
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('network') ||
          errorStr.contains('clientexception')) {
        ConnectivityService.instance.markOffline();
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }

      // Pri chybe skús načítať z cache
      final cachedData = await LectioCacheService.instance.getCachedLectio(
        today,
        lang,
      );
      if (cachedData != null && mounted) {
        appLogger.i('📦 Fallback na cache po chybe');
        setState(() {
          lectioData = cachedData.rawData;
          isLoading = false;
        });
        _invalidateTracksCache();
        return;
      }
      if (mounted) {
        setState(() {
          lectioData = null;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedBible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Hodnota je priamo názov stĺpca: biblia_1, biblia_2 alebo biblia_3
      String selectedBible = prefs.getString('selectedBible') ?? 'biblia_1';

      // Komplexná migrácia starých hodnôt na nový formát
      selectedBible = _migrateBibleValue(selectedBible);
      await prefs.setString('selectedBible', selectedBible);

      _selectedBible = selectedBible;
      _audioMode = prefs.getString('audioMode') ?? 'short';

      if (mounted) {
        setState(() {});
        _invalidateTracksCache();
      }
    } catch (e) {
      debugPrint('Error loading selected bible: $e');
      if (mounted) {
        setState(() {
          _selectedBible = 'biblia_1';
          _audioMode = 'short';
        });
        _invalidateTracksCache();
      }
    }
  }

  // Migruje starú hodnotu na nový formát (biblia_1, biblia_2, biblia_3)
  String _migrateBibleValue(String oldValue) {
    // Ak je už v správnom formáte, vráť ho
    if (oldValue == 'biblia_1' ||
        oldValue == 'biblia_2' ||
        oldValue == 'biblia_3') {
      return oldValue;
    }

    // Migrácia zo starých formátov
    switch (oldValue.toLowerCase()) {
      // Starý formát bez podčiarkovníka
      case 'biblia1':
      case 'bible_en_1':
        return 'biblia_1';

      case 'biblia2':
      case 'bible_en_2':
        return 'biblia_2';

      case 'biblia3':
      case 'bible_en_3':
        return 'biblia_3';

      // Databázové kódy
      case 'ssv':
      case 'standardny':
        return 'biblia_1';

      case 'jeruzalemsky':
      case 'jeruzalem':
        return 'biblia_2';

      case 'ekumenicky':
      case 'ekumen':
        return 'biblia_3';

      default:
        // Fallback na prvú bibliu
        return 'biblia_1';
    }
  }

  Future<void> _saveAudioMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audioMode', mode);
    if (mounted) {
      setState(() {
        _audioMode = mode;
      });
    }
  }

  void _invalidateTracksCache() {
    _cachedTracks = null;
    _lastCachedBible = null;
    _lastCachedLectioData = null;
  }

  List<Map<String, dynamic>> _getAvailableAudioTracks() {
    if (lectioData == null) return [];

    // Cache check - ak sa nič nezmenilo, vráť cache (ale refresh localPath)
    if (_cachedTracks != null &&
        _lastCachedBible == _selectedBible &&
        _lastCachedLectioData == lectioData) {
      // Vždy refresh localPath z AudioDownloadService (nie z cache)
      // aby sme mali aktuálny stav po stiahnutí
      for (final track in _cachedTracks!) {
        final url = track['url'] as String?;
        if (url != null) {
          final localPath = _audioDownloadService.getLocalPath(url);
          if (localPath != null) {
            track['localPath'] = localPath;
          } else {
            track.remove('localPath');
          }
        }
      }
      return _cachedTracks!;
    }

    // Použitie LectioAudioTracksBuilder pre generovanie stôp
    final lang = widget.selectedLang ?? context.locale.languageCode;
    final builder = LectioAudioTracksBuilder(
      lectioData: lectioData!,
      selectedBible: _selectedBible,
      languageCode: lang,
    );

    // Konverzia na mapy pre spätnú kompatibilitu
    // + pridanie lokálnych ciest pre offline prehrávanie
    final tracks = builder.build().map((track) {
      final map = track.toMap();
      // Skontroluj či je audio stiahnuté lokálne
      final localPath = _audioDownloadService.getLocalPath(track.url);
      if (localPath != null) {
        map['localPath'] = localPath;
      }
      return map;
    }).toList();

    // Ulož do cache
    _cachedTracks = tracks;
    _lastCachedBible = _selectedBible;
    _lastCachedLectioData = lectioData;

    return tracks;
  }

  Future<void> _playAudio(
    String url,
    String sectionKey, {
    bool skipAnimation = false,
  }) async {
    try {
      appLogger.d('▶️ Prehrávam: $sectionKey');

      // Don't play if user closed the player
      if (_audioPlayerClosed) {
        appLogger.d('🛑 Player was closed by user - skipping playback');
        return;
      }

      // Wait for any in-progress _playAudio to finish first
      if (_isPlayAudioInProgress && _playAudioCompleter != null) {
        appLogger.d('⏳ Čakám na dokončenie predchádzajúceho _playAudio...');
        try {
          await _playAudioCompleter!.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              appLogger.w('⚠️ Timeout čakania na predchádzajúce _playAudio');
            },
          );
        } catch (_) {}
      }

      _isPlayAudioInProgress = true;
      _playAudioCompleter = Completer<void>();

      // Zrušiť fallback subscription PRED zastavením audio
      // aby sa nezachytil "completed" stav pri stop()
      await _fallbackPlayerSubscription?.cancel();
      _fallbackPlayerSubscription = null;

      // Zastaviť aktuálne audio ak beží (oba playery)
      if (_currentAudioSection != null && _currentAudioSection != sectionKey) {
        appLogger.d(
          '🛑 Zastavujem predchádzajúce audio: $_currentAudioSection',
        );
        if (_backgroundAudioManager.isInitialized) {
          // Nepoužívaj stop() - len pause, aby sa nenastavil _isStopped flag
          await _backgroundAudioManager.pause();
        }
        await _audioPlayer.stop();
      }

      if (mounted) {
        appLogger.d('🎵 Nastavujem state pre $sectionKey PRED setUrl');
        setState(() {
          _playbackState = LectioPlaybackState.loading;
          _currentAudioSection = sectionKey;
          _isPlaying = false; // Ešte sa nehraje
          _audioPlayerClosed = false; // Reset flag keď začína nové audio
          _isMinimized = false; // Reset minimalizácie pri novom tracku
          _isPlayingInterlude =
              false; // Reset interlude flag when playing normal track
          // Reset pozície a trvania pre nový track
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
          // Vždy otvor prehrávač pri novom tracku
          _showAudioPlayer = true;
        });
        appLogger.d(
          '🎵 State nastavený: _currentAudioSection=$_currentAudioSection',
        );
      }

      // 🎯 NOVÁ LOGIKA: Animovať HNEĎ pri spustení normálnej nahrávky (nie interlude)
      if (mounted && sectionKey != 'interlude' && !skipAnimation) {
        appLogger.d('🎵 🚀 Animujem HNEĎ pri spustení nahrávky: $sectionKey');
        await Future.delayed(const Duration(milliseconds: 50));

        final tracks = _getAvailableAudioTracks();
        final trackIndex = tracks.indexWhere((t) => t['key'] == sectionKey);
        appLogger.d('🎵 Posúvam na track index: $trackIndex pre $sectionKey');

        if (trackIndex >= 0 && _playlistPageController.hasClients) {
          appLogger.d(
            '🎵 🎯 ANIMUJEM na stránku $trackIndex PRED načítaním audio',
          );
          await _playlistPageController.animateToPage(
            trackIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          appLogger.d('🎵 ✅ Animácia dokončená na stránku $trackIndex');

          // Krátka stabilizácia
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          appLogger.d(
            '🎵 ❌ Nemôžem animovať: trackIndex=$trackIndex, hasClients=${_playlistPageController.hasClients}',
          );
        }
      }

      // Skontroluj lokálny súbor pre offline prehrávanie
      final localPathOrNull = _audioDownloadService.getLocalPath(url);
      final useLocalFile =
          localPathOrNull != null && File(localPathOrNull).existsSync();
      final localPath = localPathOrNull ?? '';

      if (useLocalFile) {
        appLogger.d('🎵 📦 Offline play: $sectionKey z lokálneho súboru');
      }

      // Use background audio service if available, fallback to regular audio player
      if (_backgroundAudioManager.isInitialized) {
        // Zastaviť aj regular audio player pre istotu
        await _audioPlayer.stop();
        // VŽDY posielaj remote URL - playlist building v _playBackgroundAudio
        // už rieši local/remote výber cez _createAudioSource.
        // Posielanie localPath spôsobovalo URL mismatch v play() lookup.
        await _playBackgroundAudio(url, sectionKey);
        appLogger.d('🎵 Background audio started successfully');
      } else {
        // Zastaviť background audio ak beží
        if (_backgroundAudioManager.isInitialized) {
          await _backgroundAudioManager.stop();
        }

        // Použi lokálny súbor alebo streaming
        final audioSource = useLocalFile
            ? AudioSource.file(
                localPath,
                tag: MediaItem(
                  id: sectionKey,
                  album: 'Lectio Divina',
                  title: _getSectionTitle(sectionKey),
                  artist: 'Lectio Divina',
                  artUri: _isOffline
                      ? null
                      : Uri.parse(AudioConstants.defaultArtworkUrl),
                ),
              )
            : AudioSource.uri(
                Uri.parse(url),
                tag: MediaItem(
                  id: sectionKey,
                  album: 'Lectio Divina',
                  title: _getSectionTitle(sectionKey),
                  artist: 'Lectio Divina',
                  artUri: _isOffline
                      ? null
                      : Uri.parse(AudioConstants.defaultArtworkUrl),
                ),
              );
        await _audioPlayer.setAudioSource(audioSource);
        await _audioPlayer.play();
        appLogger.d('🎵 Regular audio player started successfully');
      }

      // State updates will come through listeners
      if (!mounted) {
        appLogger.w('🎵 ❌ Widget not mounted after audio start!');
      }
    } catch (e) {
      appLogger.e('❌ Chyba pri prehrávaní: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepodarilo sa prehrať audio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isPlayAudioInProgress = false;
      _playAudioCompleter?.complete();
      _playAudioCompleter = null;
    }
  }

  Future<void> _pauseAudio() async {
    appLogger.d('⏸️ Pausing audio');
    try {
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.pause();
      } else {
        await _audioPlayer.pause();
      }
      appLogger.d('✅ Pause complete');
    } catch (e) {
      appLogger.e('❌ Error pausing: $e');
    }
  }

  Future<void> _resumeAudio() async {
    appLogger.d('▶️ Resuming audio');
    // Don't resume if another _playAudio is in progress
    if (_isPlayAudioInProgress) {
      appLogger.d('⏳ Skipping resume - _playAudio is in progress');
      return;
    }
    try {
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.resume();
      } else if (_currentAudioSection != null) {
        await _audioPlayer.play();
      } else {
        appLogger.d('⚠️ No audio source to resume');
        return;
      }
      appLogger.d('✅ Resume complete');
    } on PlatformException catch (e) {
      appLogger.e('❌ PlatformException resuming: $e');
      // Player may be in invalid state - try to recover by replaying current track
      if (_currentAudioSection != null && mounted) {
        final tracks = _getAvailableAudioTracks();
        final currentTrack = tracks.firstWhere(
          (t) => t['key'] == _currentAudioSection,
          orElse: () => <String, dynamic>{},
        );
        if (currentTrack.isNotEmpty) {
          appLogger.d('🔄 Recovering - replaying current track');
          await _playAudio(currentTrack['url'], currentTrack['key']);
        }
      }
    } catch (e) {
      appLogger.e('❌ Error resuming: $e');
    }
  }

  Future<void> _seekAudio(Duration position) async {
    appLogger.d('🎚️ Seeking to ${position.inSeconds}s');
    try {
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.seek(position);
      } else {
        await _audioPlayer.seek(position);
      }
      appLogger.d('✅ Seek complete');
    } catch (e) {
      appLogger.e('❌ Error seeking: $e');
    }
  }

  Future<void> _stopAudio() async {
    appLogger.d('🛑 Zastavujem audio, _audioPlayerClosed=$_audioPlayerClosed');

    // Stop both audio players
    if (_backgroundAudioManager.isInitialized) {
      await _backgroundAudioManager.stop();
    }
    await _audioPlayer.stop();

    if (mounted) {
      setState(() {
        _playbackState = LectioPlaybackState.stopped;
        _currentAudioSection = null;
        _nextTrackAfterInterlude = null;
        _isPlaying = false;
        _isPlayingInterlude = false; // Reset interlude flag
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        // NERESET _audioPlayerClosed tu - to sa robí inde
        _isProcessingInterludeCompletion =
            false; // Reset interlude processing flag
      });
    }
  }

  Future<void> _playNextTrack() async {
    appLogger.d('🎵 === _playNextTrack START ===');
    appLogger.d('🎵 _currentAudioSection: $_currentAudioSection');
    appLogger.d('🎵 _audioPlayerClosed: $_audioPlayerClosed');

    if (_currentAudioSection == null) {
      appLogger.d('🛑 Skipping _playNextTrack - invalid section');
      return;
    }

    final tracks = _getAvailableAudioTracks();
    appLogger.d('🎵 Total tracks available: ${tracks.length}');

    final currentIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );
    appLogger.d('🎵 Current track index: $currentIndex');

    if (currentIndex == -1) {
      appLogger.w('⚠️ Track not found in list');
      return;
    }

    // Is there a next track?
    final hasNext = currentIndex < tracks.length - 1;
    appLogger.d('🎵 Has next track: $hasNext');

    if (!hasNext) {
      // Last track - wait before final meditation
      appLogger.d('🎵 ⏳ Last track - waiting 500ms before final meditation');
      await Future.delayed(const Duration(milliseconds: 500));

      if (_audioMode != 'none') {
        appLogger.d('🎵 Starting final meditation music (no next track)');
        _playMeditationMusic(null); // No next track
      } else {
        appLogger.d('🛑 Audio mode is none - stopping playback');
        _stopAudio();
      }
      return;
    }

    // We have next track - wait before interlude
    final nextTrack = tracks[currentIndex + 1];
    appLogger.d('🎵 Next track: ${nextTrack['key']} - ${nextTrack['label']}');
    appLogger.d('🎵 ⏳ Waiting 500ms before interlude');
    await Future.delayed(const Duration(milliseconds: 500));

    if (_audioMode != 'none') {
      // Play meditation → then nextTrack
      appLogger.d('🎵 Starting interlude music before next track');
      _playMeditationMusic(nextTrack);
    } else {
      // Play nextTrack directly - WITHOUT animation (automatic transition)
      appLogger.d('🎵 Playing next track directly (no interlude)');
      _playAudio(nextTrack['url'], nextTrack['key'], skipAnimation: true);
    }

    appLogger.d('🎵 === _playNextTrack END ===');
  }

  Future<void> _playMeditationMusic(Map<String, dynamic>? nextTrack) async {
    // Vyber správnu meditačnú hudbu
    final bool useLongInterlude;
    if (_audioMode == 'short') {
      // Short: pre contemplatio alebo actio → dlhá, inak krátka
      useLongInterlude =
          _currentAudioSection == 'contemplatio_audio' || nextTrack == null;
    } else {
      // Long: vždy dlhá meditácia
      useLongInterlude = true;
    }
    final url = AudioConstants.getInterludeUrl(isLong: useLongInterlude);

    try {
      _nextTrackAfterInterlude = nextTrack; // Ulož ďalší track (alebo null)

      // Odlišné čakanie pre krátke vs dlhé interlude
      final delay = useLongInterlude
          ? AudioTimingConstants.longInterludeDelay
          : AudioTimingConstants.shortInterludeDelay;

      appLogger.d(
        '🎵 ⏳ Čakám ${delay}ms pred spustením ${useLongInterlude ? "DLHÉHO" : "KRÁTKEHO"} interlude',
      );
      await Future.delayed(Duration(milliseconds: delay));

      // Set state BEFORE playing to ensure listener sees correct section
      if (mounted) {
        setState(() {
          _playbackState = LectioPlaybackState.playingInterlude;
          _isPlayingInterlude = true; // Set interlude flag for UI
          _isPlaying = true;
        });
        appLogger.d(
          '🎵 🎸 Interlude state nastavený PRED spustením (${useLongInterlude ? "DLHÉ" : "KRÁTKE"})',
        );
      }

      final interludeTitle = useLongInterlude
          ? 'Meditačná hudba (dlhá)'
          : 'Meditačná hudba';
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: 'interlude',
            album: 'Lectio Divina',
            title: interludeTitle,
            artist: 'Meditácia',
            artUri: _isOffline
                ? null
                : Uri.parse(AudioConstants.defaultArtworkUrl),
          ),
        ),
      );
      await _audioPlayer.play();

      appLogger.d('🎵 ✅ Interlude audio spustené');
    } catch (e) {
      appLogger.e('❌ Meditácia zlyhala: $e');
      _nextTrackAfterInterlude = null;
      if (nextTrack != null) {
        _playAudio(nextTrack['url'], nextTrack['key'], skipAnimation: true);
      } else {
        _stopAudio();
      }
    }
  }

  Future<void> _playPreviousTrack() async {
    final tracks = _getAvailableAudioTracks();
    if (tracks.isEmpty) return;

    // Ak je interlude, vráť sa na aktuálnu nahrávku (nie predchádzajúcu)
    if (_isPlayingInterlude) {
      _nextTrackAfterInterlude = null;
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.stop();
      } else {
        await _audioPlayer.stop();
      }
      // Vráť sa na aktuálny track (pred interlude)
      final currentIndex = tracks.indexWhere(
        (t) => t['key'] == _currentAudioSection,
      );
      final trackToPlay = currentIndex >= 0 ? tracks[currentIndex] : tracks[0];
      appLogger.d(
        '🎵 Interlude stopped, returning to track: ${trackToPlay['key']}',
      );
      await _playAudio(trackToPlay['url'], trackToPlay['key']);
      return;
    }

    if (_currentAudioSection == null) {
      // Ak nič nehrá, začni od prvého tracku
      if (tracks.isNotEmpty) {
        await _playAudio(tracks[0]['url'], tracks[0]['key']);
      }
      return;
    }

    final currentIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );

    // Ak sme na začiatku alebo pozícia > 3 sekundy, seekni na začiatok
    if (currentIndex <= 0 || _currentPosition.inSeconds > 3) {
      appLogger.d('🎵 Seeking to beginning of current track');
      await _seekAudio(Duration.zero);
      setState(() {
        _currentPosition = Duration.zero;
      });
      return;
    }

    // Inak prehraj predchádzajúcu stopu
    final previousTrack = tracks[currentIndex - 1];
    appLogger.d('🎵 Playing previous track: ${previousTrack['key']}');
    await _playAudio(previousTrack['url'], previousTrack['key']);
  }

  Widget _buildSection({
    required String? title,
    String subtitle = '',
    required String text,
    String? reference,
  }) {
    return LectioSectionCard(
      title: title,
      subtitle: subtitle,
      text: text,
      reference: reference,
    );
  }

  void _goToPreviousDay() {
    if (!DateLimitsConfig.canGoToPreviousDay(selectedDate)) {
      return; // Nedovoľ ísť mimo povolený rozsah
    }
    setState(
      () => selectedDate = selectedDate.subtract(const Duration(days: 1)),
    );
    fetchLectioData();
  }

  void _goToNextDay() {
    if (!DateLimitsConfig.canGoToNextDay(selectedDate)) {
      return; // Nedovoľ ísť mimo povolený rozsah
    }
    setState(() => selectedDate = selectedDate.add(const Duration(days: 1)));
    fetchLectioData();
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateLimitsConfig.getMinDate(),
      lastDate: DateLimitsConfig.getMaxDate(),
      locale: context.locale,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchLectioData();
    }
  }

  Future<void> _handleDndToggle() async {
    final dndHelper = DndHelper(
      dndService: _dndService,
      context: context,
      onStateChanged: (isDndActive) {
        setState(() {
          _isDndActive = isDndActive;
        });
      },
    );
    await dndHelper.handleDndToggle();
  }

  void _handleAddNote() {
    if (lectioData == null) return;
    // Použij dynamický stĺpec podľa vybranej biblie
    String bibleReference = lectioData?[_selectedBible] ?? '';

    final now = DateTime.now();
    final formattedDate = DateFormat('d.M.yyyy').format(now);

    final noteData = {
      'id': null,
      'title': formattedDate,
      'content': '',
      'bible_reference': lectioData?['suradnice_pismo'] ?? '',
      'bible_quote': bibleReference,
    };

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteDetailScreen(note: noteData)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat(
      'dd.MM.yyyy',
      context.locale.toString(),
    ).format(selectedDate);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => _prayerFocusService.onUserInteraction(),
        onPanDown: (_) => _prayerFocusService.onUserInteraction(),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    theme.scaffoldBackgroundColor,
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  // Hero SliverAppBar s obrázkom
                  SliverAppBar(
                    expandedHeight: MediaQuery.of(context).size.width >= 600
                        ? 450.0
                        : 300.0,
                    floating: false,
                    pinned: true,
                    centerTitle:
                        true, // Vycentruje títul na všetkých platformách
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    actions: [
                      // DND Status Indicator
                      StreamBuilder<bool>(
                        stream: DoNotDisturbService().dndStateStream,
                        initialData: DoNotDisturbService().isDndActive,
                        builder: (context, snapshot) {
                          final isDndActive = snapshot.data ?? false;

                          return AnimatedOpacity(
                            opacity: isDndActive ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              margin: const EdgeInsets.only(
                                right: AppSpacing.sm,
                                top: AppSpacing.sm,
                                bottom: AppSpacing.sm,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.do_not_disturb_on_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('do_not_disturb_active'),
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Offline Status Indicator - úplne vpravo
                      if (_isOffline)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.lg),
                          child: Tooltip(
                            message: tr('offline.offline_mode'),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.cloud_off_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: EdgeInsets.fromLTRB(
                        72,
                        16,
                        72,
                        MediaQuery.of(context).size.width >= 600 ? 24 : 16,
                      ),
                      title: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          "Lectio Divina",
                          style:
                              (MediaQuery.of(context).size.width >= 600
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.titleMedium)!
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Background image
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/lectio_header.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(),
                              ),
                            ),
                            // Gradient overlay
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.primaryOverlay,
                                      AppColors.primary,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // Date badge
                            Positioned(
                              top: 120,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  formattedDate,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Date Navigation Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.cardColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withValues(alpha: 0.07),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: tr("previous_day"),
                              icon: Icon(
                                Icons.chevron_left,
                                size: 32,
                                color:
                                    DateLimitsConfig.canGoToPreviousDay(
                                      selectedDate,
                                    )
                                    ? null
                                    : Colors.grey.shade300,
                              ),
                              onPressed:
                                  DateLimitsConfig.canGoToPreviousDay(
                                    selectedDate,
                                  )
                                  ? _goToPreviousDay
                                  : null,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _showDatePicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        formattedDate,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: tr("next_day"),
                              icon: Icon(
                                Icons.chevron_right,
                                size: 32,
                                color:
                                    DateLimitsConfig.canGoToNextDay(
                                      selectedDate,
                                    )
                                    ? null
                                    : Colors.grey.shade300,
                              ),
                              onPressed:
                                  DateLimitsConfig.canGoToNextDay(selectedDate)
                                  ? _goToNextDay
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Divider(height: 1, color: theme.dividerColor),
                  ),

                  // Audio download progress indicator
                  if (_isDownloadingAudio)
                    SliverToBoxAdapter(
                      child: AudioDownloadProgress(
                        progress: _audioDownloadProgress,
                        currentTrack: _audioDownloadCurrent,
                        totalTracks: _audioDownloadTotal,
                      ),
                    ),

                  // Offline audio banner
                  if (!_isDownloadingAudio && lectioData != null)
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final tracks = _getAvailableAudioTracks();
                          final downloadedCount = tracks
                              .where((t) => t['localPath'] != null)
                              .length;
                          if (downloadedCount == 0) {
                            return const SizedBox.shrink();
                          }
                          return OfflineAudioBanner(
                            downloadedTracks: downloadedCount,
                            totalTracks: tracks.length,
                            onManageTap: _showStorageManagement,
                          );
                        },
                      ),
                    ),

                  // Main Content
                  SliverToBoxAdapter(
                    child: isLoading
                        ? const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : lectioData == null
                        ? SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    tr("lectio_not_available"),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Title and Bible Reference
                              if ((lectioData?['hlava'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.lg,
                                  ),
                                  child: Center(
                                    child: Text(
                                      lectioData?['hlava'] ?? '',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if ((lectioData?['suradnice_pismo'] ?? '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.xs,
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Center(
                                    child: Text(
                                      lectioData?['suradnice_pismo'] ?? '',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ),
                                ),

                              // Biblický text podľa vybranej biblie
                              if (lectioData?[_selectedBible] != null &&
                                  (lectioData?[_selectedBible] ?? '')
                                      .isNotEmpty)
                                _buildSection(
                                  title: lectioData?['nazov_$_selectedBible'],
                                  text: lectioData?[_selectedBible] ?? '',
                                ),

                              // Lectio Divina sekcie
                              _buildSection(
                                title: "LECTIO",
                                subtitle: tr("l_commenter"),
                                text: lectioData?['lectio_text'] ?? '',
                              ),
                              _buildSection(
                                title: "MEDITATIO",
                                subtitle: tr("l_meditatio"),
                                text: lectioData?['meditatio_text'] ?? '',
                              ),
                              _buildSection(
                                title: "ORATIO",
                                subtitle: tr("l_oratio"),
                                text: lectioData?['oratio_text'] ?? '',
                              ),
                              _buildSection(
                                title: "CONTEMPLATIO",
                                subtitle: tr("l_contemplatio"),
                                text: lectioData?['contemplatio_text'] ?? '',
                              ),
                              _buildSection(
                                title: "ACTIO",
                                subtitle: tr("l_actio"),
                                text: lectioData?['actio_text'] ?? '',
                                reference: lectioData?['reference'],
                              ),
                              SizedBox(
                                height:
                                    120 +
                                    MediaQuery.of(context).viewPadding.bottom,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // Floating Audio Player
            if (_showAudioPlayer && _getAvailableAudioTracks().isNotEmpty)
              _buildFloatingAudioPlayerWidget(),

            // Prayer Focus Mode Indicator
            const PrayerFocusIndicator(),
          ], // Stack children
        ), // Stack
      ), // GestureDetector
      // Floating Action Button Menu
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: AppSpacing.xl + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: LectioSpeedDialFAB(
          onAddNote: Supabase.instance.client.auth.currentUser != null
              ? _handleAddNote
              : null,
          onDndToggle: _dndEnabled ? _handleDndToggle : null,
          onAudioToggle: _getAvailableAudioTracks().isNotEmpty
              ? () {
                  setState(() {
                    _showAudioPlayer = !_showAudioPlayer;
                  });
                }
              : null,
          onDownload: _showDownloadDialog,
          onRefresh: fetchLectioData,
          isDndActive: _isDndActive,
          hasAudio: _getAvailableAudioTracks().isNotEmpty,
          showAudioPlayer: _showAudioPlayer,
          dndEnabled: _dndEnabled,
          isOffline: _isOffline,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    ); // Scaffold
  }

  Widget _buildFloatingAudioPlayerWidget() {
    final tracks = _getAvailableAudioTracks();
    final currentTrackIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );

    return LectioFloatingAudioPlayer(
      tracks: tracks,
      currentAudioSection: _currentAudioSection,
      isPlaying: _isPlaying,
      isPlayingInterlude: _isPlayingInterlude,
      isMinimized: _isMinimized,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      audioMode: _audioMode,
      playlistPageController: _playlistPageController,
      onPlayPause: () {
        if (_isPlaying) {
          _pauseAudio();
        } else if (_currentAudioSection != null) {
          _resumeAudio();
        } else {
          _audioPlayerClosed = false;
          final firstTrack = tracks.isNotEmpty ? tracks[0] : null;
          if (firstTrack != null) {
            _playAudio(firstTrack['url'], firstTrack['key']);
          }
        }
      },
      onSkipPrevious: _currentAudioSection != null || _isPlayingInterlude
          ? () async {
              // Debounce: ignore if pressed within 500ms
              final now = DateTime.now();
              if (_lastSkipTime != null &&
                  now.difference(_lastSkipTime!) <
                      const Duration(milliseconds: 500)) {
                appLogger.d('⏳ Skip Previous debounced');
                return;
              }
              _lastSkipTime = now;
              appLogger.d('🎮 Skip Previous button pressed');
              if (_isPlayingInterlude) {
                _nextTrackAfterInterlude = null;
                setState(() {
                  _isPlayingInterlude = false;
                });
                final currentIndex = tracks.indexWhere(
                  (t) => t['key'] == _currentAudioSection,
                );
                final trackToPlay = currentIndex >= 0
                    ? tracks[currentIndex]
                    : tracks[0];
                await _playAudio(trackToPlay['url'], trackToPlay['key']);
              } else {
                await _playPreviousTrack();
              }
            }
          : null,
      onSkipNext:
          (_currentAudioSection != null || _isPlayingInterlude) &&
              (currentTrackIndex < tracks.length - 1 || _isPlayingInterlude)
          ? () async {
              // Debounce: ignore if pressed within 500ms
              final now = DateTime.now();
              if (_lastSkipTime != null &&
                  now.difference(_lastSkipTime!) <
                      const Duration(milliseconds: 500)) {
                appLogger.d('⏳ Skip Next debounced');
                return;
              }
              _lastSkipTime = now;
              appLogger.d('🎮 Skip Next button pressed');
              if (_isPlayingInterlude) {
                final nextTrack = _nextTrackAfterInterlude;
                _nextTrackAfterInterlude = null;
                setState(() {
                  _isPlayingInterlude = false;
                });
                if (nextTrack != null) {
                  await _playAudio(nextTrack['url'], nextTrack['key']);
                }
                return;
              }
              final nextIndex = currentTrackIndex + 1;
              if (nextIndex < tracks.length) {
                final nextTrack = tracks[nextIndex];
                await _playAudio(nextTrack['url'], nextTrack['key']);
              }
            }
          : null,
      onSeekStart: () {
        _setPlaybackState(LectioPlaybackState.seeking);
        appLogger.d('🎚️ Seek started');
      },
      onSeekChanged: (position) {
        setState(() {
          _currentPosition = position;
        });
      },
      onSeekEnd: (value) async {
        final position = Duration(milliseconds: value.toInt());
        appLogger.d('🎚️ Seek ended at ${position.inSeconds}s');
        await _seekAudio(position);
        await Future.delayed(const Duration(milliseconds: 300));
        _setPlaybackState(
          _isPlaying ? LectioPlaybackState.playing : LectioPlaybackState.paused,
        );
        appLogger.d('🎚️ Seek flag reset');
      },
      onPlayTrack: (url, key) {
        _audioPlayerClosed = false;
        _playAudio(url, key);
      },
      onAudioModeChanged: _saveAudioMode,
      onMinimize: () {
        setState(() {
          _isMinimized = !_isMinimized;
        });
      },
      onClose: () async {
        appLogger.d('🔒 Zatváram prehrávač');
        _audioPlayerClosed = true;
        await _fallbackPlayerSubscription?.cancel();
        _fallbackPlayerSubscription = null;
        await _stopAudio();
        if (mounted) {
          setState(() {
            _showAudioPlayer = false;
          });
        }
      },
    );
  }
}

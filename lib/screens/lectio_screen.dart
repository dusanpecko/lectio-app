import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lectio_audio_state.dart';
import '../models/lectio_audio_track.dart';
import '../services/background_audio_manager.dart';
import '../services/connectivity_service.dart';
import '../services/lectio_cache_service.dart';
import '../shared/audio_constants.dart';
import '../services/do_not_disturb_service.dart';
import '../services/prayer_focus_service.dart';
import '../shared/app_colors.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../widgets/lectio_section_card.dart';
import '../widgets/lectio_speed_dial_fab.dart';
import '../widgets/prayer_focus_indicator.dart';
import 'note_detail_screen.dart';

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

  Map<String, dynamic>? lectioData;
  bool isLoading = true;
  bool _dataLoaded = false;
  DateTime selectedDate = DateTime.now();
  String _selectedBible = 'biblia1';

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

  // Do Not Disturb state
  bool _isDndActive = false;
  bool _dndEnabled = false;

  // Offline mode state
  bool _isDownloading = false;
  int _downloadedDays = 0;
  int _totalDaysToDownload = 7;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

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
    _setupAudioListeners();
    _initializeDndService();
    _initializeBackgroundAudio();
    _startPositionTimer();
    _initializeConnectivity();

    // Callback sa zaregistruje v _playBackgroundAudio po inicializácii

    // Notifikuj Prayer Focus Service o vstupe do Lectio screen
    _prayerFocusService.onSpiritualScreenEntered(SpiritualScreen.lectio);
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

            if (item.duration != null && _currentAudioSection != 'interlude') {
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

      // 🎯 NOVÁ LOGIKA: Nastaviť playlist do BackgroundAudioManager
      // Toto umožňuje pokračovanie v background aj keď widget nie je mounted
      final tracks = _getAvailableAudioTracks();
      final currentIndex = tracks.indexWhere((t) => t['key'] == sectionKey);

      // Nastaviť playlist a audio mode (NOW ASYNC)
      await _backgroundAudioManager.setPlaylist(tracks, _audioMode);
      if (currentIndex >= 0) {
        // Nastaviť current index manuálne (nie cez playTrackByIndex aby sa neprehral znova)
        appLogger.d(
          '🎵 Setting playlist with ${tracks.length} tracks, current: $currentIndex',
        );
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
              _currentAudioSection = 'interlude';
            } else if (index >= 0 && index < tracks.length) {
              _currentAudioSection = tracks[index]['key'];
              // Animovať na nový track
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

      // Callback keď sa playlist dokončí
      _backgroundAudioManager.setOnPlaylistCompleted(() {
        appLogger.d('🎵 Playlist completed');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentAudioSection = null;
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
      // Fallback to regular audio player
      _usingFallbackPlayer = true;
      appLogger.d(
        '🎵 🔄 Using fallback player, _usingFallbackPlayer=$_usingFallbackPlayer',
      );

      // Zrušiť predchádzajúcu subscription ak existuje
      await _fallbackPlayerSubscription?.cancel();
      _fallbackPlayerSubscription = null;
      appLogger.d('🎵 Previous fallback subscription cancelled');

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: sectionKey,
            album: 'Lectio Divina',
            title: _getSectionTitle(sectionKey),
            artist: 'Lectio Divina',
            artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
          ),
        ),
      );
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
            _currentAudioSection != 'interlude') {
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

      // Debug výpis každú sekundu
      if (position.inMilliseconds % 1000 < 250) {
        appLogger.d(
          '🎵 Timer update: pos=${position.inSeconds}s, dur=${duration?.inSeconds}s, playing=$isPlaying, _isPlaying=$_isPlaying',
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
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.download_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              tr('offline.download_for_offline'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('offline.download_description'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadLectioForDays(7);
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(tr('offline.download_days', args: ['7'])),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('common.cancel')),
            ),
          ],
        ),
      ),
    );
  }

  /// Stiahne Lectio pre zadaný počet dní
  Future<void> _downloadLectioForDays(int days) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadedDays = 0;
      _totalDaysToDownload = days;
    });

    try {
      final locale = context.locale.languageCode;
      final result = await LectioCacheService.instance.downloadLectioForDays(
        locale: locale,
        days: days,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _downloadedDays = current;
              _totalDaysToDownload = total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'offline.download_complete',
                args: ['${result.downloadedDays}'],
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      appLogger.e('❌ Download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('offline.download_error')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        _currentAudioSection == 'interlude') {
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
      } else if (_currentAudioSection == 'interlude' &&
          _nextTrackAfterInterlude == null) {
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
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedBible = prefs.getString('selectedBible') ?? 'biblia1';
        _audioMode = prefs.getString('audioMode') ?? 'short';
      });
      _invalidateTracksCache();
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

    // Cache check - ak sa nič nezmenilo, vráť cache
    if (_cachedTracks != null &&
        _lastCachedBible == _selectedBible &&
        _lastCachedLectioData == lectioData) {
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
    final tracks = builder.build().map((track) => track.toMap()).toList();

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
          await _backgroundAudioManager.stop();
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

      // Use background audio service if available, fallback to regular audio player
      if (_backgroundAudioManager.isInitialized) {
        // Zastaviť aj regular audio player pre istotu
        await _audioPlayer.stop();
        await _playBackgroundAudio(url, sectionKey);
        appLogger.d('🎵 Background audio started successfully');
      } else {
        // Zastaviť background audio ak beží
        if (_backgroundAudioManager.isInitialized) {
          await _backgroundAudioManager.stop();
        }
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: sectionKey,
              album: 'Lectio Divina',
              title: _getSectionTitle(sectionKey),
              artist: 'Lectio Divina',
              artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
            ),
          ),
        );
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
    try {
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.resume();
      } else {
        await _audioPlayer.play();
      }
      appLogger.d('✅ Resume complete');
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

    if (_currentAudioSection == null || _currentAudioSection == 'interlude') {
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
          _currentAudioSection = 'interlude';
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
            artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
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
    if (_currentAudioSection == 'interlude') {
      _nextTrackAfterInterlude = null;
      if (_backgroundAudioManager.isInitialized) {
        await _backgroundAudioManager.stop();
      } else {
        await _audioPlayer.stop();
      }
      // Nájdi posledne hraný track pred interlude
      // Keďže nevieme presne ktorý to bol, vrátime sa na začiatok playlistu
      appLogger.d('🎵 Interlude stopped, returning to first track');
      if (tracks.isNotEmpty) {
        await _playAudio(tracks[0]['url'], tracks[0]['key']);
      }
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getNowPlayingTitle() {
    if (_currentAudioSection == 'interlude') {
      return 'Meditačná hudba';
    }

    // Nájdi aktuálny track
    final tracks = _getAvailableAudioTracks();
    final currentTrack = tracks.firstWhere(
      (t) => t['key'] == _currentAudioSection,
      orElse: () => {'label': 'Audio'},
    );

    return currentTrack['label'] ?? 'Audio';
  }

  Widget _buildAudioModeIconButton(
    String mode,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _audioMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveAudioMode(mode),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade600,
            size: 28,
          ),
        ),
      ),
    );
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
    try {
      if (_isDndActive) {
        // Deaktivácia DND
        await _dndService.deactivateDndManually();
      } else {
        // Aktivácia DND
        final hasPermissions = await _dndService.checkPermissions();

        if (!hasPermissions) {
          // Požiadaj o povolenia
          final granted = await _dndService.requestPermissions();
          if (!granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pre aktiváciu Nerušiť je potrebné povoliť prístup k notifikáciám',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }

        // Aktivuj DND manuálne
        await _dndService.activateDndManually();
      }

      // Aktualizuj UI stav podľa skutočného stavu service
      setState(() {
        _isDndActive = _dndService.isDndActive;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.do_not_disturb_on, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isIOS
                        ? 'Zapnite "Nerušiť" manuálne v Control Center'
                        : 'Režim Nerušiť aktivovaný',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: Platform.isIOS
                ? SnackBarAction(
                    label: 'Ako na to',
                    textColor: Colors.white,
                    onPressed: () => _showIOSDndInstructions(),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      // Chyba pri toggle DND
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri prepínaní režimu Nerušiť: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showIOSDndInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shortcut_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('iOS Shortcuts pre DND'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Automatické riešenie',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vytvorte si iOS Shortcuts pre automatické zapínanie/vypínanie Focus režimu pri používaní DND tlačidla.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildInstructionStep(
                '1',
                'Vytvorte Shortcuts',
                'Nastavenia → Vytvorte Shortcuts pre DND',
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                '2',
                'Použite DND tlačidlo',
                'Shortcuts sa spustia automaticky',
              ),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 12),

              Text(
                'Manuálne riešenie:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                'A',
                'Control Center',
                'Potiahnite zhora doprava → 🌙',
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                'B',
                'Focus režim',
                'Nastavenia → Focus → Do Not Disturb',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Nastavenia'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleAddNote() {
    if (lectioData == null) return;
    String bibleReference = '';
    if (_selectedBible == 'biblia1') {
      bibleReference = lectioData?['biblia_1'] ?? '';
    } else if (_selectedBible == 'biblia2') {
      bibleReference = lectioData?['biblia_2'] ?? '';
    } else if (_selectedBible == 'biblia3') {
      bibleReference = lectioData?['biblia_3'] ?? '';
    }

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
                    expandedHeight: 250,
                    floating: false,
                    pinned: true,
                    centerTitle:
                        true, // Vycentruje títul na všetkých platformách
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    actions: [
                      // Download button pre offline mód (zobrazí sa len keď sme online)
                      if (!_isOffline)
                        IconButton(
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    value: _totalDaysToDownload > 0
                                        ? _downloadedDays / _totalDaysToDownload
                                        : null,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          tooltip: tr('offline.download_days', args: ['7']),
                          onPressed: _isDownloading
                              ? null
                              : _showDownloadDialog,
                        ),
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
                                right: 16,
                                top: 8,
                                bottom: 8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(
                        72,
                        16,
                        72,
                        16,
                      ), // Viac priestoru pre centrálne zarovnanie
                      title: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "Lectio Divina",
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, Color(0xFF6B73A8)],
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
                                      Color(0x4D4A5085),
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
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
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
                          borderRadius: BorderRadius.circular(18),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
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
                                  const SizedBox(height: 16),
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
                                  padding: const EdgeInsets.only(top: 16.0),
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
                                    top: 4,
                                    bottom: 8,
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

                              // Biblický text podľa vybranej biblie (rovnako pre SK aj EN)
                              if (_selectedBible == 'biblia1' ||
                                  _selectedBible == 'bible_en_1')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_1'],
                                  text: lectioData?['biblia_1'] ?? '',
                                ),
                              if (_selectedBible == 'biblia2' ||
                                  _selectedBible == 'bible_en_2')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_2'],
                                  text: lectioData?['biblia_2'] ?? '',
                                ),
                              if (_selectedBible == 'biblia3' ||
                                  _selectedBible == 'bible_en_3')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_3'],
                                  text: lectioData?['biblia_3'] ?? '',
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
                              const SizedBox(height: 40),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // Floating Audio Player
            if (_showAudioPlayer && _getAvailableAudioTracks().isNotEmpty)
              _buildFloatingAudioPlayer(theme),

            // Prayer Focus Mode Indicator
            const PrayerFocusIndicator(),
          ], // Stack children
        ), // Stack
      ), // GestureDetector
      // Floating Action Button Menu
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
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
          onRefresh: fetchLectioData,
          isDndActive: _isDndActive,
          hasAudio: _getAvailableAudioTracks().isNotEmpty,
          showAudioPlayer: _showAudioPlayer,
          dndEnabled: _dndEnabled,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    ); // Scaffold
  }

  Widget _buildFloatingAudioPlayer(ThemeData theme) {
    final tracks = _getAvailableAudioTracks();
    final currentTrackIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );

    // Zobraz current track alebo interlude
    final currentTrack = currentTrackIndex >= 0
        ? tracks[currentTrackIndex]
        : null;

    // ============================================
    // MINIMALIZOVANÝ REŽIM - Kruh na ľavej strane
    // ============================================
    if (_isMinimized) {
      return Positioned(
        bottom: 20, // Zarovnané s FAB na pravej strane
        left: 16,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isMinimized = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                if (_totalDuration.inMilliseconds > 0)
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value:
                          _currentPosition.inMilliseconds /
                          _totalDuration.inMilliseconds,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                // Play/Pause icon
                Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                // Pulsing animation when playing
                if (_isPlaying) Positioned.fill(child: _PulsingCircle()),
              ],
            ),
          ),
        ),
      );
    }

    // ============================================
    // PLNÝ PREHRÁVAČ
    // ============================================
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audio prehrávač',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minimize button
                      IconButton(
                        icon: const Icon(
                          Icons.remove_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Minimalizovať',
                        onPressed: () {
                          setState(() {
                            _isMinimized = true;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      // Close button
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Zatvoriť a zastaviť',
                        onPressed: () async {
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
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Plný obsah prehrávača
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Audio Mode Selector - len ikony v kruhu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAudioModeIconButton('none', Icons.music_off, theme),
                      const SizedBox(width: 12),
                      _buildAudioModeIconButton(
                        'short',
                        Icons.music_note,
                        theme,
                      ),
                      const SizedBox(width: 12),
                      _buildAudioModeIconButton(
                        'long',
                        Icons.queue_music,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Now Playing - s animáciou
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _currentAudioSection != null
                        ? Container(
                            key: ValueKey(_currentAudioSection),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _currentAudioSection == 'interlude'
                                      ? Icons
                                            .spa // Ikona pre meditáciu
                                      : (currentTrack?['icon'] ??
                                            Icons.music_note),
                                  color: _currentAudioSection == 'interlude'
                                      ? Colors.blue.shade300
                                      : (currentTrack?['color'] ??
                                            AppColors.primary),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Práve hrá',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                      Text(
                                        _getNowPlayingTitle(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ), // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        color: _currentAudioSection != null
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        onPressed: _currentAudioSection != null
                            ? _playPreviousTrack
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4A5085,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 32,
                          ),
                          color: Colors.white,
                          onPressed: () {
                            appLogger.d('🎮 HLAVNÉ PLAY tlačidlo stlačené');
                            appLogger.d('🎮 _isPlaying: $_isPlaying');
                            appLogger.d(
                              '🎮 _currentAudioSection: $_currentAudioSection',
                            );
                            appLogger.d(
                              '🎮 _showAudioPlayer: $_showAudioPlayer',
                            );

                            if (_isPlaying) {
                              appLogger.d('🎮 -> Pozastavujem audio');
                              _pauseAudio();
                            } else if (_currentAudioSection != null) {
                              appLogger.d('🎮 -> Obnovujem pozastavené audio');
                              _resumeAudio();
                            } else {
                              appLogger.d('🎮 -> Spúšťam prvú nahrávku');
                              // Reset closed flag - user wants to play again
                              _audioPlayerClosed = false;
                              final tracks = _getAvailableAudioTracks();
                              appLogger.d(
                                '🎮 -> Počet dostupných tracks: ${tracks.length}',
                              );
                              final firstTrack = tracks.isNotEmpty
                                  ? tracks[0]
                                  : null;
                              if (firstTrack != null) {
                                appLogger.d(
                                  '🎮 -> Prvý track: ${firstTrack['key']} - ${firstTrack['label']}',
                                );
                                appLogger.d('🎮 -> URL: ${firstTrack['url']}');
                                _playAudio(
                                  firstTrack['url'],
                                  firstTrack['key'],
                                  // Manuálne spustenie = animovať hneď
                                );
                              } else {
                                appLogger.e(
                                  '🎮 -> CHYBA: Žiaden track k dispozícii!',
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        color:
                            _currentAudioSection != null &&
                                _currentAudioSection != 'interlude' &&
                                currentTrackIndex < tracks.length - 1
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        onPressed:
                            _currentAudioSection != null &&
                                _currentAudioSection != 'interlude' &&
                                currentTrackIndex < tracks.length - 1
                            ? () async {
                                // Manuálne preskočenie - zastaviť aktuálne audio a prehrať ďalšie
                                appLogger.d('🎮 Skip Next button pressed');
                                final nextIndex = currentTrackIndex + 1;
                                if (nextIndex < tracks.length) {
                                  final nextTrack = tracks[nextIndex];
                                  await _playAudio(
                                    nextTrack['url'],
                                    nextTrack['key'],
                                  );
                                }
                              }
                            : null,
                      ),
                    ],
                  ),

                  // Progress bar - zobrazuj vždy
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16.0,
                            ),
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          child: Slider(
                            value: _totalDuration.inMilliseconds > 0
                                ? _currentPosition.inMilliseconds
                                      .toDouble()
                                      .clamp(
                                        0.0,
                                        _totalDuration.inMilliseconds
                                            .toDouble(),
                                      )
                                : 0.0,
                            min: 0.0,
                            max: _totalDuration.inMilliseconds > 0
                                ? _totalDuration.inMilliseconds.toDouble()
                                : 1.0,
                            onChangeStart: _currentAudioSection != null
                                ? (value) {
                                    _setPlaybackState(
                                      LectioPlaybackState.seeking,
                                    );
                                    appLogger.d('🎚️ Seek started');
                                  }
                                : null,
                            onChangeEnd: _currentAudioSection != null
                                ? (value) async {
                                    final position = Duration(
                                      milliseconds: value.toInt(),
                                    );
                                    appLogger.d(
                                      '🎚️ Seek ended at ${position.inSeconds}s',
                                    );
                                    // Seekni na playeri
                                    await _seekAudio(position);
                                    // Počkaj trochu a potom reset flag
                                    await Future.delayed(
                                      const Duration(milliseconds: 300),
                                    );
                                    _setPlaybackState(
                                      _isPlaying
                                          ? LectioPlaybackState.playing
                                          : LectioPlaybackState.paused,
                                    );
                                    appLogger.d('🎚️ Seek flag reset');
                                  }
                                : null,
                            onChanged: _currentAudioSection != null
                                ? (value) {
                                    final position = Duration(
                                      milliseconds: value.toInt(),
                                    );
                                    // Okamžite aktualizuj lokálny stav (len vizuálne)
                                    setState(() {
                                      _currentPosition = position;
                                    });
                                  }
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Playlist - horizontálny swipe
                  Text(
                    'Dostupné nahrávky',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // PageView so swipe
                  SizedBox(
                    height: 70,
                    child: PageView.builder(
                      controller: _playlistPageController,
                      itemCount: tracks.length,
                      onPageChanged: (index) {
                        // Voliteľne môžeme prehrať nahrávku pri manuálnom swipe
                        // final track = tracks[index];
                        // _playAudio(track['url'], track['key']);
                      },
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack =
                            track['key'] == _currentAudioSection;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap: () {
                              // Reset closed flag - user wants to play
                              _audioPlayerClosed = false;
                              _playAudio(
                                track['url'],
                                track['key'],
                                // Priame kliknutie používateľa = animovať hneď (skipAnimation: false)
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                gradient: isCurrentTrack
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isCurrentTrack
                                    ? null
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: isCurrentTrack
                                    ? Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 2,
                                      )
                                    : Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                boxShadow: isCurrentTrack
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // Ikona
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        track['icon'],
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Názov nahrávky + playing indicator
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track['label'],
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  color: isCurrentTrack
                                                      ? AppColors.primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurface,
                                                  fontWeight: isCurrentTrack
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isCurrentTrack && _isPlaying) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(AppColors.primary),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Práve hrá',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Page indicator (dots)
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(tracks.length, (index) {
                      final isCurrentPage =
                          tracks[index]['key'] == _currentAudioSection;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrentPage ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrentPage
                              ? AppColors.primary
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsujúci kruh pre minimalizovaný prehrávač počas prehrávania
class _PulsingCircle extends StatefulWidget {
  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/lectio_audio_state.dart';
import '../models/lectio_audio_track.dart';
import '../services/background_audio_manager.dart';
import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';
import '../shared/audio_player_factory.dart';

/// Jednotný controller pre audio playback v Lectio Divina
///
/// Abstrahuje rozdiel medzi:
/// - BackgroundAudioManager (pre background playback s lock screen controls)
/// - AudioPlayer (pre jednoduchý fallback playback)
///
/// Použitie:
/// ```dart
/// final controller = LectioAudioController();
/// await controller.initialize();
///
/// controller.setPlaylist(tracks, 'short');
/// await controller.playTrack(0);
/// ```
class LectioAudioController extends ChangeNotifier {
  static LectioAudioController? _instance;
  static LectioAudioController get instance =>
      _instance ??= LectioAudioController._internal();

  static void setInstanceForTesting(LectioAudioController instance) {
    _instance = instance;
  }

  factory LectioAudioController() => instance;

  final BackgroundAudioManager _backgroundManager;
  final AudioPlayer _fallbackPlayer;

  LectioAudioController._internal()
    : _backgroundManager = BackgroundAudioManager(),
      _fallbackPlayer = createAppAudioPlayer();

  @visibleForTesting
  LectioAudioController.internal({
    required BackgroundAudioManager manager,
    AudioPlayer? fallbackPlayer,
  }) : _backgroundManager = manager,
       _fallbackPlayer = fallbackPlayer ?? createAppAudioPlayer();

  // State
  LectioPlaybackState _state = LectioPlaybackState.idle;
  List<LectioAudioTrack> _playlist = [];
  int _currentTrackIndex = -1;
  String _audioMode = 'short';
  bool _useFallback = false;
  bool _isPlayingInterlude = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Subscriptions
  StreamSubscription? _fallbackSubscription;
  StreamSubscription? _positionSubscription;

  // Callbacks
  VoidCallback? onPlaylistCompleted;
  Function(String trackKey, int index)? onTrackChanged;

  // Getters
  LectioPlaybackState get state => _state;
  // Pre testovanie a kompatibilitu
  @visibleForTesting
  BackgroundAudioManager get backgroundAudioManager => _backgroundManager;
  LectioPlaybackState get playbackState => _state;

  List<LectioAudioTrack> get playlist => _playlist;
  int get currentTrackIndex => _currentTrackIndex;
  String get audioMode => _audioMode;
  bool get isPlaying => _state == LectioPlaybackState.playing;
  bool get isLoading => _state == LectioPlaybackState.loading;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isPlayingInterlude => _isPlayingInterlude;
  LectioAudioTrack? get currentTrack =>
      _currentTrackIndex >= 0 && _currentTrackIndex < _playlist.length
      ? _playlist[_currentTrackIndex]
      : null;

  // UI State properties
  bool _isPlayerVisible = false;
  bool _isPlayerMinimized = false;

  bool get isPlayerVisible => _isPlayerVisible;
  bool get isPlayerMinimized => _isPlayerMinimized;

  String? get currentAudioSection {
    if (_isPlayingInterlude) return 'interlude';
    if (_currentTrackIndex >= 0 && _currentTrackIndex < _playlist.length) {
      return _playlist[_currentTrackIndex].key;
    }
    return null;
  }

  String get currentTitle {
    if (_isPlayingInterlude) return 'Meditačná hudba';
    if (_currentTrackIndex >= 0 && _currentTrackIndex < _playlist.length) {
      return _playlist[_currentTrackIndex].label;
    }
    return '';
  }

  void setPlayerVisible(bool visible) {
    if (_isPlayerVisible != visible) {
      _isPlayerVisible = visible;
      notifyListeners();
    }
  }

  void setPlayerMinimized(bool minimized) {
    if (_isPlayerMinimized != minimized) {
      _isPlayerMinimized = minimized;
      notifyListeners();
    }
  }

  Future<void> playPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Inicializuje controller
  Future<void> initialize() async {
    try {
      await _backgroundManager.initialize();
      _setupBackgroundCallbacks();
      _setupFallbackListeners();
      appLogger.i('✅ LectioAudioController initialized');
    } catch (e) {
      appLogger.w('⚠️ Background audio failed, using fallback: $e');
      _useFallback = true;
    }
  }

  void _setupBackgroundCallbacks() {
    _backgroundManager.setOnTrackChanged((trackKey, index) {
      _isPlayingInterlude = trackKey == 'interlude';
      if (!_isPlayingInterlude && index >= 0) {
        _currentTrackIndex = index;
      }
      _setState(LectioPlaybackState.playing);
      onTrackChanged?.call(trackKey, index);
    });

    _backgroundManager.setOnPlaylistCompleted(() {
      _setState(LectioPlaybackState.completed);
      onPlaylistCompleted?.call();
    });

    _backgroundManager.setOnSectionCompleted(() {
      _onTrackCompleted();
    });
  }

  void _setupFallbackListeners() {
    _fallbackSubscription = _fallbackPlayer.playerStateStream.listen((state) {
      if (!_useFallback) return;

      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      } else if (state.playing) {
        _setState(LectioPlaybackState.playing);
      } else if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        _setState(LectioPlaybackState.loading);
      }
    });

    _positionSubscription = _fallbackPlayer.positionStream.listen((position) {
      if (_useFallback) {
        _currentPosition = position;
        _totalDuration = _fallbackPlayer.duration ?? Duration.zero;
        notifyListeners();
      }
    });
  }

  /// Nastaví playlist pre prehrávanie
  void setPlaylist(List<LectioAudioTrack> tracks, String audioMode) {
    _playlist = List.from(tracks);
    _audioMode = audioMode;
    _currentTrackIndex = -1;

    // Sync s background manager
    final trackMaps = tracks.map((t) => t.toMap()).toList();
    _backgroundManager.setPlaylist(trackMaps, audioMode);

    appLogger.d('🎵 Playlist set: ${tracks.length} tracks, mode: $audioMode');
  }

  /// Nastaví audio mód (none, short, long)
  void setAudioMode(String mode) {
    _audioMode = mode;
    _backgroundManager.audioMode = mode;
  }

  /// Prehrá stopu podľa indexu
  Future<void> playTrack(int index) async {
    if (index < 0 || index >= _playlist.length) {
      appLogger.e('❌ Invalid track index: $index');
      return;
    }

    _currentTrackIndex = index;
    _isPlayingInterlude = false;
    final track = _playlist[index];

    _setState(LectioPlaybackState.loading);

    try {
      if (_useFallback) {
        await _playWithFallback(track.url, track.label);
      } else {
        _backgroundManager.setCurrentTrackByKey(track.key);
        await _backgroundManager.play(
          track.url,
          title: track.label,
          artist: 'Lectio Divina',
        );
      }
      _setState(LectioPlaybackState.playing);
      onTrackChanged?.call(track.key, index);
    } catch (e) {
      appLogger.e('❌ Error playing track: $e');
      _setState(LectioPlaybackState.error);
    }
  }

  /// Prehrá stopu podľa key
  Future<void> playTrackByKey(String key) async {
    final index = _playlist.indexWhere((t) => t.key == key);
    if (index >= 0) {
      await playTrack(index);
    }
  }

  /// Prehrá interlude hudbu
  Future<void> playInterlude({required bool isLong}) async {
    _isPlayingInterlude = true;
    _setState(LectioPlaybackState.loading);

    try {
      final url = AudioConstants.getInterludeUrl(isLong: isLong);

      if (_useFallback) {
        await _playWithFallback(url, 'Meditačná hudba');
      } else {
        await _backgroundManager.playInterlude(isLong: isLong);
      }

      _setState(LectioPlaybackState.interlude);
      onTrackChanged?.call('interlude', -1);
    } catch (e) {
      appLogger.e('❌ Error playing interlude: $e');
      _setState(LectioPlaybackState.error);
    }
  }

  Future<void> _playWithFallback(String url, String title) async {
    await _fallbackPlayer.setUrl(url);
    await _fallbackPlayer.play();
  }

  /// Pozastaví prehrávanie
  Future<void> pause() async {
    if (_useFallback) {
      await _fallbackPlayer.pause();
    } else {
      await _backgroundManager.pause();
    }
    _setState(LectioPlaybackState.paused);
  }

  /// Obnoví prehrávanie
  Future<void> resume() async {
    if (_useFallback) {
      await _fallbackPlayer.play();
    } else {
      await _backgroundManager.resume();
    }
    _setState(LectioPlaybackState.playing);
  }

  /// Zastaví prehrávanie
  Future<void> stop() async {
    if (_useFallback) {
      await _fallbackPlayer.stop();
    } else {
      await _backgroundManager.stop();
    }
    _currentTrackIndex = -1;
    _isPlayingInterlude = false;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _setState(LectioPlaybackState.stopped);
  }

  /// Seekne na pozíciu
  Future<void> seek(Duration position) async {
    _setState(LectioPlaybackState.seeking);
    if (_useFallback) {
      await _fallbackPlayer.seek(position);
    } else {
      await _backgroundManager.seek(position);
    }
    _currentPosition = position;

    // Delay pre UI update
    await Future.delayed(
      Duration(milliseconds: AudioTimingConstants.seekCompletionDelay),
    );
    if (state == LectioPlaybackState.seeking) {
      _setState(LectioPlaybackState.playing);
    }
  }

  /// Helper pre prehranie zoznamu trackov (pre testy a kompatibilitu)
  Future<void> playTracks(
    List<Map<String, dynamic>> tracks, {
    String? startKey,
  }) async {
    final audioTracks = tracks.map((m) => LectioAudioTrack.fromMap(m)).toList();
    setPlaylist(
      audioTracks,
      'short',
    ); // Default 'short' ak nie je špecifikované

    if (startKey != null) {
      await playTrackByKey(startKey);
    } else if (audioTracks.isNotEmpty) {
      await playTrack(0);
    }
  }

  /// Prehrá ďalšiu stopu
  Future<void> playNext() async {
    if (_currentTrackIndex < _playlist.length - 1) {
      await playTrack(_currentTrackIndex + 1);
    }
  }

  /// Prehrá predchádzajúcu stopu
  Future<void> playPrevious() async {
    if (_currentTrackIndex > 0) {
      await playTrack(_currentTrackIndex - 1);
    }
  }

  /// Aktualizuje pozíciu z externého zdroja (pre UI sync)
  void updatePosition() {
    if (_useFallback) {
      _currentPosition = _fallbackPlayer.position;
      _totalDuration = _fallbackPlayer.duration ?? Duration.zero;
    } else {
      _currentPosition = _backgroundManager.currentPosition;
      _totalDuration = _backgroundManager.totalDuration ?? Duration.zero;
    }
    notifyListeners();
  }

  void _onTrackCompleted() {
    appLogger.d('🏁 Track completed, mode: $_audioMode');

    if (_isPlayingInterlude) {
      // Interlude skončil, hraj ďalšiu stopu
      _isPlayingInterlude = false;
      if (_currentTrackIndex < _playlist.length - 1) {
        playTrack(_currentTrackIndex + 1);
      } else {
        _setState(LectioPlaybackState.completed);
        onPlaylistCompleted?.call();
      }
      return;
    }

    final hasNextTrack = _currentTrackIndex < _playlist.length - 1;

    if (_audioMode == 'none') {
      // Bez interlude
      if (hasNextTrack) {
        playTrack(_currentTrackIndex + 1);
      } else {
        _setState(LectioPlaybackState.completed);
        onPlaylistCompleted?.call();
      }
    } else {
      // S interlude
      final isLong = _audioMode == 'long' || !hasNextTrack;
      playInterlude(isLong: isLong);
    }
  }

  void _setState(LectioPlaybackState newState) {
    if (_state != newState) {
      _state = newState;
      appLogger.d('🎵 State: $newState');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _fallbackSubscription?.cancel();
    _positionSubscription?.cancel();
    _fallbackPlayer.dispose();
    _backgroundManager.clearOnSectionCompleted();
    super.dispose();
  }
}

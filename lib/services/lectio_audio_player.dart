import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../shared/audio_constants.dart';

/// Simple, clean audio player for Lectio Divina
/// Based on working just_audio + audio_session example
class LectioAudioPlayer extends ChangeNotifier {
  static final LectioAudioPlayer _instance = LectioAudioPlayer._internal();
  factory LectioAudioPlayer() => _instance;
  LectioAudioPlayer._internal();

  final AudioPlayer _player = AudioPlayer();

  // State
  bool _isInitialized = false;
  List<Map<String, dynamic>> _playlist = [];
  int _currentTrackIndex = -1;
  String _audioMode = 'short'; // none, short, long
  bool _isPlayingInterlude = false;
  Map<String, dynamic>? _nextTrackAfterInterlude;

  // Callbacks
  VoidCallback? onPlaylistCompleted;
  void Function(String trackKey, int index)? onTrackChanged;

  // Getters
  AudioPlayer get player => _player;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  String? get currentTrackKey =>
      _currentTrackIndex >= 0 && _currentTrackIndex < _playlist.length
      ? _playlist[_currentTrackIndex]['key']
      : (_isPlayingInterlude ? 'interlude' : null);
  int get currentTrackIndex => _currentTrackIndex;
  List<Map<String, dynamic>> get playlist => _playlist;
  String get audioMode => _audioMode;
  bool get isPlayingInterlude => _isPlayingInterlude;

  /// Initialize audio session
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure audio session - CRITICAL for Android
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      debugPrint('🎵 AudioSession configured');

      // Setup player listeners
      _setupListeners();

      _isInitialized = true;
      debugPrint('🎵 LectioAudioPlayer initialized');
    } catch (e) {
      debugPrint('❌ Error initializing LectioAudioPlayer: $e');
      rethrow;
    }
  }

  void _setupListeners() {
    // Position updates
    _player.positionStream.listen((position) {
      notifyListeners();
    });

    // Duration updates
    _player.durationStream.listen((duration) {
      notifyListeners();
    });

    // Player state changes
    _player.playerStateStream.listen((state) {
      debugPrint(
        '🎵 Player state: playing=${state.playing}, processingState=${state.processingState}',
      );

      // Track completed
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }

      notifyListeners();
    });

    // Error handling
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('❌ Playback error: $e');
      },
    );
  }

  /// Set playlist
  void setPlaylist(List<Map<String, dynamic>> tracks, String mode) {
    _playlist = List.from(tracks);
    _audioMode = mode;
    debugPrint('🎵 Playlist set: ${tracks.length} tracks, mode: $mode');
  }

  /// Set audio mode
  void setAudioMode(String mode) {
    _audioMode = mode;
    notifyListeners();
  }

  /// Play specific track by key
  Future<void> playTrack(String key) async {
    final index = _playlist.indexWhere((t) => t['key'] == key);
    if (index < 0) {
      debugPrint('❌ Track not found: $key');
      return;
    }
    await playTrackByIndex(index);
  }

  /// Play track by index
  Future<void> playTrackByIndex(int index) async {
    if (index < 0 || index >= _playlist.length) {
      debugPrint('❌ Invalid track index: $index');
      return;
    }

    _currentTrackIndex = index;
    _isPlayingInterlude = false;
    final track = _playlist[index];
    final url = track['url'] as String;
    final title = track['label'] as String? ?? 'Audio';
    final key = track['key'] as String? ?? 'track_$index';

    debugPrint('🎵 Playing track $index: $title');
    debugPrint('🎵 URL: $url');

    try {
      // Use AudioSource with MediaItem tag for lock screen controls
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: key,
            album: 'Lectio Divina',
            title: title,
            artist: 'Lectio Divina',
            artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
          ),
        ),
      );
      await _player.play();

      onTrackChanged?.call(track['key'], index);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error playing track: $e');
    }
  }

  /// Play interlude music
  Future<void> _playInterlude(Map<String, dynamic>? nextTrack) async {
    _isPlayingInterlude = true;
    _nextTrackAfterInterlude = nextTrack;

    final isLong = _audioMode == 'long' || nextTrack == null;
    final url = AudioConstants.getInterludeUrl(isLong: isLong);
    final title = isLong ? 'Meditačná hudba (dlhá)' : 'Meditačná hudba';

    debugPrint('🎵 Playing ${isLong ? "long" : "short"} interlude');

    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: 'interlude',
            album: 'Lectio Divina',
            title: title,
            artist: 'Meditácia',
            artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
          ),
        ),
      );
      await _player.play();

      onTrackChanged?.call('interlude', -1);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error playing interlude: $e');
      // Skip to next track if interlude fails
      if (nextTrack != null) {
        await playTrack(nextTrack['key']);
      }
    }
  }

  /// Handle track completion
  void _onTrackCompleted() {
    debugPrint(
      '🎵 Track completed: currentIndex=$_currentTrackIndex, isInterlude=$_isPlayingInterlude',
    );

    // If interlude finished, play next track
    if (_isPlayingInterlude) {
      _isPlayingInterlude = false;
      if (_nextTrackAfterInterlude != null) {
        final next = _nextTrackAfterInterlude!;
        _nextTrackAfterInterlude = null;
        playTrack(next['key']);
      } else {
        // Playlist completed
        onPlaylistCompleted?.call();
      }
      return;
    }

    // Normal track finished - play interlude then next
    if (_audioMode != 'none') {
      final hasNext = _currentTrackIndex < _playlist.length - 1;
      final nextTrack = hasNext ? _playlist[_currentTrackIndex + 1] : null;
      _playInterlude(nextTrack);
    } else {
      // No interlude mode - go directly to next
      if (_currentTrackIndex < _playlist.length - 1) {
        playTrackByIndex(_currentTrackIndex + 1);
      } else {
        onPlaylistCompleted?.call();
      }
    }
  }

  /// Play/Resume
  Future<void> play() async {
    if (_currentTrackIndex < 0 && _playlist.isNotEmpty) {
      await playTrackByIndex(0);
    } else {
      await _player.play();
    }
  }

  /// Pause
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stop
  Future<void> stop() async {
    await _player.stop();
    _currentTrackIndex = -1;
    _isPlayingInterlude = false;
    _nextTrackAfterInterlude = null;
    notifyListeners();
  }

  /// Seek
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Skip to next track
  Future<void> skipNext() async {
    if (_isPlayingInterlude) {
      // Skip interlude, go to next track
      _isPlayingInterlude = false;
      if (_nextTrackAfterInterlude != null) {
        final next = _nextTrackAfterInterlude!;
        _nextTrackAfterInterlude = null;
        await playTrack(next['key']);
      }
      return;
    }

    if (_currentTrackIndex < _playlist.length - 1) {
      await playTrackByIndex(_currentTrackIndex + 1);
    }
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    if (_isPlayingInterlude) {
      // Cancel interlude, go back to current
      _isPlayingInterlude = false;
      _nextTrackAfterInterlude = null;
      if (_currentTrackIndex >= 0) {
        await playTrackByIndex(_currentTrackIndex);
      }
      return;
    }

    // If more than 3 seconds in, restart current track
    if (_player.position.inSeconds > 3 || _currentTrackIndex <= 0) {
      await seek(Duration.zero);
    } else {
      await playTrackByIndex(_currentTrackIndex - 1);
    }
  }

  /// Dispose
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

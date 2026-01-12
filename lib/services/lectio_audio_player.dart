import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';

/// Simple, clean audio player for Lectio Divina
/// Uses setAudioSources() with MediaItem tags for proper iOS lock screen controls
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
  bool _isStopped = false; // Flag to prevent auto-progression after stop

  // Callbacks
  VoidCallback? onPlaylistCompleted;
  void Function(String trackKey, int index)? onTrackChanged;
  VoidCallback? onSectionCompleted;

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
      // Configure audio session - use predefined music() configuration like official example
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      appLogger.d('🎵 AudioSession configured for music playback');

      // Setup player listeners
      _setupListeners();

      _isInitialized = true;
      appLogger.d('🎵 LectioAudioPlayer initialized');
    } catch (e) {
      appLogger.e('❌ Error initializing LectioAudioPlayer: $e');
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

    // Track index changes (for lock screen next/prev AND auto-progression)
    int? lastCompletedIndex;
    _player.currentIndexStream.listen((index) {
      if (index == null) return;

      appLogger.d(
        '🎵 currentIndexStream: index=$index, _currentTrackIndex=$_currentTrackIndex, lastCompletedIndex=$lastCompletedIndex',
      );

      // Detect automatic track progression (not manual skip)
      if (index != _currentTrackIndex && !_isPlayingInterlude) {
        // Check if this is auto-progression (previous track completed)
        if (lastCompletedIndex != null && index == (lastCompletedIndex! + 1)) {
          appLogger.d(
            '🎵 🎯 AUTO-PROGRESSION detected: $lastCompletedIndex -> $index',
          );
          // Previous track completed, trigger interlude logic
          final previousIndex = lastCompletedIndex!;
          lastCompletedIndex = index;

          // Update current index BEFORE triggering completion
          _currentTrackIndex = index;

          // Trigger track completion for the PREVIOUS track
          appLogger.d('🎵 Triggering completion for track $previousIndex');
          _handleTrackCompleted();

          // Notify UI of new track (will be called again after interlude)
          if (index >= 0 && index < _playlist.length) {
            onTrackChanged?.call(_playlist[index]['key'], index);
          }
        } else {
          // Manual skip or first track
          appLogger.d('🎵 Manual skip or first track: $index');
          lastCompletedIndex = index;
          _currentTrackIndex = index;
          if (index >= 0 && index < _playlist.length) {
            onTrackChanged?.call(_playlist[index]['key'], index);
          }
        }
        notifyListeners();
      } else if (index == _currentTrackIndex && lastCompletedIndex == null) {
        // First track started
        lastCompletedIndex = index;
      }
    });

    // Player state changes (for final playlist completion)
    _player.playerStateStream.listen((state) {
      appLogger.d(
        '🎵 Player state: playing=${state.playing}, processingState=${state.processingState}',
      );

      // Only handle final playlist completion
      if (state.processingState == ProcessingState.completed) {
        appLogger.d('🎵 🏁 FINAL playlist completion detected');
        _handleTrackCompleted();
      }

      notifyListeners();
    });

    // Error handling
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        appLogger.e('❌ Playback error: $e');
      },
    );
  }

  /// Set playlist and audio mode
  Future<void> setPlaylist(
    List<Map<String, dynamic>> tracks,
    String mode,
  ) async {
    _playlist = List.from(tracks);
    _audioMode = mode;
    _isStopped = false; // Reset stopped flag for new playlist
    appLogger.d('🎵 Setting playlist: ${tracks.length} tracks, mode: $mode');

    // Build list of AudioSources with MediaItem tags (like in official example)
    final sources = <AudioSource>[];
    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final url = track['url'] as String;
      final title = track['label'] as String? ?? 'Audio';
      final key = track['key'] as String? ?? 'track_$i';

      sources.add(
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
    }

    // Use setAudioSources (plural) like in official example
    // This automatically creates ConcatenatingAudioSource and enables lock screen controls
    try {
      await _player.setAudioSources(sources, preload: true);
      appLogger.d('🎵 ✅ Audio sources set with ${sources.length} tracks');
    } catch (e) {
      appLogger.e('❌ Error setting audio sources: $e');
    }
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
      appLogger.e('❌ Track not found: $key');
      return;
    }
    await playTrackByIndex(index);
  }

  /// Play track by index
  Future<void> playTrackByIndex(int index) async {
    if (index < 0 || index >= _playlist.length) {
      appLogger.e('❌ Invalid track index: $index');
      return;
    }

    _currentTrackIndex = index;
    _isPlayingInterlude = false;
    final track = _playlist[index];
    final title = track['label'] as String? ?? 'Audio';
    final key = track['key'] as String? ?? 'track_$index';

    appLogger.d('🎵 Playing track $index: $title');

    try {
      // Use seek() to navigate to track in concatenated playlist (like official example)
      await _player.seek(Duration.zero, index: index);
      if (!_player.playing) {
        await _player.play();
      }
      appLogger.d('🎵 ✅ Seeked to track $index and started playback');

      onTrackChanged?.call(key, index);
      notifyListeners();
    } catch (e) {
      appLogger.e('❌ Error playing track: $e');
    }
  }

  /// Play interlude music (outside of playlist)
  Future<void> _playInterlude(Map<String, dynamic>? nextTrack) async {
    _isPlayingInterlude = true;
    _nextTrackAfterInterlude = nextTrack;

    final isLong = _audioMode == 'long' || nextTrack == null;
    final url = AudioConstants.getInterludeUrl(isLong: isLong);
    final title = isLong ? 'Meditačná hudba (dlhá)' : 'Meditačná hudba';

    appLogger.d('🎵 Playing ${isLong ? "long" : "short"} interlude');

    try {
      // CRITICAL: Keep audio session active during interlude
      final session = await AudioSession.instance;
      await session.setActive(
        true,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );

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
      appLogger.e('❌ Error playing interlude: $e');
      // Skip to next track if interlude fails
      if (nextTrack != null) {
        await playTrack(nextTrack['key']);
      }
    }
  }

  /// Handle track completion - wrapper to run async code
  void _handleTrackCompleted() {
    // Run async code without awaiting (fire and forget)
    // This is safe because _onTrackCompletedAsync handles all errors internally
    _onTrackCompletedAsync();
  }

  /// Handle track completion - async implementation
  Future<void> _onTrackCompletedAsync() async {
    try {
      appLogger.d('🎵 ═══════════════════════════════════════════════');
      appLogger.d('🎵 _onTrackCompletedAsync CALLED');
      appLogger.d('🎵 currentIndex=$_currentTrackIndex');
      appLogger.d('🎵 isInterlude=$_isPlayingInterlude');
      appLogger.d('🎵 audioMode=$_audioMode');
      appLogger.d('🎵 playlist length=${_playlist.length}');
      appLogger.d('🎵 isStopped=$_isStopped');
      appLogger.d('🎵 ═══════════════════════════════════════════════');

      // Don't continue if user stopped playback
      if (_isStopped) {
        appLogger.d('🛑 Playback was stopped - skipping auto-progression');
        return;
      }

      // Notify section completed for UI callback
      onSectionCompleted?.call();

      // If interlude finished, play next track
      if (_isPlayingInterlude) {
        _isPlayingInterlude = false;
        if (_nextTrackAfterInterlude != null) {
          final next = _nextTrackAfterInterlude!;
          _nextTrackAfterInterlude = null;
          appLogger.d(
            '🎵 Interlude completed, playing next track: ${next['key']}',
          );
          // Need to restore playlist and play next track
          await _restorePlaylistAndPlayTrack(next);
        } else {
          appLogger.d('🎵 Interlude completed, playlist finished');
          // Playlist completed
          onPlaylistCompleted?.call();
        }
        return;
      }

      // Normal track finished - play interlude then next (if audio mode != none)
      appLogger.d(
        '🎵 Checking if should play interlude: audioMode=$_audioMode',
      );
      if (_audioMode != 'none' && _currentTrackIndex >= 0) {
        final hasNext = _currentTrackIndex < _playlist.length - 1;
        final nextTrack = hasNext ? _playlist[_currentTrackIndex + 1] : null;
        appLogger.d(
          '🎵 ✅ Will play interlude. hasNext=$hasNext, nextTrack=${nextTrack?['key']}',
        );

        // CRITICAL: Pause player before interlude to prevent auto-progression
        await _player.pause();
        appLogger.d('🎵 ⏸️ Player paused before interlude');

        await _playInterlude(nextTrack);
      } else {
        appLogger.d(
          '🎵 ❌ Skipping interlude: audioMode=$_audioMode, currentIndex=$_currentTrackIndex',
        );
        // No interlude mode - check if we need to advance
        if (_currentTrackIndex >= _playlist.length - 1) {
          appLogger.d('🎵 Playlist completed (no interlude mode)');
          onPlaylistCompleted?.call();
        } else {
          // Auto-advance to next track
          appLogger.d('🎵 Auto-advancing to next track (no interlude mode)');
          await playTrackByIndex(_currentTrackIndex + 1);
        }
      }
    } catch (e) {
      appLogger.e('❌ Error in _onTrackCompletedAsync: $e');
    }
  }

  /// Restore playlist after interlude and play specific track
  Future<void> _restorePlaylistAndPlayTrack(Map<String, dynamic> track) async {
    _isPlayingInterlude = false;

    // Find track index
    final index = _playlist.indexWhere((t) => t['key'] == track['key']);
    if (index >= 0) {
      appLogger.d('🎵 Resuming playlist at track $index after interlude');
      // Just seek to the track - playlist is already set
      await _player.seek(Duration.zero, index: index);
      await _player.play();
      _currentTrackIndex = index;
      onTrackChanged?.call(track['key'], index);
      notifyListeners();
    } else {
      appLogger.e('❌ Track not found in playlist: ${track['key']}');
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
    _isStopped = true; // Prevent auto-progression
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
    appLogger.d(
      '🎵 skipNext called, isInterlude=$_isPlayingInterlude, currentIndex=$_currentTrackIndex',
    );

    if (_isPlayingInterlude) {
      // Skip interlude, go to next track
      _isPlayingInterlude = false;
      if (_nextTrackAfterInterlude != null) {
        final next = _nextTrackAfterInterlude!;
        _nextTrackAfterInterlude = null;
        await _restorePlaylistAndPlayTrack(next);
      }
      return;
    }

    // Use just_audio's built-in next for playlist
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_currentTrackIndex < _playlist.length - 1) {
      await playTrackByIndex(_currentTrackIndex + 1);
    }
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    appLogger.d(
      '🎵 skipPrevious called, isInterlude=$_isPlayingInterlude, currentIndex=$_currentTrackIndex',
    );

    if (_isPlayingInterlude) {
      // Cancel interlude, restart current track
      _isPlayingInterlude = false;
      _nextTrackAfterInterlude = null;
      if (_currentTrackIndex >= 0) {
        await playTrackByIndex(_currentTrackIndex);
      }
      return;
    }

    // If more than 3 seconds in, restart current track
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_currentTrackIndex > 0) {
      await playTrackByIndex(_currentTrackIndex - 1);
    } else {
      await seek(Duration.zero);
    }
  }

  /// Dispose
  @override
  void dispose() {
    // Dispose player (audio session will be deactivated automatically)
    _player.dispose();
    super.dispose();
  }
}

// Compatibility layer - redirects to new LectioAudioPlayer
// This file exists for backwards compatibility with lectio_screen.dart

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/app_logger.dart';
import 'lectio_audio_player.dart';

// Global audio handler for compatibility
AudioHandler? globalAudioHandler;

class BackgroundAudioManager {
  static final BackgroundAudioManager _instance =
      BackgroundAudioManager._internal();
  factory BackgroundAudioManager() => _instance;
  BackgroundAudioManager._internal();

  final LectioAudioPlayer _player = LectioAudioPlayer();
  bool _isInitialized = false;

  // Callbacks
  void Function(String trackKey, int index)? _onTrackChanged;
  VoidCallback? _onPlaylistCompleted;
  VoidCallback? _onSectionCompleted;

  /// Initialize background audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _player.initialize();

      _player.onTrackChanged = (key, index) {
        appLogger.d('🎵 BAM: onTrackChanged $key at $index');
        _onTrackChanged?.call(key, index);
      };

      _player.onPlaylistCompleted = () {
        appLogger.d('🎵 BAM: onPlaylistCompleted');
        _onPlaylistCompleted?.call();
      };

      // Connect section completed callback
      _player.onSectionCompleted = () {
        appLogger.d('🎵 BAM: onSectionCompleted');
        _onSectionCompleted?.call();
      };

      _isInitialized = true;
      appLogger.i('✅ BackgroundAudioManager initialized');
    } catch (e) {
      appLogger.e('❌ Error initializing background audio: $e');
      rethrow;
    }
  }

  /// Get audio handler instance (null - no longer using audio_service directly)
  dynamic get audioHandler => null;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Set playlist for background playback - NOW ASYNC
  Future<void> setPlaylist(
    List<Map<String, dynamic>> tracks,
    String audioMode,
  ) async {
    await _player.setPlaylist(tracks, audioMode);
  }

  /// Set current track by section key
  void setCurrentTrackByKey(String sectionKey) {
    // This is handled when playTrack is called
  }

  /// Get current playlist
  List<Map<String, dynamic>> get playlist => _player.playlist;

  /// Get current track index
  int get currentTrackIndex => _player.currentTrackIndex;

  /// Audio mode - 'none', 'short', 'long'
  String audioMode = 'short';

  /// Set audio mode without rebuilding playlist
  void setAudioMode(String mode) {
    audioMode = mode;
    _player.setAudioMode(mode);
  }

  /// Check if playing interlude
  bool get isPlayingInterlude => _player.isPlayingInterlude;

  /// Get current position
  Duration get currentPosition => _player.position;

  /// Get total duration
  Duration? get totalDuration => _player.duration;

  /// Check if playing
  bool get isPlaying => _player.isPlaying;

  /// Get underlying LectioAudioPlayer for listeners
  LectioAudioPlayer get lectioPlayer => _player;

  /// Get player state stream for UI updates
  Stream<PlayerState> get playerStateStream => _player.player.playerStateStream;

  /// Get position stream for UI updates
  Stream<Duration> get positionStream => _player.player.positionStream;

  /// Get duration stream for UI updates
  Stream<Duration?> get durationStream => _player.player.durationStream;

  /// Playback state stream (compatibility - empty for now)
  Stream<PlaybackState> get playbackStateStream => Stream.empty();

  /// Play URL (find track by URL and play)
  Future<void> play(String url, {String? title, String? artist}) async {
    // Find track by URL and play
    final index = _player.playlist.indexWhere((t) => t['url'] == url);
    if (index >= 0) {
      await _player.playTrackByIndex(index);
    } else {
      appLogger.w('⚠️ Track not found by URL, playing from start');
      await _player.play();
    }
  }

  /// Pause
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume
  Future<void> resume() async {
    await _player.play();
  }

  /// Stop
  Future<void> stop() async {
    await _player.stop();
  }

  /// Seek
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Set callback for section completed
  void setOnSectionCompleted(VoidCallback? callback) {
    _onSectionCompleted = callback;
    _player.onSectionCompleted = callback;
  }

  /// Clear on section completed callback
  void clearOnSectionCompleted() {
    _onSectionCompleted = null;
    _player.onSectionCompleted = null;
  }

  /// Set callback for track changed
  void setOnTrackChanged(void Function(String trackKey, int index)? callback) {
    _onTrackChanged = callback;
    _player.onTrackChanged = callback;
  }

  /// Set callback for playlist completed
  void setOnPlaylistCompleted(VoidCallback? callback) {
    _onPlaylistCompleted = callback;
    _player.onPlaylistCompleted = callback;
  }

  /// Play track by index
  Future<void> playTrackByIndex(int index, {String? artistOverride}) async {
    await _player.playTrackByIndex(index);
  }

  /// Skip to next track
  Future<void> skipNext() async {
    await _player.skipNext();
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    await _player.skipPrevious();
  }

  /// Play interlude music (handled internally by LectioAudioPlayer)
  Future<void> playInterlude({
    required bool isLong,
    int? nextTrackIndex,
  }) async {
    // Interlude is handled internally by LectioAudioPlayer
  }

  /// Handle track completion
  Future<void> onTrackCompleted() async {
    _onSectionCompleted?.call();
  }
}

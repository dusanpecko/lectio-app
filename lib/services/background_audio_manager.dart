// Compatibility layer - redirects to new LectioAudioPlayer
// This file exists for backwards compatibility with lectio_screen.dart

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

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
        _onTrackChanged?.call(key, index);
      };

      _player.onPlaylistCompleted = () {
        _onPlaylistCompleted?.call();
      };

      // Listen for track completion to trigger section callback
      _player.addListener(() {
        // This is handled internally by LectioAudioPlayer now
      });

      _isInitialized = true;
      debugPrint('✅ BackgroundAudioManager (compatibility) initialized');
    } catch (e) {
      debugPrint('❌ Error initializing background audio: $e');
      rethrow;
    }
  }

  /// Get audio handler instance (null - no longer using audio_service directly)
  dynamic get audioHandler => null;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Set playlist for background playback
  void setPlaylist(List<Map<String, dynamic>> tracks, String audioMode) {
    _player.setPlaylist(tracks, audioMode);
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

  /// Check if playing interlude
  bool get isPlayingInterlude => _player.isPlayingInterlude;

  /// Get current position
  Duration get currentPosition => _player.position;

  /// Get total duration
  Duration? get totalDuration => _player.duration;

  /// Check if playing
  bool get isPlaying => _player.isPlaying;

  /// Playback state stream (compatibility)
  Stream<PlaybackState> get playbackStateStream => Stream.empty();

  /// Play URL
  Future<void> play(String url, {String? title, String? artist}) async {
    // Find track by URL and play
    final index = _player.playlist.indexWhere((t) => t['url'] == url);
    if (index >= 0) {
      await _player.playTrackByIndex(index);
    } else {
      // Direct play - but we need to add to playlist first
      debugPrint('🎵 Direct play URL: $url');
      // For now, just start playing from playlist
      await _player.play();
    }

    // Trigger section completed callback when track ends
    // This is now handled by LectioAudioPlayer internally
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
  }

  /// Clear on section completed callback
  void clearOnSectionCompleted() {
    _onSectionCompleted = null;
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

  /// Play interlude music
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

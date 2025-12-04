import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' hide debugPrint;
import 'package:get_it/get_it.dart';

import '../shared/globals.dart';
import 'lectio_audio_service.dart';

class BackgroundAudioManager {
  static final BackgroundAudioManager _instance =
      BackgroundAudioManager._internal();
  factory BackgroundAudioManager() => _instance;
  BackgroundAudioManager._internal();

  LectioAudioHandler? _audioHandler;
  bool _isInitialized = false;

  // Playlist pre background playback
  List<Map<String, dynamic>> _playlist = [];
  int _currentTrackIndex = -1;
  String _audioMode = 'short'; // 'none', 'short', 'long'
  bool _isPlayingInterlude = false;

  /// Initialize background audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioHandler = await AudioService.init(
        builder: () => LectioAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'sk.lectio.divina.audio',
          androidNotificationChannelName: 'Lectio Divina Audio',
          androidNotificationChannelDescription:
              'Audio prehrávanie pre Lectio Divina - background playback s lock screen controls',
          androidNotificationOngoing:
              false, // Allow dismissible with media controls
          androidStopForegroundOnPause:
              false, // Keep service alive for background play
          androidShowNotificationBadge: true,
          notificationColor: Color(0xFF4A5085),
          androidNotificationClickStartsActivity: true,
          androidNotificationIcon: 'mipmap/launcher_icon',
          // Enhanced settings for better MediaSession integration
          preloadArtwork: true,
          androidResumeOnClick: true,
          // Force media session activation
          artDownscaleWidth: 144,
          artDownscaleHeight: 144,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );

      await _audioHandler?.initializeAudioHandler();
      _isInitialized = true;

      // Set global reference
      globalAudioHandler = _audioHandler;

      // Register in GetIt for easy access
      if (!GetIt.instance.isRegistered<LectioAudioHandler>()) {
        GetIt.instance.registerSingleton<LectioAudioHandler>(_audioHandler!);
      }
    } catch (e) {
      print('❌ Error initializing background audio: $e');
      rethrow;
    }
  }

  /// Get audio handler instance
  LectioAudioHandler? get audioHandler => _audioHandler;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Set playlist for background playback
  void setPlaylist(List<Map<String, dynamic>> tracks, String audioMode) {
    _playlist = List.from(tracks);
    _audioMode = audioMode;
    debugPrint(
      '🎵 BackgroundAudioManager: Playlist set with ${tracks.length} tracks, mode: $audioMode',
    );
  }

  /// Set current track by section key
  void setCurrentTrackByKey(String sectionKey) {
    final index = _playlist.indexWhere((t) => t['key'] == sectionKey);
    if (index >= 0) {
      _currentTrackIndex = index;
      _isPlayingInterlude = false;
      debugPrint(
        '🎵 BackgroundAudioManager: Current track set to index $index (key: $sectionKey)',
      );
    } else {
      debugPrint(
        '🎵 BackgroundAudioManager: Track key "$sectionKey" not found in playlist',
      );
    }
  }

  /// Get current playlist
  List<Map<String, dynamic>> get playlist => _playlist;

  /// Get current track index
  int get currentTrackIndex => _currentTrackIndex;

  /// Get audio mode
  String get audioMode => _audioMode;

  /// Set audio mode
  set audioMode(String mode) {
    _audioMode = mode;
  }

  /// Check if playing interlude
  bool get isPlayingInterlude => _isPlayingInterlude;

  /// Play audio with title and artist
  Future<void> play(String url, {String? title, String? artist}) async {
    if (_audioHandler == null) {
      throw Exception('Background audio not initialized');
    }

    try {
      await _audioHandler!.playFromUrl(
        url,
        title: title ?? 'Lectio Divina',
        artist: artist ?? 'Spiritual Audio',
      );
    } catch (e) {
      print('❌ Error playing audio: $e');
      rethrow;
    }
  }

  /// Play track by index
  Future<void> playTrackByIndex(int index, {String? artistOverride}) async {
    if (index < 0 || index >= _playlist.length) {
      debugPrint('❌ Invalid track index: $index');
      return;
    }

    _currentTrackIndex = index;
    _isPlayingInterlude = false;
    final track = _playlist[index];

    debugPrint('🎵 Playing track $index: ${track['label']}');

    await play(
      track['url'],
      title: track['label'],
      artist: artistOverride ?? 'Lectio Divina',
    );
  }

  /// Play interlude music
  Future<void> playInterlude({
    required bool isLong,
    int? nextTrackIndex,
  }) async {
    _isPlayingInterlude = true;

    String url;
    if (isLong) {
      url =
          'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/lectio_full.mp3';
    } else {
      url =
          'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/audio_null.mp3';
    }

    debugPrint('🎵 Playing interlude (${isLong ? "long" : "short"})');

    await play(url, title: 'Meditačná hudba', artist: 'Lectio Divina');
  }

  /// Handle track completion - called from audio handler
  Future<void> onTrackCompleted() async {
    debugPrint('🎵 ═══════════════════════════════════════════════════════');
    debugPrint('🎵 BackgroundAudioManager.onTrackCompleted()');
    debugPrint('🎵 _isPlayingInterlude: $_isPlayingInterlude');
    debugPrint('🎵 _currentTrackIndex: $_currentTrackIndex');
    debugPrint('🎵 _playlist.length: ${_playlist.length}');
    debugPrint('🎵 _audioMode: $_audioMode');
    debugPrint('🎵 ═══════════════════════════════════════════════════════');

    // Ak nemáme playlist alebo index, fallback na widget callback
    if (_playlist.isEmpty || _currentTrackIndex < 0) {
      debugPrint(
        '🎵 ⚠️ No valid playlist/index (_currentTrackIndex=$_currentTrackIndex), cannot auto-progress',
      );
      debugPrint(
        '🎵 Widget callback should handle this via _onSectionCompleted in audio handler',
      );
      // Nevraciam sa - nech to spadne do else vetvy a zavolá interlude ak treba
      // Ale ak nemáme index, nemôžeme pokračovať
      return;
    }

    if (_isPlayingInterlude) {
      // Interlude finished, play next track
      _isPlayingInterlude = false;
      final nextIndex = _currentTrackIndex + 1;

      if (nextIndex < _playlist.length) {
        debugPrint('🎵 Interlude finished, playing next track: $nextIndex');
        await playTrackByIndex(nextIndex);
        // Notify listener if set (for UI update)
        _onTrackChanged?.call(_playlist[nextIndex]['key'], nextIndex);
      } else {
        debugPrint('🎵 Interlude finished, no more tracks');
        _onPlaylistCompleted?.call();
      }
      return;
    }

    // Regular track finished
    final hasNextTrack = _currentTrackIndex < _playlist.length - 1;

    if (_audioMode == 'none') {
      // No interlude, play next track directly
      if (hasNextTrack) {
        final nextIndex = _currentTrackIndex + 1;
        debugPrint('🎵 No interlude mode, playing next track: $nextIndex');
        await playTrackByIndex(nextIndex);
        _onTrackChanged?.call(_playlist[nextIndex]['key'], nextIndex);
      } else {
        debugPrint('🎵 Playlist completed');
        _onPlaylistCompleted?.call();
      }
    } else {
      // Play interlude
      final isLong = _audioMode == 'long' || !hasNextTrack;
      debugPrint(
        '🎵 Playing interlude before ${hasNextTrack ? "next track" : "end"}',
      );
      await playInterlude(isLong: isLong);
      _onTrackChanged?.call('interlude', -1);
    }
  }

  // Callbacks for UI updates
  Function(String trackKey, int index)? _onTrackChanged;
  Function()? _onPlaylistCompleted;

  /// Set callback for track changes (for UI updates)
  void setOnTrackChanged(Function(String trackKey, int index) callback) {
    _onTrackChanged = callback;
  }

  /// Set callback for playlist completion
  void setOnPlaylistCompleted(Function() callback) {
    _onPlaylistCompleted = callback;
  }

  /// Resume current audio
  Future<void> resume() async {
    await _audioHandler?.play();
  }

  /// Pause audio
  Future<void> pause() async {
    await _audioHandler?.pause();
  }

  /// Stop audio
  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentTrackIndex = -1;
    _isPlayingInterlude = false;
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  /// Set background play enabled/disabled
  Future<void> setBackgroundPlayEnabled(bool enabled) async {
    await _audioHandler?.setBackgroundPlayEnabled(enabled);
  }

  /// Get current state - use playbackState stream for Android compatibility
  bool get isPlaying {
    // Use the handler's playbackState which is synced via audio_service
    try {
      final state = _audioHandler?.playbackState.value;
      if (state != null && state.playing) return true;
    } catch (_) {}
    // Fallback to direct player access
    return _audioHandler?.isPlaying ?? false;
  }

  Duration get currentPosition {
    // Use the handler's playbackState which is synced via audio_service
    try {
      final state = _audioHandler?.playbackState.value;
      if (state != null) return state.position;
    } catch (_) {}
    // Fallback to direct player access
    return _audioHandler?.currentPosition ?? Duration.zero;
  }

  Duration? get totalDuration {
    // Use mediaItem from handler
    try {
      final mediaItem = _audioHandler?.mediaItem.value;
      if (mediaItem?.duration != null) return mediaItem!.duration;
    } catch (_) {}
    // Fallback to direct player access
    return _audioHandler?.totalDuration;
  }

  bool get backgroundPlayEnabled =>
      _audioHandler?.backgroundPlayEnabled ?? true;

  /// Get playback state stream
  Stream<PlaybackState> get playbackStateStream =>
      AudioService.playbackStateStream;

  /// Get current media item
  MediaItem? get currentMediaItem => _audioHandler?.mediaItem.value;

  /// Set callback for when a section completes (for automatic progression)
  void setOnSectionCompleted(Function callback) {
    if (_audioHandler != null) {
      _audioHandler!.setOnSectionCompleted(callback);
    }
  }

  /// Clear section completion callback
  void clearOnSectionCompleted() {
    if (_audioHandler != null) {
      _audioHandler!.clearOnSectionCompleted();
    }
  }

  /// Dispose resources
  void dispose() {
    _audioHandler?.dispose();
  }
}

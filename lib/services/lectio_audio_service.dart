import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';
import 'background_audio_manager.dart';

class LectioAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _logger = appLogger;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _backgroundPlayEnabled = true;

  Future<void> initializeAudioHandler() async {
    _logger.i('🎵 Initializing Lectio Audio Handler');

    // Load background play setting
    await _loadBackgroundPlaySetting();

    // Setup audio player listeners
    _setupAudioPlayerListeners();

    // Configure audio session for background playback
    await _configureAudioSession();
  }

  Future<void> _configureAudioSession() async {
    try {
      // Configure player for background audio and media controls
      await _audioPlayer.setLoopMode(LoopMode.off);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSpeed(1.0);

      // Create initial MediaItem to establish MediaSession
      mediaItem.add(
        MediaItem(
          id: 'lectio_divina_init',
          album: 'Lectio Divina',
          title: 'Lectio Divina Ready',
          artist: 'Spiritual Audio',
          genre: 'Spiritual',
          duration: Duration.zero,
          playable: true,
          // iOS lock screen artwork
          artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
        ),
      );

      // Initialize comprehensive playback state for Android lock screen
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.play,
            MediaControl.pause,
            MediaControl.stop,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToPrevious,
            MediaAction.skipToNext,
            MediaAction.setSpeed,
            MediaAction.setRepeatMode,
            MediaAction.setShuffleMode,
          },
          // Critical for Android lock screen - show play/pause and stop
          androidCompactActionIndices: const [
            0,
            1,
            2,
          ], // play/pause, stop, skip
          processingState: AudioProcessingState.idle,
          playing: false,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
          repeatMode: AudioServiceRepeatMode.none,
          shuffleMode: AudioServiceShuffleMode.none,
          // Force Android to show this as active media session
          queueIndex: 0,
        ),
      );

      _logger.i(
        '🎵 Audio session configured for background playback and lock screen controls',
      );
    } catch (e) {
      _logger.w('⚠️ Could not configure audio session: $e');
    }
  }

  Future<void> _loadBackgroundPlaySetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _backgroundPlayEnabled = prefs.getBool('background_play_enabled') ?? true;
      _logger.i('📱 Background play enabled: $_backgroundPlayEnabled');
    } catch (e) {
      _logger.e('❌ Error loading background play setting: $e');
    }
  }

  void _setupAudioPlayerListeners() {
    // Player state changes
    _audioPlayer.playerStateStream.listen((state) {
      _logger.i(
        '🎵 Player state changed: ${state.processingState}, playing: ${state.playing}',
      );

      if (state.processingState == ProcessingState.completed) {
        _logger.i(
          '🏁 ProcessingState.completed detected - calling _onAudioCompleted()',
        );
        _onAudioCompleted();
      }

      _updatePlaybackState(state);
    });

    // Error handling
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        _logger.e('❌ Audio playback error: $e');
        // Don't try to continue on network errors - let user handle it
        if (e.toString().contains('UnknownHostException') ||
            e.toString().contains('No address associated')) {
          _logger.e('🌐 Network error detected - stopping auto-progression');
          return;
        }
        // For other errors, we might still try to continue
        _tryPlayNextSection();
      },
    );

    // Position updates
    _audioPlayer.positionStream.listen((position) {
      _updateMediaItem(position: position);
    });

    // Duration updates
    _audioPlayer.durationStream.listen((duration) {
      _updateMediaItem(duration: duration);
    });
  }

  void _updatePlaybackState(PlayerState playerState) {
    final isPlaying = playerState.playing;
    final processingState = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[playerState.processingState]!;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          // Always show play/pause as primary control
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          // Add skip controls for better UX
          MediaControl.skipToPrevious,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        // Show primary controls in compact notification (Android lock screen)
        androidCompactActionIndices: const [0, 1], // play/pause, stop
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
        speed: _audioPlayer.speed,
        queueIndex: 0,
        // Ensure Android shows this as active media session
        repeatMode: AudioServiceRepeatMode.none,
        shuffleMode: AudioServiceShuffleMode.none,
      ),
    );
  }

  void _updateMediaItem({Duration? duration, Duration? position}) {
    final currentMediaItem = mediaItem.value;
    if (currentMediaItem != null) {
      mediaItem.add(
        currentMediaItem.copyWith(
          duration: duration ?? currentMediaItem.duration,
        ),
      );
    }
  }

  @override
  Future<void> play() async {
    if (!_backgroundPlayEnabled) {
      _logger.w('⚠️ Background play is disabled');
      return;
    }

    try {
      _logger.i(
        '▶️ Playing audio (background enabled: $_backgroundPlayEnabled)',
      );
      await _audioPlayer.play();

      // Ensure playback state is updated
      _updatePlaybackState(_audioPlayer.playerState);
    } catch (e) {
      _logger.e('❌ Error starting playback: $e');
      rethrow;
    }
  }

  /// Custom method to play specific URL with metadata
  Future<void> playFromUrl(String url, {String? title, String? artist}) async {
    try {
      _logger.i('🎵 ════════════════════════════════════════════════════════');
      _logger.i('🎵 playFromUrl() START');
      _logger.i('🎵 URL: $url');
      _logger.i('🎵 Title: $title');
      _logger.i('🎵 ════════════════════════════════════════════════════════');

      // Create MediaItem with comprehensive metadata for better iOS/Android support
      final mediaItemData = MediaItem(
        id: url,
        album: 'Lectio Divina',
        title: title ?? 'Lectio Divina Audio',
        artist: artist ?? 'Spiritual Audio',
        genre: 'Spiritual',
        duration: null, // Will be set when audio loads
        playable: true,
        // iOS lock screen artwork - use hosted icon
        artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
        extras: {
          'displayTitle': title ?? 'Lectio Divina Audio',
          'displaySubtitle': artist ?? 'Spiritual Audio',
        },
      );

      _logger.i('🎵 MediaItem created, adding to stream...');
      mediaItem.add(mediaItemData);
      _logger.i('🎵 MediaItem added');

      // Load the audio source with enhanced headers
      _logger.i('🎵 Loading audio source...');
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: {'User-Agent': 'LectioDivina/1.0', 'Accept': 'audio/*'},
        ),
      );
      _logger.i('🎵 Audio source loaded successfully');
      _logger.i('🎵 Duration: ${_audioPlayer.duration}');

      // Start playing immediately to trigger media session
      _logger.i('🎵 Calling play()...');
      await play();
      _logger.i('🎵 play() completed, audio should be playing now');
      _logger.i('🎵 isPlaying: ${_audioPlayer.playing}');
      _logger.i('🎵 position: ${_audioPlayer.position}');
    } catch (e) {
      _logger.e('🎵 ❌ ERROR in playFromUrl: $e');
      // Use enhanced error handling with network diagnostics
      await _handleAudioError('playFromUrl', e);

      // Check if it's a network error and stop auto-progression
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('unknownhostexception') ||
          errorMessage.contains('no network') ||
          errorMessage.contains('failed host lookup') ||
          errorMessage.contains('unable to resolve host')) {
        _logger.w('🌐 Network error detected - stopping auto-progression');
        // Don't trigger completion callback for network errors
        return;
      }

      // Don't rethrow immediately - let the main app handle fallbacks
      throw Exception('Failed to load audio: ${e.toString()}');
    }
  }

  @override
  Future<void> pause() async {
    _logger.i('⏸️ Pausing audio');
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    _logger.i('⏹️ Stopping audio');
    await _audioPlayer.stop();

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _logger.i('⏩ Seeking to: ${position.inSeconds}s');
    await _audioPlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    _logger.i('⏭️ Skip to next - triggering section completion');
    // Trigger section completion to advance to next track
    _tryPlayNextSection();
  }

  @override
  Future<void> skipToPrevious() async {
    _logger.i('⏮️ Skip to previous');
    // Seek to beginning for now - actual previous track would require track history
    await _audioPlayer.seek(Duration.zero);
  }

  /// Play Lectio audio with metadata
  Future<void> playLectioAudio({
    required String url,
    required String title,
    required String subtitle,
    String? artUri,
  }) async {
    try {
      _logger.i('🎵 Playing Lectio audio: $title');

      // Default artwork URI for iOS lock screen
      final defaultArtUri = AudioConstants.defaultArtworkUrl;

      // Set media item for notification
      mediaItem.add(
        MediaItem(
          id: url,
          album: 'Lectio Divina',
          title: title,
          artist: subtitle,
          duration: null, // Will be updated when known
          artUri: Uri.parse(artUri ?? defaultArtUri),
          extras: {'source': 'lectio_divina', 'type': 'spiritual_audio'},
        ),
      );

      // Load and play audio
      await _audioPlayer.setUrl(url);
      await play();
    } catch (e) {
      _logger.e('❌ Error playing Lectio audio: $e');
      rethrow;
    }
  }

  /// Update background play setting
  Future<void> setBackgroundPlayEnabled(bool enabled) async {
    _backgroundPlayEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_play_enabled', enabled);
      _logger.i('📱 Background play setting updated: $enabled');
    } catch (e) {
      _logger.e('❌ Error saving background play setting: $e');
    }

    if (!enabled && _audioPlayer.playing) {
      await pause();
    }
  }

  /// Handle audio completion
  void _onAudioCompleted() {
    _logger.i('🏁 ════════════════════════════════════════════════════════');
    _logger.i('🏁 Audio playback completed - _onAudioCompleted() called');
    _logger.i('🏁 _backgroundPlayEnabled: $_backgroundPlayEnabled');
    _logger.i('🏁 ════════════════════════════════════════════════════════');

    // If background play is enabled, try to continue to next section
    if (_backgroundPlayEnabled) {
      _logger.i('🔄 Background play enabled, triggering auto-progression...');
      // Immediately trigger auto-progression
      _tryPlayNextSection();
    } else {
      _logger.i('⏸️ Background play disabled, stopping auto-progression');
    }
  }

  /// Try to play next section automatically
  void _tryPlayNextSection() {
    _logger.i('🎵 Attempting to play next section in background...');

    // FIRST: Use BackgroundAudioManager directly for reliable background playback
    // This doesn't depend on widget being mounted
    final bgManager = BackgroundAudioManager();

    // Only use BackgroundAudioManager if it has valid playlist AND valid track index
    if (bgManager.playlist.isNotEmpty && bgManager.currentTrackIndex >= 0) {
      _logger.i(
        '📝 Using BackgroundAudioManager.onTrackCompleted() for background playback (index: ${bgManager.currentTrackIndex})',
      );
      bgManager.onTrackCompleted();
      return;
    }

    _logger.i(
      '📝 BackgroundAudioManager not ready (playlist: ${bgManager.playlist.length}, index: ${bgManager.currentTrackIndex})',
    );

    // FALLBACK: Use callback for widget (only works when mounted)
    if (_onSectionCompleted != null) {
      _logger.i('📝 Calling registered section completion callback');
      _onSectionCompleted!();
    } else {
      _logger.w(
        '📝 ⚠️ No section completion handler registered - auto-progression will not work!',
      );
    }
  }

  /// Callback for when a section is completed (to be set by main lectio flow)
  Function? _onSectionCompleted;

  /// Set callback for section completion
  void setOnSectionCompleted(Function callback) {
    _onSectionCompleted = callback;
    _logger.i('📝 Section completion callback registered');
  }

  /// Clear section completion callback
  void clearOnSectionCompleted() {
    _onSectionCompleted = null;
    _logger.i('📝 Section completion callback cleared');
  }

  /// Get current playback state
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;
  bool get backgroundPlayEnabled => _backgroundPlayEnabled;

  @override
  Future<void> onTaskRemoved() async {
    // Handle when app is removed from recent apps
    _logger.i('📱 App task removed, background play: $_backgroundPlayEnabled');
    if (!_backgroundPlayEnabled) {
      await stop();
    }
    await super.onTaskRemoved();
  }

  /// Handle app lifecycle changes
  Future<void> onAppLifecycleStateChanged(String state) async {
    _logger.i('📱 App lifecycle changed: $state');

    switch (state) {
      case 'paused':
        // App went to background - ensure audio continues if enabled
        if (_backgroundPlayEnabled && _audioPlayer.playing) {
          _logger.i('🎵 App backgrounded, maintaining foreground service');
          // Sync playback state to maintain foreground service
          _updatePlaybackState(_audioPlayer.playerState);
        }
        break;
      case 'resumed':
        // App came back to foreground
        _logger.i('🎵 App resumed, syncing playback state');
        _updatePlaybackState(_audioPlayer.playerState);
        break;
      case 'detached':
        // App is detaching
        if (!_backgroundPlayEnabled) {
          _logger.i('🛑 App detached, background play disabled - stopping');
          await stop();
        } else {
          _logger.i('🎵 App detached, background play enabled - continuing');
        }
        break;
    }
  }

  /// Check network connectivity
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _logger.i(
        '🌐 Network connectivity check: ${isConnected ? "CONNECTED" : "DISCONNECTED"}',
      );
      return isConnected;
    } catch (e) {
      _logger.w('🌐 Network connectivity check failed: $e');
      return false;
    }
  }

  /// Enhanced error handling with network diagnostics
  Future<void> _handleAudioError(String context, dynamic error) async {
    _logger.e('❌ Audio error in $context: $error');

    // Check if it's a network-related error
    final errorMessage = error.toString().toLowerCase();
    final isNetworkError =
        errorMessage.contains('unknownhostexception') ||
        errorMessage.contains('no network') ||
        errorMessage.contains('failed host lookup') ||
        errorMessage.contains('unable to resolve host') ||
        errorMessage.contains('network is unreachable');

    if (isNetworkError) {
      _logger.w('🌐 Network error detected, running diagnostics...');
      final hasConnection = await _checkNetworkConnectivity();

      if (!hasConnection) {
        _logger.e('🔴 No internet connection - stopping auto-progression');
        // Stop any ongoing auto-progression
        return;
      } else {
        _logger.w('🟡 Internet available but Supabase host unreachable');
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

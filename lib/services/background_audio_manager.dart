import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
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
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  /// Set background play enabled/disabled
  Future<void> setBackgroundPlayEnabled(bool enabled) async {
    await _audioHandler?.setBackgroundPlayEnabled(enabled);
  }

  /// Get current state
  bool get isPlaying => _audioHandler?.isPlaying ?? false;
  Duration get currentPosition =>
      _audioHandler?.currentPosition ?? Duration.zero;
  Duration? get totalDuration => _audioHandler?.totalDuration;
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

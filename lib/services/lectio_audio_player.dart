import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';
import 'audio_download_service.dart';
import 'connectivity_service.dart';
import '../shared/audio_player_factory.dart';

/// Audio player for Lectio Divina with native background playback.
///
/// Key design: Interludes are pre-inserted into the ConcatenatingAudioSource
/// so the native iOS/Android player auto-advances through everything
/// without needing Dart code to run in the background.
class LectioAudioPlayer extends ChangeNotifier {
  static final LectioAudioPlayer _instance = LectioAudioPlayer._internal();
  factory LectioAudioPlayer() => _instance;
  LectioAudioPlayer._internal();

  final AudioPlayer _player = createAppAudioPlayer();
  final AudioDownloadService _audioDownloadService =
      AudioDownloadService.instance;

  // State
  bool _isInitialized = false;

  /// Original user tracks (without interludes)
  List<Map<String, dynamic>> _playlist = [];

  /// Current logical track index (in _playlist, NOT in native source)
  int _currentTrackIndex = -1;

  String _audioMode = 'short'; // none, short, long

  /// Whether the current native index is an interlude item
  bool _isPlayingInterlude = false;

  bool _isManualNavigation = false;
  bool _isPlayerBusy = false;

  /// Maps native source index → logical info
  /// Each entry: {'type': 'track'|'interlude', 'trackIndex': int}
  List<Map<String, dynamic>> _sourceMap = [];

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
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      appLogger.d('🎵 AudioSession configured for music playback');

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

    // Track index changes - just map native index to logical state
    // NO async, NO source replacement - native player handles everything
    _player.currentIndexStream.listen((nativeIndex) {
      if (nativeIndex == null || _sourceMap.isEmpty) return;
      if (_isManualNavigation) return;

      if (nativeIndex < 0 || nativeIndex >= _sourceMap.length) {
        appLogger.w('🎵 Native index $nativeIndex out of sourceMap range');
        return;
      }

      final entry = _sourceMap[nativeIndex];
      final type = entry['type'] as String;
      final trackIndex = entry['trackIndex'] as int;

      appLogger.d(
        '🎵 currentIndexStream: native=$nativeIndex → type=$type, trackIndex=$trackIndex',
      );

      if (type == 'interlude') {
        // Entering an interlude
        if (!_isPlayingInterlude) {
          _isPlayingInterlude = true;
          // Fire section completed callback (track just finished)
          onSectionCompleted?.call();
          onTrackChanged?.call('interlude', -1);
          notifyListeners();
        }
      } else {
        // Entering a track
        final wasInterlude = _isPlayingInterlude;
        _isPlayingInterlude = false;

        if (trackIndex != _currentTrackIndex || wasInterlude) {
          _currentTrackIndex = trackIndex;
          if (trackIndex >= 0 && trackIndex < _playlist.length) {
            final key = _playlist[trackIndex]['key'] as String;
            onTrackChanged?.call(key, trackIndex);
            appLogger.d('🎵 Now playing track $trackIndex: $key');
          }
        }
        notifyListeners();
      }
    });

    // Player state changes - only handle full playlist completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        appLogger.d('🎵 🏁 Playlist fully completed');
        _isPlayingInterlude = false;
        // Fire section completed for the last track
        onSectionCompleted?.call();
        onPlaylistCompleted?.call();
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

  /// Set playlist and audio mode.
  /// Builds a ConcatenatingAudioSource with interludes interleaved.
  Future<void> setPlaylist(
    List<Map<String, dynamic>> tracks,
    String mode,
  ) async {
    _playlist = List.from(tracks);
    _audioMode = mode;
    appLogger.d('🎵 Setting playlist: ${tracks.length} tracks, mode: $mode');

    // Build interleaved sources: [track0, interlude0, track1, interlude1, ...]
    final sources = <AudioSource>[];
    _sourceMap = [];

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final url = track['url'] as String;
      final title = track['label'] as String? ?? 'Audio';
      final key = track['key'] as String? ?? 'track_$i';
      final localPath = track['localPath'] as String?;

      appLogger.d(
        '🎵 Track $i: key=$key, hasLocalPath=${localPath != null}, url=$url',
      );

      // Add the track - skip if not available (e.g. offline without local file)
      final trackSource = _createAudioSource(
        url: url,
        localPath: localPath,
        key: key,
        title: title,
      );
      if (trackSource != null) {
        sources.add(trackSource);
        _sourceMap.add({'type': 'track', 'trackIndex': i});
      } else {
        appLogger.w('⏭️ Skipping track $i ($key) - not available');
      }

      // Add interlude after this track (if mode != none AND track was added)
      if (mode != 'none' && trackSource != null) {
        final interludeSource = _createInterludeSource(key, i, tracks.length);
        if (interludeSource != null) {
          sources.add(interludeSource);
          _sourceMap.add({'type': 'interlude', 'trackIndex': i});
        }
      }
    }

    appLogger.d(
      '🎵 Built ${sources.length} sources (${tracks.length} tracks + ${sources.length - tracks.length} interludes)',
    );

    if (sources.isEmpty) {
      appLogger.e('❌ No audio sources available (all tracks unavailable)');
      throw Exception(
        'No audio tracks are available offline. Please download them first.',
      );
    }

    try {
      // Stop player before replacing audio sources to prevent native crash
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // V offline mode nepreloaduj - preload môže skúsiť sťahovať artwork/metadata
      final shouldPreload = ConnectivityService.instance.isOnline;
      await _player.setAudioSources(sources, preload: shouldPreload);
      appLogger.d(
        '🎵 ✅ Interleaved audio sources set successfully (preload=$shouldPreload)',
      );
    } catch (e) {
      appLogger.e('❌ Error setting audio sources: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  /// Create an interlude AudioSource based on track context and audio mode.
  AudioSource? _createInterludeSource(
    String currentTrackKey,
    int trackIndex,
    int totalTracks,
  ) {
    final bool isLong;
    if (_audioMode == 'long') {
      isLong = true;
    } else {
      // Short mode: long interlude for contemplatio, actio, and last track
      isLong =
          currentTrackKey == 'contemplatio_audio' ||
          currentTrackKey == 'actio_audio' ||
          trackIndex == totalTracks - 1;
    }

    final url = AudioConstants.getInterludeUrl(isLong: isLong);
    final title = isLong ? 'Meditačná hudba (dlhá)' : 'Meditačná hudba';

    final localPath = _audioDownloadService.getLocalPath(url);
    final isOffline = !ConnectivityService.instance.isOnline;

    appLogger.d(
      '🎵 Interlude $trackIndex: isLong=$isLong, hasLocalPath=${localPath != null}, offline=$isOffline, url=$url',
    );

    final mediaItem = MediaItem(
      id: 'interlude_$trackIndex',
      album: 'Lectio Divina',
      title: title,
      artist: 'Meditácia',
      // V offline mode nepoužívaj remote artUri
      artUri: isOffline ? null : Uri.parse(AudioConstants.defaultArtworkUrl),
    );

    if (localPath != null) {
      try {
        if (File(localPath).existsSync()) {
          appLogger.d('🎵 📦 Using local interlude file: $localPath');
          return AudioSource.file(localPath, tag: mediaItem);
        } else {
          appLogger.w('⚠️ Local interlude file not found: $localPath');
        }
      } catch (e) {
        appLogger.e('❌ Error checking local interlude file: $e');
      }
    }

    // Skip interludes in offline mode if not available locally
    if (isOffline) {
      appLogger.w(
        '⏭️ Skipping interlude $trackIndex (offline mode, no local file)',
      );
      return null;
    }

    appLogger.d('🎵 🌐 Streaming interlude from URL: $url');
    return AudioSource.uri(Uri.parse(url), tag: mediaItem);
  }

  /// Create AudioSource for a track.
  /// Always checks AudioDownloadService directly (not just passed localPath)
  /// to handle stale cache scenarios.
  /// Returns null if track is not available (offline without local file).
  AudioSource? _createAudioSource({
    required String url,
    String? localPath,
    required String key,
    required String title,
  }) {
    final isOffline = !ConnectivityService.instance.isOnline;

    final mediaItem = MediaItem(
      id: key,
      album: 'Lectio Divina',
      title: title,
      artist: 'Lectio Divina',
      // V offline mode nepoužívaj remote artUri - Android padá keď sa snaží stiahnuť artwork
      artUri: isOffline ? null : Uri.parse(AudioConstants.defaultArtworkUrl),
    );

    // Vždy skontroluj AudioDownloadService priamo (nie len parameter)
    // Toto rieši stale cache problém
    final effectiveLocalPath =
        localPath ?? _audioDownloadService.getLocalPath(url);

    appLogger.d(
      '🎵 Creating audio source for $key: offline=$isOffline, '
      'passedLocalPath=${localPath != null}, '
      'effectiveLocalPath=${effectiveLocalPath != null}',
    );

    // Skús najprv lokálny súbor ak existuje (VŽDY preferuj lokálny)
    if (effectiveLocalPath != null) {
      try {
        final fileExists = File(effectiveLocalPath).existsSync();
        appLogger.d(
          '🎵 Local file check for $key: exists=$fileExists, path=$effectiveLocalPath',
        );

        if (fileExists) {
          appLogger.d('🎵 📦 Using local file for $key: $effectiveLocalPath');
          return AudioSource.file(effectiveLocalPath, tag: mediaItem);
        } else {
          appLogger.w('⚠️ Local file not found for $key: $effectiveLocalPath');
        }
      } catch (e) {
        appLogger.e('❌ Error checking local file for $key: $e');
      }
    }

    // V offline mode nemôžeme streamovať - skip track
    if (isOffline) {
      appLogger.w(
        '⏭️ Cannot play $key in offline mode - no local file available',
      );
      return null;
    }

    // Online - streamuj z URL
    appLogger.d('🎵 🌐 Streaming from URL for $key: $url');
    return AudioSource.uri(Uri.parse(url), tag: mediaItem);
  }

  /// Set audio mode
  void setAudioMode(String mode) {
    _audioMode = mode;
    notifyListeners();
  }

  /// Find native source index for a logical track index
  int _nativeIndexForTrack(int trackIndex) {
    for (int i = 0; i < _sourceMap.length; i++) {
      final entry = _sourceMap[i];
      if (entry['type'] == 'track' && entry['trackIndex'] == trackIndex) {
        return i;
      }
    }
    return -1;
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

  /// Play track by logical index
  Future<void> playTrackByIndex(int index) async {
    if (index < 0 || index >= _playlist.length) {
      appLogger.e('❌ Invalid track index: $index');
      return;
    }

    if (_isPlayerBusy) {
      appLogger.w('⏳ Player busy, skipping playTrackByIndex($index)');
      return;
    }
    _isPlayerBusy = true;

    _isManualNavigation = true;
    _currentTrackIndex = index;
    _isPlayingInterlude = false;
    final track = _playlist[index];
    final title = track['label'] as String? ?? 'Audio';
    final key = track['key'] as String? ?? 'track_$index';

    appLogger.d('🎵 Playing track $index: $title');

    try {
      final nativeIndex = _nativeIndexForTrack(index);
      if (nativeIndex < 0) {
        appLogger.e('❌ Native index not found for track $index');
        return;
      }

      await _player.seek(Duration.zero, index: nativeIndex);
      if (!_player.playing) {
        _player.play();
      }
      appLogger.d('🎵 ✅ Seeked to native index $nativeIndex for track $index');

      _isManualNavigation = false;

      onTrackChanged?.call(key, index);
      notifyListeners();
    } on PlatformException catch (e) {
      appLogger.e('❌ PlatformException playing track: $e');
      _isManualNavigation = false;
    } catch (e) {
      _isManualNavigation = false;
      appLogger.e('❌ Error playing track: $e');
    } finally {
      _isPlayerBusy = false;
    }
  }

  /// Play/Resume
  Future<void> play() async {
    try {
      if (_currentTrackIndex < 0 && _playlist.isNotEmpty) {
        await playTrackByIndex(0);
      } else {
        await _player.play();
      }
    } catch (e) {
      appLogger.e('❌ Error playing audio: $e');
      rethrow;
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
    notifyListeners();
  }

  /// Seek
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Skip to next track (skipping any interlude)
  Future<void> skipNext() async {
    appLogger.d(
      '🎵 skipNext called, isInterlude=$_isPlayingInterlude, currentIndex=$_currentTrackIndex',
    );

    if (_isPlayingInterlude) {
      // Currently playing interlude after track N → skip to track N+1
      final nextTrackIndex = _currentTrackIndex + 1;
      if (nextTrackIndex < _playlist.length) {
        await playTrackByIndex(nextTrackIndex);
      }
      return;
    }

    // Playing a track → skip to next track
    if (_currentTrackIndex < _playlist.length - 1) {
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
      if (_currentTrackIndex >= 0) {
        await playTrackByIndex(_currentTrackIndex);
      }
      return;
    }

    // If more than 3 seconds in, restart current track
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_currentTrackIndex > 0) {
      await playTrackByIndex(_currentTrackIndex - 1);
    } else {
      await seek(Duration.zero);
    }
  }

  /// Dispose
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

class LectioAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _backgroundPlayer = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<MediaItem> _currentItems = [];

  bool _backgroundEnabled = false;
  double _backgroundVolume = 0.3;
  String? _backgroundUrl;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<bool> get backgroundEnabledStream =>
      _backgroundPlayer.playerStateStream.map((state) => state.playing);

  LectioAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist);
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.setLoopMode(LoopMode.one);
    } catch (e) {
      debugPrint("Chyba pri nastavovaní audio source: $e");
    }

    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.sequenceStateStream.listen((sequenceState) {
      final newQueue = sequenceState.effectiveSequence.map((source) {
        return source.tag as MediaItem;
      }).toList();
      queue.add(newQueue);
      _currentItems = newQueue;

      final idx = _player.currentIndex ?? 0;
      if (_currentItems.isNotEmpty && idx < _currentItems.length) {
        mediaItem.add(_currentItems[idx]);
      }
    });

    // Listen to main player completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _fadeOutBackground();
      }
    });
  }

  Future<void> loadPlaylist(
    Map<String, dynamic> lectioData,
    List<Map<String, String>> audioSections, {
    String? backgroundAudioUrl,
  }) async {
    await _player.stop();
    await _playlist.clear();
    final mediaItems = <MediaItem>[];

    // Store background URL
    _backgroundUrl = backgroundAudioUrl;

    for (var section in audioSections) {
      final url = lectioData[section['key']] as String?;
      if (url != null && url.isNotEmpty) {
        Duration? duration;
        try {
          final tempPlayer = AudioPlayer();
          duration = await tempPlayer.setUrl(url);
          await tempPlayer.dispose();
        } catch (e) {
          duration = null;
        }
        final mediaItem = MediaItem(
          id: url,
          title: section['label'] ?? '',
          duration: duration,
          artUri: Uri.parse('https://images.sk/images/NwM1i.png'),
        );
        mediaItems.add(mediaItem);
        _playlist.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
        debugPrint('Pridávam: ${mediaItem.title} - duration: $duration');
      }
    }

    queue.add(mediaItems);
    _currentItems = mediaItems;

    if (mediaItems.isNotEmpty) {
      mediaItem.add(mediaItems.first);
    }
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    _backgroundEnabled = enabled;
    if (enabled && _backgroundUrl != null) {
      await _startBackground();
    } else {
      await _stopBackground();
    }
  }

  Future<void> setBackgroundVolume(double volume) async {
    _backgroundVolume = volume;
    await _backgroundPlayer.setVolume(volume);
  }

  Future<void> _startBackground() async {
    if (_backgroundUrl == null) return;

    try {
      await _backgroundPlayer.setUrl(_backgroundUrl!);
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.setLoopMode(LoopMode.one);
      if (_player.playing) {
        await _backgroundPlayer.play();
      }
    } catch (e) {
      debugPrint("Chyba pri spúšťaní background audio: $e");
    }
  }

  Future<void> _stopBackground() async {
    await _backgroundPlayer.stop();
  }

  Future<void> _fadeOutBackground() async {
    if (!_backgroundPlayer.playing) return;

    const fadeDuration = 5000; // 5 seconds
    const steps = 50;
    const stepDuration = fadeDuration ~/ steps;
    final volumeStep = _backgroundVolume / steps;

    for (int i = 0; i < steps; i++) {
      final newVolume = _backgroundVolume - (volumeStep * (i + 1));
      await _backgroundPlayer.setVolume(newVolume.clamp(0.0, 1.0));
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    await _backgroundPlayer.stop();
    await _backgroundPlayer.setVolume(_backgroundVolume); // Reset volume
  }

  @override
  Future<void> play() async {
    await _player.play();
    if (_backgroundEnabled && _backgroundUrl != null) {
      await _backgroundPlayer.play();
    }

    final idx = _player.currentIndex ?? 0;
    if (_currentItems.isNotEmpty && idx < _currentItems.length) {
      mediaItem.add(_currentItems[idx]);
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _backgroundPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final idx = _player.currentIndex ?? 0;
    if (_currentItems.isNotEmpty && idx < _currentItems.length) {
      mediaItem.add(_currentItems[idx]);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _stopBackground();
    await _player.seek(Duration.zero);
    await playbackState.first;
  }

  @override
  Future<void> skipToNext() async {
    await _player.seekToNext();
    final idx = _player.currentIndex ?? 0;
    if (_currentItems.isNotEmpty && idx < _currentItems.length) {
      mediaItem.add(_currentItems[idx]);
    }
    await play();
  }

  @override
  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
    final idx = _player.currentIndex ?? 0;
    if (_currentItems.isNotEmpty && idx < _currentItems.length) {
      mediaItem.add(_currentItems[idx]);
    }
    await play();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    if (_currentItems.isNotEmpty && index < _currentItems.length) {
      mediaItem.add(_currentItems[index]);
    }
    await play();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.hasPrevious) MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        if (_player.hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudioSection {
  final String key;
  final String label;
  AudioSection({required this.key, required this.label});
}

class LectioAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<MediaItem> _currentItems = [];

  Stream<Duration> get positionStream => _player.positionStream;

  LectioAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      print("Chyba pri nastavovaní audio source: $e");
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
  }

  Future<void> loadPlaylist(
    Map<String, dynamic> lectioData,
    List<AudioSection> audioSections,
  ) async {
    await _player.stop();
    await _playlist.clear();
    final mediaItems = <MediaItem>[];

    for (var section in audioSections) {
      final url = lectioData[section.key] as String?;
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
          title: section.label,
          duration: duration,
          artUri: Uri.parse('https://images.sk/images/NwM1i.png'),
        );
        mediaItems.add(mediaItem);
        _playlist.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
        print('Pridávam: ${mediaItem.title} - duration: $duration');
      }
    }

    queue.add(mediaItems);
    _currentItems = mediaItems;

    if (mediaItems.isNotEmpty) {
      mediaItem.add(mediaItems.first);
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    final idx = _player.currentIndex ?? 0;
    if (_currentItems.isNotEmpty && idx < _currentItems.length) {
      mediaItem.add(_currentItems[idx]);
    }
  }

  @override
  Future<void> pause() => _player.pause();

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
}

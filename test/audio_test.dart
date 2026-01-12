import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lectio_divina/controllers/lectio_audio_controller.dart';
import 'package:lectio_divina/services/background_audio_manager.dart';
import 'package:lectio_divina/services/lectio_audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

// Mock triedy
class MockBackgroundAudioManager extends Mock
    implements BackgroundAudioManager {}

class MockLectioAudioHandler extends Mock implements LectioAudioHandler {}

void main() {
  late LectioAudioController audioController;
  late MockBackgroundAudioManager mockBackgroundAudioManager;
  late MockLectioAudioHandler mockAudioHandler;

  // Subjects pre simuláciu eventov (musia byť BehaviorSubject, lebo BaseAudioHandler ich tak definuje)
  late BehaviorSubject<PlaybackState> playbackStateSubject;
  late BehaviorSubject<MediaItem?> mediaItemSubject;

  setUp(() {
    mockBackgroundAudioManager = MockBackgroundAudioManager();
    mockAudioHandler = MockLectioAudioHandler();

    playbackStateSubject = BehaviorSubject<PlaybackState>.seeded(
      PlaybackState(),
    );
    mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(null);

    // Setup Mock BackgroundAudioManager
    when(
      () => mockBackgroundAudioManager.initialize(),
    ).thenAnswer((_) async {});
    when(
      () => mockBackgroundAudioManager.audioHandler,
    ).thenReturn(mockAudioHandler);
    when(() => mockBackgroundAudioManager.isInitialized).thenReturn(true);

    // Setup streams
    // Pozor: BackgroundAudioManager.playbackStateStream je Stream<PlaybackState>
    when(
      () => mockBackgroundAudioManager.playbackStateStream,
    ).thenAnswer((_) => playbackStateSubject.stream);

    // Ale LectioAudioHandler.mediaItem je BehaviorSubject<MediaItem?>
    when(() => mockAudioHandler.mediaItem).thenAnswer((_) => mediaItemSubject);

    // Setup other properties
    when(
      () => mockBackgroundAudioManager.currentPosition,
    ).thenReturn(Duration.zero);
    when(() => mockBackgroundAudioManager.isPlaying).thenReturn(false);
    when(
      () => mockBackgroundAudioManager.totalDuration,
    ).thenReturn(Duration.zero);

    // Callbacks
    when(
      () => mockBackgroundAudioManager.setOnTrackChanged(any()),
    ).thenReturn(null);
    when(
      () => mockBackgroundAudioManager.setOnPlaylistCompleted(any()),
    ).thenReturn(null);

    // Inject Mock into Controller
    LectioAudioController.setInstanceForTesting(
      LectioAudioController.internal(manager: mockBackgroundAudioManager),
    );
    audioController = LectioAudioController();
  });

  tearDown(() {
    playbackStateSubject.close();
    mediaItemSubject.close();
  });

  test('Initialize controller and listen to streams', () async {
    // Act
    await audioController.initialize();

    // Assert
    verify(() => mockBackgroundAudioManager.playbackStateStream).called(1);
    // Note: audioHandler access depends on initialization check order
  });

  test('Play calls setPlaylist and playTrackByIndex', () async {
    // Arrange
    await audioController.initialize();

    final playlist = [
      {'key': 'track1', 'label': 'Title', 'url': 'http://test.com'},
    ];
    when(
      () => mockBackgroundAudioManager.setPlaylist(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockBackgroundAudioManager.playTrackByIndex(any()),
    ).thenAnswer((_) async {});

    // Act
    await audioController.playTracks(playlist, startKey: 'track1');

    // Assert
    verify(
      () => mockBackgroundAudioManager.setPlaylist(playlist, any()),
    ).called(1);
    verify(() => mockBackgroundAudioManager.playTrackByIndex(0)).called(1);
    expect(audioController.playlist, equals(playlist));
  });
}

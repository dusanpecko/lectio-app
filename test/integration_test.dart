import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lectio_divina/controllers/lectio_audio_controller.dart';
import 'package:lectio_divina/controllers/notification_controller.dart';
import 'package:lectio_divina/main.dart';
import 'package:lectio_divina/models/lectio_audio_state.dart';
import 'package:lectio_divina/screens/home_screen.dart';
import 'package:lectio_divina/services/auth_service.dart';
import 'package:lectio_divina/services/background_audio_manager.dart';
import 'package:lectio_divina/services/credentials_service.dart';
import 'package:lectio_divina/services/fcm_service.dart';
import 'package:lectio_divina/services/lectio_audio_service.dart';
import 'package:lectio_divina/services/lectio_data_service.dart';
import 'package:lectio_divina/services/local_notifications_service.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lectio_divina/models/spiritual_exercise.dart';

// Mocks
class MockAuthService extends Mock implements AuthService {}

class MockCredentialsService extends Mock implements CredentialsService {}

class MockLectioDataService extends Mock implements LectioDataService {
  @override
  Future<Map<String, dynamic>?> getDailyLectio({
    required DateTime date,
    required String locale,
  }) => super.noSuchMethod(
    Invocation.method(#getDailyLectio, [], {#date: date, #locale: locale}),
  );

  @override
  Future<DailyQuote?> getDailyQuote({required String locale}) => super
      .noSuchMethod(Invocation.method(#getDailyQuote, [], {#locale: locale}));

  @override
  Future<List<Map<String, dynamic>>> getNews({
    required String locale,
    int limit = 5,
  }) => super.noSuchMethod(
    Invocation.method(#getNews, [], {#locale: locale, #limit: limit}),
  );

  @override
  Future<SpiritualExercise?> getFeaturedExercise({required String locale}) =>
      super.noSuchMethod(
        Invocation.method(#getFeaturedExercise, [], {#locale: locale}),
      );
}

class MockLocalNotificationsService extends Mock
    implements LocalNotificationsService {}

class MockFcmService extends Mock implements FcmService {}

class MockNotificationController extends Mock
    implements NotificationController {}

class MockLectioAudioController extends Mock implements LectioAudioController {}

class MockBackgroundAudioManager extends Mock
    implements BackgroundAudioManager {}

class MockLectioAudioHandler extends Mock implements LectioAudioHandler {}

class MockSession extends Mock implements Session {}

void main() {
  late MockAuthService mockAuthService;
  late MockCredentialsService mockCredentialsService;
  late MockLectioDataService mockLectioDataService;
  late MockLocalNotificationsService mockLocalNotificationsService;
  late MockFcmService mockFcmService;
  late MockNotificationController mockNotificationController;
  late MockLectioAudioController mockAudioController;
  late MockBackgroundAudioManager mockBackgroundAudioManager;
  late MockLectioAudioHandler mockLectioAudioHandler;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'dummy',
    );
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('sk', null);

    registerFallbackValue(const Locale('sk'));
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockCredentialsService = MockCredentialsService();
    mockLectioDataService = MockLectioDataService();
    mockLocalNotificationsService = MockLocalNotificationsService();
    mockFcmService = MockFcmService();
    mockNotificationController = MockNotificationController();
    mockAudioController = MockLectioAudioController();
    mockBackgroundAudioManager = MockBackgroundAudioManager();
    mockLectioAudioHandler = MockLectioAudioHandler();

    // Inject Mocks
    AuthService.setInstanceForTesting(mockAuthService);
    CredentialsService.setInstanceForTesting(mockCredentialsService);
    LectioDataService.setInstanceForTesting(mockLectioDataService);
    LocalNotificationsService.setInstanceForTesting(
      mockLocalNotificationsService,
    );
    FcmService.setInstanceForTesting(mockFcmService);
    NotificationController.setInstanceForTesting(mockNotificationController);
    LectioAudioController.setInstanceForTesting(mockAudioController);

    // Default Stubs
    // Auth
    when(() => mockAuthService.currentSession).thenReturn(null);
    when(
      () => mockAuthService.onAuthStateChange,
    ).thenAnswer((_) => const Stream.empty());

    // Credentials
    when(
      () => mockCredentialsService.hasCredentials(),
    ).thenAnswer((_) async => false);
    when(
      () => mockCredentialsService.getCredentials(),
    ).thenAnswer((_) async => {'email': null, 'password': null});

    // Notifications
    when(
      () => mockNotificationController.clearAppBadge(),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationController.getPendingNotification(),
    ).thenReturn(null);

    when(
      () => mockLocalNotificationsService.setupRegistrationNotification(),
    ).thenAnswer((_) async {});

    // FCM
    when(() => mockFcmService.init(any())).thenAnswer((_) async {});
    when(() => mockFcmService.setNotificationCallback(any())).thenReturn(null);
    when(
      () => mockFcmService.onLanguageChanged(any(), any()),
    ).thenAnswer((_) async {});
    // Add missing requestNotificationPermissions stub
    when(
      () => mockFcmService.requestNotificationPermissions(),
    ).thenAnswer((_) async => true);

    // Audio - BAM
    when(() => mockBackgroundAudioManager.isInitialized).thenReturn(true);

    when(
      () => mockBackgroundAudioManager.audioHandler,
    ).thenReturn(mockLectioAudioHandler);

    // AudioHandler
    final playbackStateSubject = BehaviorSubject<PlaybackState>.seeded(
      PlaybackState(playing: false),
    );
    final mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(null);
    when(
      () => mockLectioAudioHandler.mediaItem,
    ).thenAnswer((_) => mediaItemSubject);
    when(
      () => mockLectioAudioHandler.playbackState,
    ).thenAnswer((_) => playbackStateSubject);

    // Audio Controller connects to BAM
    when(
      () => mockAudioController.backgroundAudioManager,
    ).thenReturn(mockBackgroundAudioManager);

    // Controller property mocks (used by UI)
    when(
      () => mockAudioController.playbackState,
    ).thenReturn(LectioPlaybackState.idle);
    when(() => mockAudioController.currentTitle).thenReturn('');
    when(() => mockAudioController.isPlayerVisible).thenReturn(false);
    when(() => mockAudioController.isPlayerMinimized).thenReturn(false);
    when(() => mockAudioController.currentPosition).thenReturn(Duration.zero);
    when(() => mockAudioController.totalDuration).thenReturn(Duration.zero);
    when(() => mockAudioController.isPlaying).thenReturn(false);

    // Data Service
    when(
      () => mockLectioDataService.getDailyQuote(locale: any(named: 'locale')),
    ).thenAnswer(
      (_) async => DailyQuote(text: 'Test Quote', reference: 'Test Ref'),
    );
    when(
      () => mockLectioDataService.getNews(locale: any(named: 'locale')),
    ).thenAnswer((_) async => []);
    when(
      () => mockLectioDataService.getFeaturedExercise(
        locale: any(named: 'locale'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    // Close subjects if needed, but since they are created per test in setUp, GC will handle it.
  });

  Widget createTestApp() {
    return EasyLocalization(
      supportedLocales: const [Locale('sk')],
      path: 'assets/translations',
      fallbackLocale: const Locale('sk'),
      startLocale: const Locale('sk'),
      child: MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
        child: const MyApp(),
      ),
    );
  }

  testWidgets('Happy Path: Guest Login -> Home', (WidgetTester tester) async {
    // 1. Pump App
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify AuthScreen because session is null
    // Check for TextFields instead of localized text to be safe
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsWidgets);

    // 2. Login as Guest
    final guestButton = find.byType(OutlinedButton);
    await tester.ensureVisible(guestButton);
    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    // Wait for animations and data loading
    // pumpAndSettle might timeout if there are infinite animations (like progress indicators)
    // but with mocked data it should settle.

    // 3. Verify HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Test Quote'), findsOneWidget);
  });
}

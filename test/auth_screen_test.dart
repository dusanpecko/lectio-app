import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/home_screen.dart'; // Needed for type checking if navigation succeeds
import 'package:lectio_divina/services/auth_service.dart';
import 'package:lectio_divina/services/credentials_service.dart';
import 'package:lectio_divina/services/lectio_data_service.dart';
import 'package:mocktail/mocktail.dart';
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

// Fake AuthResponse for easier testing
class FakeAuthResponse extends Fake implements AuthResponse {
  final Session? _session;
  final User? _user;

  FakeAuthResponse({Session? session, User? user})
    : _session = session,
      _user = user;

  @override
  Session? get session => _session;

  @override
  User? get user => _user;
}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {
  @override
  String get id => 'test-user-id';
}

void main() {
  late MockAuthService mockAuthService;
  late MockCredentialsService mockCredentialsService;
  late MockLectioDataService mockLectioDataService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase mock to avoid crashes in internal init (though we replace instances)
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'dummy-anon-key',
    );

    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('sk', null);
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockCredentialsService = MockCredentialsService();
    mockLectioDataService = MockLectioDataService();

    AuthService.setInstanceForTesting(mockAuthService);
    CredentialsService.setInstanceForTesting(mockCredentialsService);
    LectioDataService.setInstanceForTesting(mockLectioDataService);

    // Default mocks
    when(
      () => mockCredentialsService.hasCredentials(),
    ).thenAnswer((_) async => false);
    when(
      () => mockCredentialsService.getCredentials(),
    ).thenAnswer((_) async => {'email': null, 'password': null});

    // Mock LectioDataService calls from HomeScreen (in case navigation happens)
    when(
      () => mockLectioDataService.getDailyQuote(locale: any(named: 'locale')),
    ).thenAnswer((_) async => null);
    when(
      () => mockLectioDataService.getNews(locale: any(named: 'locale')),
    ).thenAnswer((_) async => []);
    when(
      () => mockLectioDataService.getFeaturedExercise(
        locale: any(named: 'locale'),
      ),
    ).thenAnswer((_) async => null);

    // Mock AppLinks platform channel to avoid MissingPluginException
    const channel = MethodChannel('com.llfbandit.app_links/events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });
    // Another possible channel name for initialization
    const methodChannel = MethodChannel('com.llfbandit.app_links/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getInitialLink') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    // Clear mock handlers
    const channel = MethodChannel('com.llfbandit.app_links/events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    const methodChannel = MethodChannel('com.llfbandit.app_links/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  Widget createAuthScreen() {
    return EasyLocalization(
      supportedLocales: const [Locale('sk'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('sk'),
      startLocale: const Locale('sk'),
      child: const MaterialApp(home: AuthScreen()),
    );
  }

  testWidgets('AuthScreen renders login fields', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    expect(find.text('login'), findsWidgets); // 'login' key
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
    // Check for buttons by type, as text might be keys
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets('Continue as guest navigates to HomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    // Tap "Continue without login" (OutlinedButton)
    final guestButton = find.byType(OutlinedButton);
    expect(guestButton, findsOneWidget);

    // Scroll until visible
    await tester.ensureVisible(guestButton);
    await tester.pumpAndSettle(); // Wait for scroll

    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    // Verification: HomeScreen should be present
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Login success calls AuthService and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    // Mock successful sign in
    final mockSession = MockSession();
    final mockUser = MockUser();
    final authResponse = FakeAuthResponse(session: mockSession, user: mockUser);

    when(
      () => mockAuthService.signIn(
        email: 'test@example.com',
        password: 'password123',
      ),
    ).thenAnswer((_) async => authResponse);

    when(
      () => mockCredentialsService.clearCredentials(),
    ).thenAnswer((_) async {});

    // Enter credentials
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    // Tap Login (first ElevatedButton)
    final loginBtn = find
        .descendant(
          of: find.byType(Column),
          matching: find.byType(ElevatedButton),
        )
        .first;

    await tester.ensureVisible(loginBtn);
    await tester.pumpAndSettle();

    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // Verify
    verify(
      () => mockAuthService.signIn(
        email: 'test@example.com',
        password: 'password123',
      ),
    ).called(1);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

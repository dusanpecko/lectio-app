import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectio_divina/screens/home_screen.dart';
import 'package:lectio_divina/services/lectio_data_service.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lectio_divina/models/spiritual_exercise.dart';

import 'package:intl/date_symbol_data_local.dart';

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

void main() {
  late MockLectioDataService mockService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase mock
    // Note: auth.currentSession will be null, simulating logged out state
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'dummy-anon-key',
    );

    await EasyLocalization.ensureInitialized();
    // Initialize date formatting
    await initializeDateFormatting('sk', null);
  });

  setUp(() {
    mockService = MockLectioDataService();
    LectioDataService.setInstanceForTesting(mockService);
  });

  testWidgets('HomeScreen displaying daily quote', (WidgetTester tester) async {
    // Arrange
    const testQuote = 'Toto je testovací citát pre Lectio Divina.';
    const testReference = 'Ján 3, 16';

    when(
      () => mockService.getDailyQuote(locale: any(named: 'locale')),
    ).thenAnswer(
      (_) async => DailyQuote(text: testQuote, reference: testReference),
    );

    when(
      () => mockService.getNews(locale: any(named: 'locale')),
    ).thenAnswer((_) async => []);

    when(
      () => mockService.getFeaturedExercise(locale: any(named: 'locale')),
    ).thenAnswer((_) async => null);

    final themeProvider = ThemeProvider();
    await themeProvider.initialize();

    // Act
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('sk'), Locale('en'), Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('sk'),
          startLocale: const Locale('sk'),
          child: Builder(
            // Needed for context context.locale
            builder: (context) {
              return const MaterialApp(home: HomeScreen());
            },
          ),
        ),
      ),
    );

    // Wait for animations and async data
    await tester.pumpAndSettle();

    // Assert
    // Check if the quote is displayed
    expect(find.text(testQuote), findsOneWidget);
    expect(find.text(testReference), findsOneWidget);

    // Check if service method was called
    verify(() => mockService.getDailyQuote(locale: 'sk')).called(1);
  });
}

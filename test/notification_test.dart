import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:lectio_divina/services/local_notifications_service.dart';

// Mock triedy
class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidFlutterLocalNotificationsPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  late LocalNotificationsService service;
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    // Register fallback values
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const AndroidNotificationChannel('id', 'name'));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(const DarwinInitializationSettings());
    registerFallbackValue(const AndroidInitializationSettings('icon'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Create new mocks for each test
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();

    // Setup mocks
    when(() => mockNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(mockAndroidPlugin);

    when(() => mockNotificationsPlugin.initialize(
          any(),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
          onDidReceiveBackgroundNotificationResponse:
              any(named: 'onDidReceiveBackgroundNotificationResponse'),
        )).thenAnswer((_) async => true);

    when(() => mockAndroidPlugin.createNotificationChannel(any()))
        .thenAnswer((_) async {});
    when(() => mockAndroidPlugin.requestExactAlarmsPermission())
        .thenAnswer((_) async => true);

    when(() => mockNotificationsPlugin.getNotificationAppLaunchDetails())
        .thenAnswer((_) async => null);

    // Inject mock into service
    LocalNotificationsService.setInstanceForTesting(
        LocalNotificationsService.internal(
            notifications: mockNotificationsPlugin));
    service = LocalNotificationsService.instance;
  });

  test('Initialize calls plugin initialize', () async {
    // Act
    final result = await service.initialize();

    // Assert
    expect(result, true);
    verify(() => mockNotificationsPlugin.initialize(
          any(),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
        )).called(1);

    // Check Android channels creation
    verify(() => mockAndroidPlugin.createNotificationChannel(any())).called(3);
  });

  test('setupRegistrationNotification schedules welcome notification',
      () async {
    // Arrange

    // Mock zonedSchedule
    // Removing problematic parameter named: uiLocalNotificationDateInterpretation
    when(() => mockNotificationsPlugin.zonedSchedule(
            any(), any(), any(), any(), any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents')))
        .thenAnswer((_) async {}); // void return, future

    // Act
    // initialize() calls setupRegistrationNotification internally
    await service.initialize();

    // We can explicitly call it again to be sure, or just rely on initialize.
    // If we call it again:
    await service.setupRegistrationNotification();

    // Assert
    // Check if zonedSchedule was called with welcome ID (1000)
    // It should be called twice (once by init, once explicitly)
    verify(() => mockNotificationsPlugin.zonedSchedule(
          1000, // ID
          any(), // title
          any(), // body
          any(), // scheduledDate
          any(), // notificationDetails
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        )).called(2);
  });

  test('setDailyLectioEnabled(false) cancels notifications', () async {
    // Arrange
    when(() => mockNotificationsPlugin.cancel(any())).thenAnswer((_) async {});

    // Act
    await service.setDailyLectioEnabled(false);

    // Assert
    // Should cancel 7 notifications (dailyLectioBaseId to baseId + 6)
    // 2000 to 2006
    verify(() => mockNotificationsPlugin.cancel(any())).called(7);
  });
}

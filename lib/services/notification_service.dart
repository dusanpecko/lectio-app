import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializuje timezone a notification kanály. Volaj iba raz v main().
  static Future<void> initialize() async {
    // Nastavenie timezone podľa zariadenia
    tz.initializeTimeZones();
    final String timeZone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZone));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final settings = InitializationSettings(android: android, iOS: iOS);

    await _notificationsPlugin.initialize(settings);

    // Android: create notification channels
    const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
      'daily_channel',
      'Denné citáty',
      description: 'Denné pripomienky citátu',
      importance: Importance.high,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dailyChannel);

    const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
      'test_channel',
      'Test Notifikácie',
      description: 'Na overenie správneho zobrazenia',
      importance: Importance.high,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(testChannel);

    // iOS špecifické – žiadosť o povolenie
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Naplánovanie dennej notifikácie na určitý čas
  static Future<void> showDailyQuoteNotification(
    int hour,
    int minute,
    String quote,
  ) async {
    final time = _nextInstanceOfTime(hour, minute);

    await _notificationsPlugin.zonedSchedule(
      1,
      'Denný citát',
      quote,
      time,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Denné citáty',
          channelDescription: 'Denné pripomienky citátu',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Pomocná funkcia na výpočet najbližšieho času na plánovanie notifikácie
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// TEST – okamžitá notifikácia po 10 sekundách
  static Future<void> showTestNotification() async {
    await _notificationsPlugin.zonedSchedule(
      99, // Unikátne ID pre test
      'Test notifikácia',
      'Funguje to!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifikácie',
          channelDescription: 'Na overenie správneho zobrazenia',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

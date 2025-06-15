import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final Logger _logger = Logger();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(android: android, iOS: iOS);
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed('/lectio');
        }
      },
    );

    const AndroidNotificationChannel tipChannel = AndroidNotificationChannel(
      'tip_channel',
      'Denné tipy',
      description: 'Denné pripomienky tipov',
      importance: Importance.high,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(tipChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showDailyTipNotification(
    int hour,
    int minute,
    String locale,
  ) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('daily_quotes')
          .select()
          .eq('date', today)
          .eq('lang', locale)
          .maybeSingle();

      if (response == null) {
        _logger.w('[NotificationService] No tip found for today.');
        return;
      }

      final quote = response['quote'] as String?;
      final reference = response['reference'] as String?;

      if (quote == null) {
        _logger.w('[NotificationService] Missing quote.');
        return;
      }

      final body = reference != null && reference.trim().isNotEmpty
          ? '$quote\n$reference'
          : quote;

      final scheduledTime = _nextInstanceOfTime(hour, minute);

      await _notificationsPlugin.zonedSchedule(
        2,
        'Denný tip',
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tip_channel',
            'Denné tipy',
            channelDescription: 'Denné pripomienky tipov',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
      );
      _logger.i('[NotificationService] Tip scheduled for $scheduledTime');
    } catch (e) {
      _logger.e('[NotificationService] Error fetching tip', error: e);
    }
  }

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

  static Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      999,
      'Test notifikácia',
      'Funguje!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tip_channel',
          'Denné tipy',
          channelDescription: 'Test',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> deleteAccount(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase.functions.invoke(
        'delete_user',
        body: {
          'user': {'id': user.id},
        },
      );
      if (response.status == 200) {
        await supabase.auth.signOut();
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('account_deleted_title')),
            content: Text(tr('account_deleted_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      } else {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('error')),
            content: Text('${tr('account_delete_failed')}: ${response.data}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('error')),
          content: Text('${tr('account_delete_failed')}: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }
}

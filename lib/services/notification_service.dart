import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart'; // import 'package_info/package_info.dart'; // <-- ODSTRÁNENÉ/ZAKOMENTOVANÉ: Ak nepoužívaš package_info_plus, tento import nie je potrebný.
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

/// Logger pre globálne použitie (alebo ho môžeš inicializovať v každej triede)
final Logger _logger = Logger();

// Táto funkcia musí byť top-level (mimo akejkoľvek triedy)
// a označená ako @pragma('vm:entry-point').
// Spustí sa, keď príde FCM notifikácia a aplikácia je na pozadí alebo ukončená.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Dôležité: Firebase a Supabase musia byť inicializované aj tu,
  // pretože tento handler beží v oddelenom izoláte.
  await Firebase.initializeApp();

  // Ak Supabase ešte nie je inicializované, inicializuj ho tu znova s tvojimi URL/kľúčmi.
  // Použi environment variables z .env, ak ich načítaš globálne alebo ich sem hardcode.
  // Supabase.instance.client nemôže byť null, takže tento blok je zbytočný a bol odstránený.

  _logger.i(
    '[FirebaseMessaging] Handling a background message: ${message.messageId}',
  );

  // Predpokladáme, že 'locale' bude súčasťou 'data' payloadu z FCM.
  final locale = message.data['locale'] ?? 'sk';
  _logger.i('Received background message, locale: $locale');

  // Zavoláme logNotificationOpen z NotificationService
  await NotificationService.logNotificationOpen(locale);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance; // <-- Nová inštancia FCM

  static Future<void> logNotificationOpen(String locale) async {
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    try {
      _logger.i('[NotificationService] RPC call: date=$today, lang=$locale');
      await Supabase.instance.client.rpc(
        'increment_notification_open',
        params: {'p_date': today, 'p_lang': locale},
      );
      _logger.i('[NotificationService] Notification open logged.');
    } catch (e, s) {
      _logger.w(
        '[NotificationService] Failed to log notification open: $e\n$s',
      );
    }
  }

  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // --- Inicializácia Flutter Local Notifications Plugin ---
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final settings = InitializationSettings(android: android, iOS: iOS);

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          _logger.i('onDidReceiveNotificationResponse fired!');
          // Táto funkcia sa spustí pri kliknutí na LOKÁLNU notifikáciu
          // alebo na PUSH notifikáciu, ak je aplikácia otvorená/na pozadí (nie ukončená).
          // Pre iOS a push notifikácie z ukončeného stavu to rieši Firebase `getInitialMessage()` a `onMessageOpenedApp`.
          final locale = response.payload ?? 'sk';
          _logger.i('Clicked notification, locale: $locale');
          await logNotificationOpen(locale);
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

      // --- Inicializácia Firebase Cloud Messaging (FCM) ---
      // Požiadanie o povolenie pre iOS
      NotificationSettings notificationSettings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);
      _logger.i(
        'User granted permission: ${notificationSettings.authorizationStatus}',
      );

      // Spracovanie správy, ak aplikácia bola ukončená a používateľ na notifikáciu klikol
      // Toto je kľúčové pre iOS zaznamenávanie z terminated stavu.
      final RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        _logger.i('App opened from terminated state by notification.');
        final locale = initialMessage.data['locale'] ?? 'sk';
        await logNotificationOpen(locale);
      }

      // Spracovanie správ, keď je aplikácia v popredí
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('Got a message whilst in the foreground!');
        _logger.i('Message data: ${message.data}');

        // Môžeš zobraziť lokálnu notifikáciu pomocou flutter_local_notifications,
        // aby používateľ videl správu, aj keď je aplikácia otvorená.
        // Správa je už prijatá, ale systém ju automaticky nezobrazí, ak je appka v popredí.
        if (message.notification != null) {
          _notificationsPlugin.show(
            message.hashCode, // Unikátne ID pre notifikáciu
            message.notification!.title,
            message.notification!.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                tipChannel.id, // Použi ID tvojho existujúceho kanála
                tipChannel.name,
                channelDescription: tipChannel.description,
                importance: tipChannel.importance,
              ),
              iOS: DarwinNotificationDetails(
                subtitle: message
                    .notification!
                    .body, // Zobraziť body ako subtitle na iOS
              ),
            ),
            payload: message.data['locale'] ?? 'sk', // Prenes payload
          );
          _logger.i('Foreground FCM message displayed as local notification.');
        } else {
          _logger.i(
            'Foreground FCM message is data-only. Not displaying a visual notification.',
          );
        }
      });

      // Spracovanie správ, keď je aplikácia na pozadí (ale nie ukončená)
      // a používateľ na notifikáciu klikne.
      FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) async {
        _logger.i('Message opened app from background state!');
        final locale = message.data['locale'] ?? 'sk';
        await logNotificationOpen(locale);
      });

      // Získanie FCM tokenu (pre odosielanie push notifikácií z backendu)
      String? fcmToken = await _firebaseMessaging.getToken();
      _logger.i('FCM Token: $fcmToken');
      // Môžeš tento token poslať na Supabase a uložiť ho pre konkrétneho používateľa,
      // aby si mohol odosielať cielené notifikácie z tvojho backendu.

      _logger.i('[NotificationService] Initialization finished.');
    } catch (e, s) {
      _logger.e('[NotificationService] Initialization failed: $e\n$s');
    }
  }

  // Táto funkcia by teraz mala spúšťať odosielanie PUSH notifikácie cez backend (napr. Firebase Functions
  // alebo iný server), ktorý potom pošle notifikáciu cez FCM.
  // Nemala by už volať _notificationsPlugin.zonedSchedule pre "Denné tipy", ak ich chceš posielať cez FCM.
  // Ak chceš mať stále lokálne denné tipy, môžeš ju ponechať, ale potom sa nebudú logovať pri otvorení
  // z ukončeného stavu na iOS (iba ak by si kombinoval lokálne s FCM).
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

      // Ak chceš tento denný tip odoslať ako PUSH notifikáciu (cez FCM),
      // budeš musieť mať backend (napr. Supabase Edge Function alebo Firebase Function),
      // ktorý túto správu odošle na FCM.
      // Tu je len príklad, ako by to mohlo vyzerať, ale priama implementácia posielania
      // FCM správ zo zariadenia sa neodporúča, malo by to ísť cez server.

      // Príklad: Poslanie na backend funkciu, ktorá odosle FCM notifikáciu
      _logger.i(
        '[NotificationService] Attempting to send FCM for daily tip (via backend if implemented).',
      );
      // Napr. await Supabase.instance.client.functions.invoke('send_fcm_daily_tip', params: {'quote': quote, 'reference': reference, 'locale': locale});

      // Ponechaná pôvodná logika pre LOKÁLNE notifikácie (ak ich chceš mať aj takto)
      // Táto sa bude zaznamenávať pri otvorení na Android aj na iOS (ak je appka v popredí/na pozadí),
      // ale nie na iOS z terminated stavu. Ak ich nechceš lokálne, tento blok odstráň.
      final scheduledTime = _nextInstanceOfTime(hour, minute);
      await _notificationsPlugin.zonedSchedule(
        2, // ID notifikácie
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
        payload: locale, // Dôležité pre onDidReceiveNotificationResponse
      );
      _logger.i(
        '[NotificationService] Local daily tip scheduled for $scheduledTime, locale=$locale',
      );
    } catch (e, s) {
      _logger.e(
        '[NotificationService] Error fetching tip or scheduling/sending notification: $e\n$s',
      );
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
        ), // <-- DÚLEŽITÉ: Chýbajúca zátvorka tu bola opravená!
      );
    }
  }
}

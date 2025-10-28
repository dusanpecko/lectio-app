import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../main.dart' show navigatorKey;

class LocalNotificationsService {
  static LocalNotificationsService? _instance;
  static LocalNotificationsService get instance =>
      _instance ??= LocalNotificationsService._internal();

  LocalNotificationsService._internal();

  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Callback pre navigation handling
  Function(String?)? _notificationCallback;

  // Notification IDs
  static const int welcomeNotificationId = 1000;
  static const int dailyLectioBaseId = 2000; // 2000-2006 pre 7 dní
  static const int prayerReminderBaseId = 3000; // 3000+ pre rôzne časy

  // SharedPreferences keys
  static const String _registrationDateKey = 'registration_date';
  static const String _welcomeNotificationSent = 'welcome_notification_sent';
  static const String _dailyLectioEnabled = 'daily_lectio_enabled';
  static const String _prayerReminderEnabled = 'prayer_reminder_enabled';
  static const String _prayerReminderTime = 'prayer_reminder_time';
  static const String _cachedLectioData = 'cached_lectio_data';
  static const String _lastCacheUpdate = 'last_cache_update';

  /// Inicializácia lokálnych notifikácií
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Inicializuj timezone a nastav lokálnu timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Bratislava'));
      _logger.i('✅ Timezone initialized: Europe/Bratislava');

      // Android nastavenia - VYTVOR NOTIFICATION CHANNELS!
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // Vytvor notification channels pre Android 8.0+
      const AndroidNotificationChannel dailyLectioChannel =
          AndroidNotificationChannel(
            'daily_lectio_channel',
            'Denné zamyslenie',
            description: 'Denné lectio divina notifikácie',
            importance: Importance.max, // ZVÝŠENÉ Z HIGH NA MAX
            playSound: true,
            enableVibration: true,
          );

      const AndroidNotificationChannel prayerReminderChannel =
          AndroidNotificationChannel(
            'prayer_reminder_channel',
            'Pripomenutie modlitby',
            description: 'Pripomienky času na modlitbu',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

      const AndroidNotificationChannel welcomeChannel =
          AndroidNotificationChannel(
            'welcome_channel',
            'Uvítacie notifikácie',
            description: 'Uvítacie správy pre nových používateľov',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

      // Registruj channels
      _logger.i('🔧 Attempting to create Android notification channels...');
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      _logger.i(
        '🔧 androidPlugin: ${androidPlugin != null ? "NOT NULL" : "NULL"}',
      );

      if (androidPlugin != null) {
        _logger.i('🔧 Creating daily lectio channel...');
        await androidPlugin.createNotificationChannel(dailyLectioChannel);
        _logger.i('🔧 Creating prayer reminder channel...');
        await androidPlugin.createNotificationChannel(prayerReminderChannel);
        _logger.i('🔧 Creating welcome channel...');
        await androidPlugin.createNotificationChannel(welcomeChannel);
        _logger.i('✅ Android notification channels created');
      } else {
        _logger.e('❌ androidPlugin is NULL - channels NOT created!');
      }

      // iOS nastavenia
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            onDidReceiveLocalNotification: (id, title, body, payload) async {
              // Handle iOS foreground notification
              _logger.i('📱 iOS foreground notification received: $title');
            },
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      final initialized = await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Fix nullable condition
      if (initialized == true) {
        _isInitialized = true;
        _logger.i('✅ Local notifications initialized successfully');

        await _setupWelcomeNotificationIfNeeded();
        await _processInitialNotificationLaunch();

        return true;
      } else {
        _logger.e('❌ Failed to initialize local notifications');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error initializing local notifications: $e');
      return false;
    }
  }

  /// Improved handling for null payloads in notification taps
  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('📱 LOCAL NOTIFICATION TAPPED IN SERVICE!');
    _logger.i('📱 Response ID: ${response.id}');
    _logger.i('📱 Response actionId: ${response.actionId}');
    _logger.i('📱 Response payload: ${response.payload}');
    _logger.i(
      '📱 Response notificationResponseType: ${response.notificationResponseType}',
    );
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      if (response.payload == null) {
        _logger.w('⚠️ Notification payload is null. Using fallback logic.');
        _navigateToHome();
        return;
      }

      // Decode payload and handle navigation
      final payload = jsonDecode(response.payload!);
      final type = payload['type'] as String?;

      switch (type) {
        case 'daily_lectio':
          final dateStr = payload['date'] as String?;
          if (dateStr != null) {
            final date = DateTime.parse(dateStr);
            _navigateToLectio(date);
          } else {
            _logger.w('⚠️ Missing date in daily_lectio payload.');
            _navigateToHome();
          }
          break;
        case 'prayer_reminder':
          _navigateToLectio(DateTime.now());
          break;
        case 'welcome':
          _navigateToHome();
          break;
        default:
          _logger.w('⚠️ Unknown notification type: $type');
          _navigateToHome();
      }
    } catch (e) {
      _logger.e('❌ Error processing notification tap: $e');
      _logger.e('❌ Stack trace: ${StackTrace.current}');
      _navigateToHome();
    }
  }

  /// Nastavenie callback pre notification handling
  void setNotificationCallback(Function(String?)? callback) {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔧 setNotificationCallback() CALLED');
    _logger.i('🔧 Callback is null: ${callback == null}');
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _notificationCallback = callback;
  }

  /// Umožní spustiť callback aj keď tap event príde z iného plugin handlera
  void handleExternalNotificationTap(String? payload) {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('📩 handleExternalNotificationTap() CALLED');
    _logger.i('📩 Payload: $payload');
    _logger.i('📩 Callback is set: ${_notificationCallback != null}');
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (_notificationCallback != null) {
      _notificationCallback!(payload);
    } else {
      _logger.w('⚠️ No notification callback set. Unable to forward payload.');
    }
  }

  Future<void> _processInitialNotificationLaunch() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();

      if (details == null) {
        _logger.i('🚪 Launch details unavailable (null)');
        return;
      }

      final response = details.notificationResponse;
      final launchedFromNotification =
          response != null || details.didNotificationLaunchApp;

      _logger.i('🚪 Launch details - didLaunch: $launchedFromNotification');

      if (!launchedFromNotification) {
        return;
      }

      final payload = response?.payload;
      _logger.i('🚪 Launch payload: $payload');

      if (payload != null) {
        _logger.i('🚀 Forwarding launch payload to callback');
        handleExternalNotificationTap(payload);
      } else {
        _logger.w('⚠️ Launch payload is null despite notification launch');
      }
    } catch (e) {
      _logger.e('❌ Error processing initial notification launch: $e');
    }
  }

  /// Public metóda pre nastavenie welcome notification
  Future<void> setupRegistrationNotification() async {
    await _setupWelcomeNotificationIfNeeded();
  }

  /// Získanie aktuálneho jazyka aplikácie
  String _getCurrentLanguage() {
    try {
      // Pokús sa získať jazyk z EasyLocalization
      final context = navigatorKey.currentContext;
      if (context != null) {
        return context.locale.languageCode;
      }
    } catch (e) {
      _logger.w('Could not get current language from context: $e');
    }
    // Fallback na slovenčinu
    return 'sk';
  }

  /// Navigácia na LectioScreen
  void _navigateToLectio(DateTime date) {
    _logger.i('🧭 Navigate to Lectio for date: $date');
    _notificationCallback?.call('daily_lectio');
  }

  /// Navigácia na Home
  void _navigateToHome() {
    _logger.i('🧭 Navigate to Home');
    _notificationCallback?.call('home');
  }

  /// Nastavenie registračnej notifikácie
  Future<void> _setupWelcomeNotificationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool(_welcomeNotificationSent) ?? false;

    if (alreadySent) {
      _logger.i('📝 Welcome notification already sent, skipping');
      return;
    }

    final registrationDate = prefs.getString(_registrationDateKey);
    if (registrationDate == null) {
      // Nastav dátum registrácie na dnes
      await prefs.setString(
        _registrationDateKey,
        DateTime.now().toIso8601String(),
      );
      _logger.i('📅 Registration date set to today');
    }

    // Naplánuj uvítaciu notifikáciu na o 3 dni
    await _scheduleWelcomeNotification();
  }

  /// Naplánovanie uvítacej notifikácie
  Future<void> _scheduleWelcomeNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registrationDateStr = prefs.getString(_registrationDateKey);

      if (registrationDateStr == null) return;

      final registrationDate = DateTime.parse(registrationDateStr);
      final welcomeDate = registrationDate.add(const Duration(days: 3));

      // Nastav na 10:00 ráno
      final scheduledDate = DateTime(
        welcomeDate.year,
        welcomeDate.month,
        welcomeDate.day,
        10, // 10:00
        0,
      );

      // Ak je dátum v minulosti, preskočíme
      if (scheduledDate.isBefore(DateTime.now())) {
        _logger.i('⏰ Welcome notification date is in the past, skipping');
        await prefs.setBool(_welcomeNotificationSent, true);
        return;
      }

      final payload = jsonEncode({
        'type': 'welcome',
        'date': DateTime.now().toIso8601String(),
      });

      final location = tz.getLocation('Europe/Bratislava');
      await _notifications.zonedSchedule(
        welcomeNotificationId,
        'Vitajte v Lectio Divina! 🙏',
        'Objavte krásu modlitbového čítania Písma. Ste pripravení na duchovnú cestu?',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'welcome_channel',
            'Uvítacie notifikácie',
            channelDescription: 'Uvítacie správy pre nových používateľov',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      _logger.i('📅 Welcome notification scheduled for: $scheduledDate');
    } catch (e) {
      _logger.e('❌ Error scheduling welcome notification: $e');
    }
  }

  /// Zapnutie/vypnutie denných lectio notifikácií
  Future<void> setDailyLectioEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyLectioEnabled, enabled);

    if (enabled) {
      await _scheduleDailyLectioNotifications();
    } else {
      await _cancelDailyLectioNotifications();
    }

    _logger.i(
      '📱 Daily lectio notifications ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Skontroluj či má aplikácia povolenie na presné alarmy (Android 13+)
  Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.canScheduleExactNotifications();
      return result ?? false;
    } catch (e) {
      _logger.e('❌ Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Požiadaj o povolenie pre presné alarmy (Android 13+)
  Future<void> requestExactAlarmPermission() async {
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      _logger.e('❌ Error requesting exact alarm permission: $e');
    }
  }

  /// Naplánovanie denných lectio notifikácií
  Future<void> _scheduleDailyLectioNotifications() async {
    try {
      // Skontroluj povolenie pre presné alarmy (Android 13+)
      final canSchedule = await canScheduleExactAlarms();
      if (!canSchedule) {
        _logger.w(
          '⚠️ Cannot schedule exact alarms - permission not granted. Using inexact scheduling.',
        );
        // Môžeme buď použiť inexact scheduling alebo informovať používateľa
        // Pre teraz budeme pokračovať s inexact
      }

      // Zruš existujúce notifikácie
      await _cancelDailyLectioNotifications();

      // Načítaj cached dáta alebo stiahni nové
      final lectioData = await _getCachedLectioData();

      for (int i = 0; i < 7; i++) {
        final notificationDate = DateTime.now().add(Duration(days: i));
        final scheduledTime = DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          9, // Správny čas 9:00
          0,
        );

        // Preskočíme ak je čas v minulosti
        if (scheduledTime.isBefore(DateTime.now())) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(notificationDate);
        final dayData = lectioData[dateKey];

        String title = 'Denné zamyslenie 📖';
        String body = 'Váš denný lectio divina text vás čaká. Otvoriť?';

        if (dayData != null) {
          title = dayData['hlava'] ?? title;
          body = dayData['actio_preview'] ?? body;
        }

        final payload = jsonEncode({
          'type': 'daily_lectio',
          'date': notificationDate.toIso8601String(),
        });

        // Použij exact alebo inexact scheduling podľa dostupnosti povolenia
        final scheduleMode = canSchedule
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;

        final location = tz.getLocation('Europe/Bratislava');
        await _notifications.zonedSchedule(
          dailyLectioBaseId + i,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, location),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_lectio_channel',
              'Denné zamyslenie',
              channelDescription: 'Denné lectio divina notifikácie',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              fullScreenIntent: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }

      _logger.i('📅 Scheduled ${7} daily lectio notifications');
    } catch (e) {
      _logger.e('❌ Error scheduling daily lectio notifications: $e');
    }
  }

  /// Zrušenie denných lectio notifikácií
  Future<void> _cancelDailyLectioNotifications() async {
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(dailyLectioBaseId + i);
    }
    _logger.i('🗑️ Cancelled daily lectio notifications');
  }

  /// Načítanie cached lectio dát alebo stiahnutie nových
  Future<Map<String, dynamic>> _getCachedLectioData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentLang = _getCurrentLanguage();
    final lastUpdateStr = prefs.getString('${_lastCacheUpdate}_$currentLang');
    final cachedDataStr = prefs.getString('${_cachedLectioData}_$currentLang');

    // Kontrola či cache nie je starý (viac ako 12 hodín)
    if (lastUpdateStr != null && cachedDataStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final cacheAge = DateTime.now().difference(lastUpdate);

      if (cacheAge.inHours < 12) {
        _logger.i(
          '📦 Using cached lectio data for $currentLang (age: ${cacheAge.inHours}h)',
        );
        return Map<String, dynamic>.from(jsonDecode(cachedDataStr));
      }
    }

    // Stiahni nové dáta
    return await _downloadAndCacheLectioData();
  }

  /// Stiahnutie a cachovanie lectio dát
  Future<Map<String, dynamic>> _downloadAndCacheLectioData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentLang = _getCurrentLanguage();
      final Map<String, dynamic> lectioData = {};

      _logger.i('🌍 Downloading lectio data for language: $currentLang');

      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        // Načítaj dáta pre daný deň (použij tú istú logiku ako v lectio_screen)
        final calendarResponse = await supabase
            .from('liturgical_calendar')
            .select('*, liturgical_years(*)')
            .eq('datum', dateStr)
            .eq('locale_code', currentLang)
            .maybeSingle();

        if (calendarResponse != null) {
          final lectioHlava = calendarResponse['lectio_hlava'];
          if (lectioHlava != null) {
            // Získaj lectio source
            final lectioSource = await supabase
                .from('lectio_sources')
                .select()
                .eq('hlava', lectioHlava)
                .eq('lang', currentLang)
                .eq('rok', 'N') // Defaultne všedné dni
                .maybeSingle();

            if (lectioSource != null) {
              lectioData[dateStr] = {
                'hlava': lectioSource['hlava'],
                'actio_preview': _truncateText(
                  lectioSource['actio_text'] ?? '',
                  100,
                ),
                'reference': lectioSource['reference'],
              };
            }
          }
        }
      }

      // Ulož do cache s jazykom
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_cachedLectioData}_$currentLang',
        jsonEncode(lectioData),
      );
      await prefs.setString(
        '${_lastCacheUpdate}_$currentLang',
        DateTime.now().toIso8601String(),
      );

      _logger.i('💾 Downloaded and cached lectio data for 7 days');
      return lectioData;
    } catch (e) {
      _logger.e('❌ Error downloading lectio data: $e');
      return {};
    }
  }

  /// Nastavenie času pripomenutia modlitby
  Future<void> setPrayerReminderTime(TimeOfDay? time) async {
    final prefs = await SharedPreferences.getInstance();

    if (time == null) {
      // Vypni pripomenutie
      await prefs.setBool(_prayerReminderEnabled, false);
      await _cancelPrayerReminder();
      _logger.i('🔕 Prayer reminder disabled');
      return;
    }

    // Ulož čas a zapni pripomenutie
    await prefs.setBool(_prayerReminderEnabled, true);
    await prefs.setString(_prayerReminderTime, '${time.hour}:${time.minute}');

    await _schedulePrayerReminder(time);
    _logger.i('⏰ Prayer reminder set for ${time.hour}:${time.minute}');
  }

  /// Naplánovanie pripomenutia modlitby
  Future<void> _schedulePrayerReminder(TimeOfDay time) async {
    try {
      // Skontroluj povolenie pre presné alarmy
      final canSchedule = await canScheduleExactAlarms();
      if (!canSchedule) {
        _logger.w(
          '⚠️ Cannot schedule exact alarms - permission not granted. Using inexact scheduling.',
        );
      }

      // Zruš existujúce
      await _cancelPrayerReminder();

      // Naplánuj na každý deň na najbližších 7 dní
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().add(Duration(days: i));
        var scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // Ak je čas dnes už prešiel, začni od zajtra
        if (i == 0 && scheduledTime.isBefore(DateTime.now())) {
          continue;
        }

        final payload = jsonEncode({
          'type': 'prayer_reminder',
          'date': scheduledTime.toIso8601String(),
        });

        // Použij exact alebo inexact scheduling podľa dostupnosti povolenia
        final scheduleMode = canSchedule
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;

        final location = tz.getLocation('Europe/Bratislava');
        await _notifications.zonedSchedule(
          prayerReminderBaseId + i,
          'Čas na modlitbu 🙏',
          'Pozvanie k chvíľke rozjímania s Bohom. Pripojiť sa?',
          tz.TZDateTime.from(scheduledTime, location),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_reminder_channel',
              'Pripomenutie modlitby',
              channelDescription: 'Pripomienky času na modlitbu',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              fullScreenIntent: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }

      _logger.i('📅 Scheduled prayer reminders for 7 days');
    } catch (e) {
      _logger.e('❌ Error scheduling prayer reminder: $e');
    }
  }

  /// Zrušenie pripomenutia modlitby
  Future<void> _cancelPrayerReminder() async {
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(prayerReminderBaseId + i);
    }
    _logger.i('🗑️ Cancelled prayer reminders');
  }

  /// Skrátenie textu pre notifikáciu
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Získanie aktuálnych nastavení
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final prayerTimeStr = prefs.getString(_prayerReminderTime);
    TimeOfDay? prayerTime;

    if (prayerTimeStr != null) {
      final parts = prayerTimeStr.split(':');
      prayerTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return {
      'daily_lectio_enabled': prefs.getBool(_dailyLectioEnabled) ?? false,
      'prayer_reminder_enabled': prefs.getBool(_prayerReminderEnabled) ?? false,
      'prayer_reminder_time': prayerTime,
      'welcome_notification_sent':
          prefs.getBool(_welcomeNotificationSent) ?? false,
    };
  }

  /// Refresh cache - volať pri spustení aplikácie ak je internet
  Future<void> refreshCacheIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final dailyEnabled = prefs.getBool(_dailyLectioEnabled) ?? false;

    if (dailyEnabled) {
      _logger.i('🔄 Refreshing lectio cache for daily notifications');
      await _downloadAndCacheLectioData();
      // Re-schedule notifikácie s novými dátami
      await _scheduleDailyLectioNotifications();
    }
  }

  /// ⚡ Žiada vypnutie Battery Optimization (nutné pre scheduled notifications na Android 13+)
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;

      if (!status.isGranted) {
        _logger.i(
          '🔋 Requesting ignore battery optimizations (needed for scheduled notifications)',
        );
        await Permission.ignoreBatteryOptimizations.request();
      } else {
        _logger.i('✅ Battery optimizations already disabled');
      }
    } catch (e) {
      _logger.e('❌ Error requesting battery optimization exemption: $e');
    }
  }

  /// Skontroluje či je Battery Optimization vypnutá
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      _logger.e('❌ Error checking battery optimization status: $e');
      return false;
    }
  }
}

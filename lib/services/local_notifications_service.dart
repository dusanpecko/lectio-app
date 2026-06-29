import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../controllers/notification_controller.dart';
import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';

class LocalNotificationsService {
  static LocalNotificationsService? _instance;
  static LocalNotificationsService get instance =>
      _instance ??= LocalNotificationsService._internal();

  static void setInstanceForTesting(LocalNotificationsService instance) {
    _instance = instance;
  }

  factory LocalNotificationsService() => instance;

  final FlutterLocalNotificationsPlugin _notifications;

  /// Verejný prístup k plugin inštancii — používa FcmService na foreground .show()
  FlutterLocalNotificationsPlugin get plugin => _notifications;

  // Private constructor
  LocalNotificationsService._internal()
    : _notifications = FlutterLocalNotificationsPlugin();

  // Internal constructor for testing
  @visibleForTesting
  LocalNotificationsService.internal({
    required FlutterLocalNotificationsPlugin notifications,
  }) : _notifications = notifications;

  final _logger = appLogger;

  bool _isInitialized = false;

  // Cached timezone location for scheduling
  tz.Location? _localTimezone;

  // Callback pre navigation handling
  Function(String?)? _notificationCallback;

  // Notification IDs
  static const int welcomeNotificationId = 1000;
  static const int prayerReminderBaseId = 3000; // 3000+ pre rôzne časy

  // SharedPreferences keys
  static const String _registrationDateKey = 'registration_date';
  static const String _welcomeNotificationSent = 'welcome_notification_sent';
  static const String _prayerReminderEnabled = 'prayer_reminder_enabled';
  static const String _prayerReminderTime = 'prayer_reminder_time';

  /// Detekcia a inicializácia lokálnej timezone
  Future<void> _initializeLocalTimezone() async {
    try {
      // Získaj timezone name z OS
      final String timezoneName = await _getNativeTimezoneName();
      _logger.i('🌍 Detected native timezone: $timezoneName');

      // Skús nájsť timezone v databáze
      try {
        _localTimezone = tz.getLocation(timezoneName);
        tz.setLocalLocation(_localTimezone!);
        _logger.i('✅ Timezone initialized: $timezoneName');
      } catch (e) {
        // Ak timezone nie je v databáze, použij fallback
        _logger.w(
          '⚠️ Timezone "$timezoneName" not found in database, using fallback',
        );
        _localTimezone = _getFallbackTimezone(timezoneName);
        tz.setLocalLocation(_localTimezone!);
        _logger.i('✅ Timezone fallback initialized: ${_localTimezone!.name}');
      }
    } catch (e) {
      // Ak natívna detekcia zlyhá, použij UTC ako posledná možnosť
      _logger.e('❌ Failed to detect native timezone: $e');
      _localTimezone = tz.UTC;
      tz.setLocalLocation(_localTimezone!);
      _logger.w('⚠️ Using UTC as fallback timezone');
    }
  }

  /// Získa názov timezone z operačného systému
  Future<String> _getNativeTimezoneName() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Na mobile získame timezone cez symlink alebo system property
        if (Platform.isAndroid) {
          // Android: skúsime prečítať /etc/localtime symlink alebo property
          try {
            final link = await Link('/etc/localtime').target();
            // Link je typicky /usr/share/zoneinfo/Europe/Bratislava
            final parts = link.split('/zoneinfo/');
            if (parts.length > 1) {
              return parts.last;
            }
          } catch (_) {
            // Fallback - použijeme DateTime info
          }
        }

        // iOS a Android fallback: odhadneme timezone z offsetu a DST
        return _guessTimezoneFromOffset();
      } else {
        // Desktop/Web - použijeme DateTime.now().timeZoneName
        final tzName = DateTime.now().timeZoneName;
        // Preložíme skratky na plné názvy
        return _resolveTimezoneAbbreviation(tzName);
      }
    } catch (e) {
      _logger.w('⚠️ Could not get native timezone name: $e');
      return _guessTimezoneFromOffset();
    }
  }

  /// Odhadne timezone na základe aktuálneho offsetu a DST
  String _guessTimezoneFromOffset() {
    final now = DateTime.now();
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = now.timeZoneOffset.inMinutes % 60;

    _logger.i('🕐 Current offset: ${offsetHours}h ${offsetMinutes}m');

    // Mapa offsetov na bežné timezone (priorita pre európske kvôli cieľovej skupine)
    // Formát: offset v hodinách -> timezone name
    final Map<int, String> offsetToTimezone = {
      -12: 'Pacific/Fiji',
      -11: 'Pacific/Midway',
      -10: 'Pacific/Honolulu',
      -9: 'America/Anchorage',
      -8: 'America/Los_Angeles',
      -7: 'America/Denver',
      -6: 'America/Chicago',
      -5: 'America/New_York',
      -4: 'America/Halifax',
      -3: 'America/Sao_Paulo',
      -2: 'Atlantic/South_Georgia',
      -1: 'Atlantic/Azores',
      0: 'Europe/London',
      1: 'Europe/Paris', // CET - Stredná Európa (SK, CZ, DE, AT, PL...)
      2: 'Europe/Kyiv', // EET - Východná Európa
      3: 'Europe/Moscow',
      4: 'Asia/Dubai',
      5: 'Asia/Karachi',
      6: 'Asia/Dhaka',
      7: 'Asia/Bangkok',
      8: 'Asia/Singapore',
      9: 'Asia/Tokyo',
      10: 'Australia/Sydney',
      11: 'Pacific/Noumea',
      12: 'Pacific/Auckland',
    };

    return offsetToTimezone[offsetHours] ?? 'Europe/Paris';
  }

  /// Preloží skratku timezone na plný IANA názov
  String _resolveTimezoneAbbreviation(String abbreviation) {
    final Map<String, String> abbreviationToTimezone = {
      // Stredoeurópsky čas
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'Central European Time': 'Europe/Paris',
      'Central European Summer Time': 'Europe/Paris',
      // Východoeurópsky čas
      'EET': 'Europe/Kyiv',
      'EEST': 'Europe/Kyiv',
      // Západoeurópsky čas
      'WET': 'Europe/London',
      'WEST': 'Europe/London',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      // Americké timezone
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      // Ázijské
      'JST': 'Asia/Tokyo',
      'KST': 'Asia/Seoul',
      'IST': 'Asia/Kolkata',
      'CST China': 'Asia/Shanghai',
    };

    // Ak je to už IANA formát (obsahuje /), vráť ako je
    if (abbreviation.contains('/')) {
      return abbreviation;
    }

    return abbreviationToTimezone[abbreviation] ?? _guessTimezoneFromOffset();
  }

  /// Získa fallback timezone na základe názvu alebo offsetu
  tz.Location _getFallbackTimezone(String timezoneName) {
    // Skús preložiť skratku na IANA názov
    final resolvedName = _resolveTimezoneAbbreviation(timezoneName);

    try {
      return tz.getLocation(resolvedName);
    } catch (_) {
      // Fallback na základe offsetu
      final guessedName = _guessTimezoneFromOffset();
      try {
        return tz.getLocation(guessedName);
      } catch (_) {
        _logger.w('⚠️ Could not find suitable timezone, using UTC');
        return tz.UTC;
      }
    }
  }

  /// Získa aktuálnu timezone location (cached)
  tz.Location get _currentTimezone => _localTimezone ?? tz.UTC;

  /// Verejný prístup k IANA timezone názvu (pre FCM token registráciu)
  String get currentTimezoneName => _currentTimezone.name;

  /// Inicializácia lokálnych notifikácií
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Inicializuj timezone a nastav lokálnu timezone dynamicky
      tz.initializeTimeZones();
      await _initializeLocalTimezone();

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

      // Channel pre FCM push notifikácie (foreground + background)
      const AndroidNotificationChannel fcmPushChannel =
          AndroidNotificationChannel(
            'lectio_divina_notifications',
            'Lectio Divina Notifications',
            description: 'Notifications for Lectio Divina app',
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
        _logger.i('🔧 Creating FCM push channel...');
        await androidPlugin.createNotificationChannel(fcmPushChannel);
        _logger.i('✅ Android notification channels created');
      } else {
        _logger.e('❌ androidPlugin is NULL - channels NOT created!');
      }

      // iOS nastavenia
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // macOS nastavenia
      const DarwinInitializationSettings initializationSettingsMacOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsMacOS,
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

      // FCM push notifikácie majú 'screen' field — deleguj na callback chain
      final screen = payload['screen'] as String?;
      if (screen != null) {
        _logger.i('📱 FCM push notification detected (screen=$screen)');
        handleExternalNotificationTap(response.payload);
        return;
      }

      final type = payload['type'] as String?;

      switch (type) {
        case 'daily_lectio':
          final dateStr = payload['date'] as String?;
          if (dateStr != null) {
            try {
              final date = DateTime.parse(dateStr);
              _navigateToLectio(date);
            } catch (e) {
              _logger.e(
                '❌ Invalid date format in daily_lectio payload: $dateStr',
              );
              _navigateToLectio(DateTime.now()); // Fallback na dnešný dátum
            }
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

  /// Získaj preložený text notifikácie podľa aktuálneho jazyka
  String _getNotificationText(String key) {
    final lang = _getCurrentLanguage();
    const texts = {
      'sk': {
        'welcome_title': 'Vitajte v Lectio Divina! 🙏',
        'welcome_body':
            'Objavte krásu modlitbového čítania Písma. Ste pripravení na duchovnú cestu?',
        'daily_title': 'Denné zamyslenie 📖',
        'daily_body': 'Váš denný lectio divina text vás čaká. Otvoriť?',
        'prayer_title': 'Čas na modlitbu 🙏',
        'prayer_body': 'Pozvanie k chvíľke rozjímania s Bohom. Pripojiť sa?',
      },
      'en': {
        'welcome_title': 'Welcome to Lectio Divina! 🙏',
        'welcome_body':
            'Discover the beauty of prayerful Scripture reading. Are you ready for a spiritual journey?',
        'daily_title': 'Daily Reflection 📖',
        'daily_body': 'Your daily lectio divina text is waiting. Open?',
        'prayer_title': 'Time for Prayer 🙏',
        'prayer_body':
            'An invitation to a moment of meditation with God. Join?',
      },
      'es': {
        'welcome_title': '¡Bienvenido a Lectio Divina! 🙏',
        'welcome_body':
            'Descubre la belleza de la lectura orante de las Escrituras. ¿Estás listo para un viaje espiritual?',
        'daily_title': 'Reflexión diaria 📖',
        'daily_body': 'Tu texto diario de lectio divina te espera. ¿Abrir?',
        'prayer_title': 'Hora de orar 🙏',
        'prayer_body':
            'Una invitación a un momento de meditación con Dios. ¿Unirse?',
      },
      'fr': {
        'welcome_title': 'Bienvenue dans Lectio Divina ! 🙏',
        'welcome_body':
            'Découvre la beauté de la lecture priante des Écritures. Es-tu prêt pour un chemin spirituel ?',
        'daily_title': 'Méditation du jour 📖',
        'daily_body': 'Ton texte quotidien de lectio divina t\'attend. Ouvrir ?',
        'prayer_title': 'Le temps de la prière 🙏',
        'prayer_body':
            'Une invitation à un moment de recueillement avec Dieu. Rejoindre ?',
      },
    };
    return texts[lang]?[key] ?? texts['en']?[key] ?? texts['sk']![key]!;
  }

  /// Získanie aktuálneho jazyka aplikácie
  String _getCurrentLanguage() {
    try {
      // Pokús sa získať jazyk z EasyLocalization
      final context =
          NotificationController.instance.navigatorKey.currentContext;
      if (context != null) {
        return context.locale.languageCode;
      }
    } catch (e) {
      _logger.w('Could not get current language from context: $e');
    }
    // Fallback na angličtinu (predvolený jazyk)
    return 'en';
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

      DateTime registrationDate;
      try {
        registrationDate = DateTime.parse(registrationDateStr);
      } catch (e) {
        _logger.e('❌ Invalid registration date format: $registrationDateStr');
        // Fallback: použijeme dnešný dátum
        registrationDate = DateTime.now();
      }
      final welcomeDate = registrationDate.add(
        const Duration(
          days: NotificationConstants.welcomeNotificationDaysAfterRegistration,
        ),
      );

      // Nastav na predvolený čas
      final scheduledDate = DateTime(
        welcomeDate.year,
        welcomeDate.month,
        welcomeDate.day,
        NotificationConstants.welcomeNotificationHour,
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

      await _notifications.zonedSchedule(
        welcomeNotificationId,
        _getNotificationText('welcome_title'),
        _getNotificationText('welcome_body'),
        tz.TZDateTime.from(scheduledDate, _currentTimezone),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'welcome_channel',
            'Uvítacie notifikácie',
            channelDescription: 'Uvítacie správy pre nových používateľov',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            fullScreenIntent: true,
            number: 1,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      _logger.i('📅 Welcome notification scheduled for: $scheduledDate');
    } catch (e) {
      _logger.e('❌ Error scheduling welcome notification: $e');
    }
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

      // Naplánuj na každý deň na najbližších N dní
      for (int i = 0; i < NotificationConstants.scheduleDaysAhead; i++) {
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

        await _notifications.zonedSchedule(
          prayerReminderBaseId + i,
          _getNotificationText('prayer_title'),
          _getNotificationText('prayer_body'),
          tz.TZDateTime.from(scheduledTime, _currentTimezone),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_reminder_channel',
              'Pripomenutie modlitby',
              channelDescription: 'Pripomienky času na modlitbu',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              fullScreenIntent: true,
              number: 1,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              badgeNumber: 1,
            ),
            macOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              badgeNumber: 1,
            ),
          ),
          androidScheduleMode: scheduleMode,
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
    for (int i = 0; i < NotificationConstants.scheduleDaysAhead; i++) {
      await _notifications.cancel(prayerReminderBaseId + i);
    }
    _logger.i('🗑️ Cancelled prayer reminders');
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
      'prayer_reminder_enabled': prefs.getBool(_prayerReminderEnabled) ?? false,
      'prayer_reminder_time': prayerTime,
      'welcome_notification_sent':
          prefs.getBool(_welcomeNotificationSent) ?? false,
    };
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

// lib/services/fcm_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'notification_api.dart';
import '../models/notification_models.dart';

final Logger _logger = Logger();

/// Global instance pre local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// TOP-LEVEL background handler – musí byť mimo triedy.
/// Zobrazuje lokálne notifikácie pre background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _logger.i('Background message received: ${message.data}');

  // Zobraz lokálnu notifikáciu pre background messages
  await _showLocalNotification(message);
}

/// Helper funkcia pre zobrazenie lokálnej notifikácie
Future<void> _showLocalNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'lectio_divina_notifications',
          'Lectio Divina Notifications',
          channelDescription: 'Notifications for Lectio Divina app',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/launcher_icon',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  } catch (e) {
    _logger.e('Error showing local notification: $e');
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  // Rate limiting pre APNS token retry
  int _apnsRetryCount = 0;
  static const int _maxApnsRetries = 3;

  // Local notifications initialized flag
  bool _localNotificationsInitialized = false;

  // Current FCM token
  String? _currentToken;

  // API service instance
  final NotificationAPI _api = NotificationAPI.instance;

  // Callback pre handling notifikácií
  Function(RemoteMessage)? _onNotificationCallback;

  String _toLocaleCode(String appLang) {
    // DB používa 'cz'; ak v UI máš 'cs', mapujeme na 'cz'
    switch (appLang) {
      case 'cs':
        return 'cz';
      default:
        return appLang; // sk, en, es, de...
    }
  }

  /// Inicializuje local notifications
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // Vytvor Android notification channel
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'lectio_divina_notifications',
                'Lectio Divina Notifications',
                description: 'Notifications for Lectio Divina app',
                importance: Importance.high,
              ),
            );
      }

      _localNotificationsInitialized = true;
      _logger.i('Local notifications initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize local notifications: $e');
    }
  }

  /// Callback pre kliknutie na lokálnu notifikáciu
  void _onLocalNotificationTapped(NotificationResponse response) {
    _logger.i('Local notification tapped with payload: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        _logger.e('Error parsing notification payload: $e');
      }
    }
  }

  /// Spracuje dáta z notifikácie (navigácia, akcie...)
  void _handleNotificationData(Map<String, dynamic> data) {
    _logger.i('Handling notification data: $data');

    // Tu môžeš implementovať navigáciu podľa typu notifikácie
    final type = data['type'] as String?;

    switch (type) {
      case 'lectio':
        // Naviguj na lectio screen
        break;
      case 'news':
        // Naviguj na news detail
        break;
      case 'reminder':
        // Naviguj na reminder screen
        break;
      default:
        // Fallback - naviguj na home
        break;
    }
  }

  Future<void> init(String appLangCode) async {
    _logger.i('Initializing FCM with language: $appLangCode');
    final m = FirebaseMessaging.instance;

    // Inicializuj local notifications ako prvé
    await _initializeLocalNotifications();

    // Povolenia pre FCM
    if (Platform.isIOS) {
      final settings = await m.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _logger.i(
        'iOS notification permission status: ${settings.authorizationStatus}',
      );
      await m.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      final st = await Permission.notification.status;
      _logger.i('Android notification permission status: $st');
      if (!st.isGranted) {
        final result = await Permission.notification.request();
        _logger.i('Android permission request result: $result');
      }
    }

    // Registruj background handler (top-level funkcia)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground message handler - zobraz lokálne notifikácie
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _logger.i('Foreground message received:');
      _logger.i('Title: ${message.notification?.title}');
      _logger.i('Body: ${message.notification?.body}');
      _logger.i('Data: ${message.data}');

      // Zobraz lokálnu notifikáciu pre foreground messages
      await _showLocalNotification(message);
    });

    // Handler pre otvorenie app z notifikácie
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('App opened from notification: ${message.data}');
      if (_onNotificationCallback != null) {
        _onNotificationCallback!(message);
      } else {
        _handleNotificationData(message.data);
      }
    });

    // Skontroluj či app bol otvorený z notifikácie
    final initialMessage = await m.getInitialMessage();
    if (initialMessage != null) {
      _logger.i('App launched from notification: ${initialMessage.data}');
      if (_onNotificationCallback != null) {
        _onNotificationCallback!(initialMessage);
      } else {
        _handleNotificationData(initialMessage.data);
      }
    }

    // Prvé zaregistrovanie tokenu + témy
    await _register(appLangCode);

    // Refresh tokenu
    m.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _register(appLangCode);
    });

    // Keď sa zmení prihlásený user, dopíš user_id k tokenu
    Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
      await _register(appLangCode);
    });
  }

  Future<void> _register(String appLangCode) async {
    try {
      final m = FirebaseMessaging.instance;

      // Pre iOS, počkáme na APNS token ak ešte nie je dostupný
      if (Platform.isIOS) {
        try {
          final apnsToken = await m.getAPNSToken();
          if (apnsToken == null) {
            if (_apnsRetryCount < _maxApnsRetries) {
              _apnsRetryCount++;
              _logger.w(
                'APNS token not available yet, retrying in 2 seconds... (attempt $_apnsRetryCount/$_maxApnsRetries)',
              );
              await Future.delayed(const Duration(seconds: 2));
              return _register(appLangCode); // Rekurzívne zavolanie
            } else {
              _logger.w(
                'Max APNS token retry attempts reached. Continuing without APNS token.',
              );
              _apnsRetryCount = 0; // Reset pre budúce pokusy
            }
          } else {
            _logger.i('APNS token available: ${apnsToken.substring(0, 20)}...');
            _apnsRetryCount = 0; // Reset úspešných pokusov
          }
        } catch (e) {
          _logger.w(
            'Failed to get APNS token: $e. Continuing with FCM token only.',
          );
          _apnsRetryCount = 0; // Reset pri chybe
        }
      }

      final token = await m.getToken();
      if (token == null || token.isEmpty) {
        _logger.w('FCM token is null or empty');
        return;
      }

      _currentToken = token;
      _logger.i('FCM Token: ${token.substring(0, 20)}...');

      final code = _toLocaleCode(appLangCode); // 'sk'|'en'|'cz'|'es'|'de'
      final platform = Platform.isIOS ? 'ios' : 'android';
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      _logger.i('Registering with locale: $code, platform: $platform');

      // Registruj token na backend API (Supabase)
      try {
        await _api.registerFCMToken(
          fcmToken: token,
          deviceType: platform,
          appVersion: appVersion,
          deviceId: null, // Optional: Add device ID if needed
        );
        _logger.i('Token registered in Supabase via API');
      } catch (apiError) {
        _logger.w('API registration failed: $apiError');
        // Pokračuj s lokálnou registráciou
      }

      // Upsert do Supabase DB - fallback
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;

        await Supabase.instance.client.from('push_tokens').upsert({
          'token': token,
          'platform': platform,
          'locale_code': code,
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        });

        _logger.i('Token successfully registered in Supabase database');
      } catch (dbError) {
        _logger.e('Supabase database error (continuing anyway): $dbError');
        // Pokračujeme aj s chybou DB
      }

      _logger.i('Successfully registered FCM token with backend');
    } catch (e) {
      _logger.e('Error in FCM registration: $e');
    }
  }

  /// Zavolaj pri zmene jazyka v appke
  Future<void> onLanguageChanged(String oldAppLang, String newAppLang) async {
    try {
      _logger.i('Language changed from $oldAppLang to $newAppLang');
      final m = FirebaseMessaging.instance;
      final newCode = _toLocaleCode(newAppLang);

      final token = await m.getToken();
      if (token != null) {
        // Aktualizuj v backend API
        try {
          final platform = Platform.isIOS ? 'ios' : 'android';
          final packageInfo = await PackageInfo.fromPlatform();
          final appVersion =
              '${packageInfo.version}+${packageInfo.buildNumber}';

          await _api.registerFCMToken(
            fcmToken: token,
            deviceType: platform,
            appVersion: appVersion,
          );
        } catch (e) {
          _logger.w('Failed to update language on backend API: $e');
        }

        // Aktualizuj v Supabase DB
        try {
          await Supabase.instance.client
              .from('push_tokens')
              .update({'locale_code': newCode})
              .eq('token', token);
        } catch (e) {
          _logger.w('Failed to update language in Supabase: $e');
        }
      }
      _logger.i('Language change completed');
    } catch (e) {
      _logger.e('Error changing language: $e');
    }
  }

  /// Získa notification preferences z backend API
  Future<NotificationPreferencesResponse?> getNotificationPreferences({
    bool forceRefresh = false,
  }) async {
    try {
      return await _api.getNotificationPreferences(forceRefresh: forceRefresh);
    } catch (e) {
      _logger.e('Failed to get notification preferences: $e');
      return null;
    }
  }

  /// Aktualizuje preferencie pre konkrétny topic
  Future<bool> updateTopicPreference(String topicId, bool isEnabled) async {
    try {
      // Ulož do databázy - backend bude používať multicast na FCM tokeny
      await _api.updateTopicPreference(topicId: topicId, isEnabled: isEnabled);
      _logger.i(
        '✅ Updated topic preference in database: $topicId = $isEnabled',
      );

      return true;
    } catch (e) {
      _logger.e('❌ Failed to update topic preference: $e');
      return false;
    }
  }

  /// Hromadne aktualizuje viacero topic preferencií
  Future<bool> updateMultipleTopicPreferences(
    Map<String, bool> preferences,
  ) async {
    try {
      // Ulož do databázy - backend bude používať multicast na FCM tokeny
      await _api.updateMultipleTopicPreferences(preferences: preferences);
      _logger.i(
        '✅ Updated ${preferences.length} topic preferences in database',
      );

      return true;
    } catch (e) {
      _logger.e('❌ Failed to update multiple topic preferences: $e');
      return false;
    }
  }

  /// Deaktivuje FCM token (pri odhlásení)
  Future<void> deactivateToken() async {
    try {
      if (_currentToken != null) {
        await _api.deactivateFCMToken(_currentToken!);
        _logger.i('FCM token deactivated');
      }
    } catch (e) {
      _logger.e('Failed to deactivate FCM token: $e');
    }
  }

  /// Získa aktuálny FCM token
  Future<String?> getCurrentToken() async {
    try {
      final m = FirebaseMessaging.instance;
      final token = await m.getToken();
      _currentToken = token;
      return token;
    } catch (e) {
      _logger.e('Failed to get current FCM token: $e');
      return null;
    }
  }

  /// Testuje notification permissions
  Future<bool> hasNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      } else if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return false;
    } catch (e) {
      _logger.e('Failed to check notification permissions: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      } else if (Platform.isAndroid) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return false;
    } catch (e) {
      _logger.e('Failed to request notification permissions: $e');
      return false;
    }
  }

  /// Nastaví callback pre spracovanie notifikácií
  void setNotificationCallback(Function(RemoteMessage) callback) {
    _onNotificationCallback = callback;
  }
}

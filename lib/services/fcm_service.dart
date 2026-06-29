// lib/services/fcm_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';
import '../utils/app_logger.dart';
import 'local_notifications_service.dart';
import 'notification_api.dart';

/// Logger pre background handler (musí byť top-level kvôli izolovanému kontextu)
final _backgroundLogger = appLogger;

/// TOP-LEVEL background handler – musí byť mimo triedy.
/// Na Androide pri notification+data payloadoch systém sám zobrazí notifikáciu,
/// preto zobrazujeme lokálnu len na iOS/macOS (kde je to potrebné).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _backgroundLogger.i('Background message received: ${message.data}');

  // Na Androide systém zobrazí notifikáciu automaticky (notification payload).
  // Ak by sme ju zobrazili aj my, používateľ by videl duplikát.
  if (!Platform.isAndroid) {
    await _showLocalNotification(message);
  }
}

/// Helper funkcia pre zobrazenie lokálnej notifikácie
/// V background isolate nemáme prístup k LocalNotificationsService singleton,
/// preto vytvárame a inicializujeme lokálnu inštanciu pluginu.
Future<void> _showLocalNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    if (notification == null) return;

    // Inicializuj lokálnu inštanciu — v background isolate nie je dostupný singleton
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );

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

    const DarwinNotificationDetails macOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
      macOS: macOSPlatformChannelSpecifics,
    );

    await plugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  } catch (e) {
    _backgroundLogger.e('Error showing local notification: $e');
  }
}

class FcmService {
  FcmService._();
  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService._();

  static void setInstanceForTesting(FcmService instance) {
    _instance = instance;
  }

  /// Logger pre inštanciu služby
  final _logger = appLogger;

  // Rate limiting pre APNS token retry
  int _apnsRetryCount = 0;
  static const int _maxApnsRetries = 3;

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

  /// Zobrazí foreground notifikáciu cez zdieľaný plugin z LocalNotificationsService.
  /// Tap callback je jednotný — spracuje ho LocalNotificationsService._onNotificationTapped.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'lectio_divina_notifications',
            'Lectio Divina Notifications',
            channelDescription: 'Notifications for Lectio Divina app',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'ticker',
            icon: '@mipmap/launcher_icon',
            number: 1,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      const DarwinNotificationDetails macosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: macosDetails,
      );

      await LocalNotificationsService.instance.plugin.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      _logger.e('Error showing foreground notification: $e');
    }
  }

  Future<void> init(String appLangCode) async {
    _logger.i('Initializing FCM with language: $appLangCode');
    final m = FirebaseMessaging.instance;

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

      // Zobraz lokálnu notifikáciu cez zdieľaný plugin (LocalNotificationsService)
      await _showForegroundNotification(message);
    });

    // Handler pre otvorenie app z notifikácie
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('App opened from notification: ${message.data}');
      if (_onNotificationCallback != null) {
        _onNotificationCallback!(message);
      }
    });

    // Skontroluj či app bol otvorený z notifikácie
    final initialMessage = await m.getInitialMessage();
    if (initialMessage != null) {
      _logger.i('App launched from notification: ${initialMessage.data}');
      if (_onNotificationCallback != null) {
        _onNotificationCallback!(initialMessage);
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
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isMacOS
          ? 'macos'
          : 'android';
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      _logger.i('Registering with locale: $code, platform: $platform');

      // Získaj IANA timezone pre timezone-aware push notifikácie
      final timezone = LocalNotificationsService.instance.currentTimezoneName;

      // Registruj token na backend API (Supabase)
      // Používame SPRÁVNU tabuľku: user_fcm_tokens (nie push_tokens)
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;

        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'token': token,
          'device_type': platform,
          'locale_code': code,
          'app_version': appVersion,
          'user_id': userId,
          'timezone': timezone,
          'is_active': true,
          'last_used_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'token');

        _logger.i(
          '✅ Token successfully registered in Supabase (user_fcm_tokens)',
        );
      } catch (dbError) {
        _logger.e('❌ Supabase registration failed: $dbError');
        // Pokračujeme aj s chybou - token je stále platný lokálne
      }

      _logger.i('Successfully completed FCM token registration');
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
        // Aktualizuj v Supabase DB - použijeme správnu tabuľku user_fcm_tokens
        try {
          await Supabase.instance.client
              .from('user_fcm_tokens')
              .update({
                'locale_code': newCode,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('token', token);
          _logger.i('✅ Language updated in Supabase (user_fcm_tokens)');
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
        // Deaktivuj v databáze - použijeme správnu tabuľku user_fcm_tokens
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('token', _currentToken!);
        _logger.i('✅ FCM token deactivated (user_fcm_tokens)');
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

  /// Vráti `true`, ak sú notifikácie zablokované na úrovni systému a OS už
  /// znova nezobrazí dialóg s povolením — používateľa treba poslať do
  /// systémových nastavení (cez [openSystemNotificationSettings]).
  Future<bool> isNotificationPermissionBlocked() async {
    try {
      if (Platform.isIOS) {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        // `denied` = používateľ to už raz zamietol → iOS znova nepýta.
        // `notDetermined` = ešte sa nepýtalo → dialóg sa dá zobraziť.
        return settings.authorizationStatus == AuthorizationStatus.denied;
      } else if (Platform.isAndroid) {
        // Permanentne zamietnuté (Android 13+) → request() už dialóg nezobrazí.
        return await Permission.notification.isPermanentlyDenied;
      }
      return false;
    } catch (e) {
      _logger.e('Failed to check blocked notification permission: $e');
      return false;
    }
  }

  /// Otvorí systémové nastavenia aplikácie (sekcia povolení).
  Future<bool> openSystemNotificationSettings() => openAppSettings();

  /// Nastaví callback pre spracovanie notifikácií
  void setNotificationCallback(Function(RemoteMessage) callback) {
    _onNotificationCallback = callback;
  }

  /// Aktualizuje preferovaný čas denného lectia v user_fcm_tokens
  /// [time] je TimeOfDay alebo null (reset na default 08:00)
  Future<bool> updatePreferredLectioTime(TimeOfDay? time) async {
    try {
      final token = _currentToken ?? await getCurrentToken();
      if (token == null) {
        _logger.w('Cannot update preferred lectio time: no FCM token');
        return false;
      }

      final timeStr = time != null
          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
          : '08:00';

      await Supabase.instance.client
          .from('user_fcm_tokens')
          .update({
            'preferred_lectio_time': timeStr,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('token', token);

      _logger.i('✅ Preferred lectio time updated to $timeStr');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to update preferred lectio time: $e');
      return false;
    }
  }

  /// Získa preferovaný čas denného lectia z user_fcm_tokens
  Future<TimeOfDay?> getPreferredLectioTime() async {
    try {
      final token = _currentToken ?? await getCurrentToken();
      if (token == null) return null;

      final result = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('preferred_lectio_time')
          .eq('token', token)
          .maybeSingle();

      if (result == null) return null;

      final timeStr = result['preferred_lectio_time'] as String?;
      if (timeStr == null) return null;

      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get preferred lectio time: $e');
      return null;
    }
  }
}

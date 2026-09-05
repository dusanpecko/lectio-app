import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lectio_divina/controllers/notification_controller.dart';
import 'package:lectio_divina/shared/env_error_app.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/background_audio_manager.dart';
import 'services/local_notifications_service.dart';
import 'services/umami_analytics_service.dart';
import 'utils/app_logger.dart';

typedef AppBuilder = Widget Function();

Future<void> bootstrap(AppBuilder builder) async {
  final logger = appLogger;

  // 1. Core Binding
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Config & Utils
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Bratislava'));
  logger.i('✅ Timezone initialized');

  try {
    await dotenv.load();
  } catch (e) {
    logger.w('.env loading failed: $e');
  }

  await EasyLocalization.ensureInitialized();

  // 3. Check Critical Config
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    logger.e('Missing Supabase Config');
    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('sk'),
          Locale('es'),
          Locale('fr'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const EnvErrorApp(),
      ),
    );
    return;
  }

  // 4. Initialize Core Services
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  // 5. Initialize Feature Services

  // Local Notifications - set callback FIRST
  try {
    LocalNotificationsService.instance.setNotificationCallback(
      NotificationController.instance.handleLocalNotificationTap,
    );
    await LocalNotificationsService.instance.initialize();
    logger.i('✅ Local Notifications initialized');
  } catch (e) {
    logger.e('❌ Local Notifications init failed: $e');
  }

  // Audio
  try {
    await BackgroundAudioManager().initialize();
    logger.i('✅ Audio initialized');
  } catch (e) {
    logger.e('❌ Audio init failed: $e');
  }

  // Analytics
  try {
    await UmamiAnalyticsService().initialize();
  } catch (e) {
    logger.e('❌ Analytics init failed: $e');
  }

  // 6. Theme & Locale
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  final startLocale = await _getStartLocale(themeProvider.languageCode);

  // 7. Run App
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('sk'),
          Locale('es'),
          Locale('fr'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: startLocale,
        child: builder(),
      ),
    ),
  );
}

Future<Locale> _getStartLocale(String languageCode) async {
  if (languageCode == 'system') {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLanguages = ['en', 'sk', 'es', 'fr'];
    return supportedLanguages.contains(systemLocale.languageCode)
        ? Locale(systemLocale.languageCode)
        : const Locale('en');
  }
  return Locale(languageCode);
}

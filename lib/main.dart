import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/home_screen.dart';
import 'package:lectio_divina/screens/lectio_screen.dart';
import 'package:lectio_divina/services/notification_service.dart';
import 'package:lectio_divina/shared/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ===== BACKGROUND HANDLER =====
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  try {
    await dotenv.load();
  } catch (_) {
    // pre istotu - dotenv už môže byť načítané
  }

  // Supabase už bude zvyčajne inicializovaný
  _logger.i(
    '[FirebaseMessaging] Handling a background message: ${message.messageId}',
  );
  final locale = message.data['locale'] ?? 'sk';
  await NotificationService.logNotificationOpen(locale);
}

// ===== PERMISSION HANDLER =====
Future<void> requestAndroidNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.notification.request();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Skús načítať .env, ošetri chybu ak by súbor neexistoval
  try {
    await dotenv.load();
  } catch (e) {
    _logger.w('.env loading failed: $e');
  }

  await EasyLocalization.ensureInitialized();

  // Firebase musí byť pred FCM
  await Firebase.initializeApp();

  // Registrácia background handlera
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Supabase init
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await NotificationService.initialize();
  await requestAndroidNotificationPermission();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('sk'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('sk'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lectio Divina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SessionHandler(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routes: {'/lectio': (context) => const LectioScreen()},
    );
  }
}

class SessionHandler extends StatefulWidget {
  const SessionHandler({super.key});
  @override
  State<SessionHandler> createState() => _SessionHandlerState();
}

class _SessionHandlerState extends State<SessionHandler> {
  Session? session;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    session = Supabase.instance.client.auth.currentSession;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      if (!mounted) return;
      setState(() {
        session = Supabase.instance.client.auth.currentSession;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const AuthScreen();
    } else {
      return const HomeScreen();
    }
  }
}

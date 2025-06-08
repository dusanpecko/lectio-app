import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:audio_service/audio_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'shared/app_theme.dart';
import 'services/audio_handler.dart';
import 'dart:async';

// ===== ZMENA: Typ je teraz naša konkrétna trieda LectioAudioHandler =====
late LectioAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  audioHandler = await AudioService.init(
    builder: () => LectioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'sk.dusanpecko.lectio_divina.channel.audio',
      androidNotificationChannelName: 'Prehrávanie audia',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('sk'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('sk'),
      child: const MyApp(),
    ),
  );
}

// Ostatok súboru main.dart zostáva bez zmeny
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('app_title'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SessionHandler(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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

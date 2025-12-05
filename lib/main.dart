import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/home_screen.dart';
import 'package:lectio_divina/screens/lectio_screen.dart';
import 'package:lectio_divina/shared/app_theme.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'shared/app_colors.dart';
import 'services/background_audio_manager.dart';
import 'services/fcm_service.dart';
import 'services/local_notifications_service.dart';

final Logger _logger = Logger();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

AudioHandler? globalAudioHandler;

// Globálna premenná pre čakajúcu notifikáciu
String? _pendingNotificationPayload;

/// Getter pre pending notification
String? getPendingNotification() {
  _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  _logger.i('🔍 getPendingNotification() CALLED');
  _logger.i(
    '🔍 Current _pendingNotificationPayload: $_pendingNotificationPayload',
  );

  final payload = _pendingNotificationPayload;
  _pendingNotificationPayload = null; // Vymaž po prečítaní

  _logger.i('🔍 Returning payload: $payload');
  _logger.i('🔍 Cleared _pendingNotificationPayload to null');
  _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  return payload;
}

// Method channel pre komunikáciu s natívnym iOS kódom
const MethodChannel _badgeChannel = MethodChannel('com.lectio_divina/badge');

/// Vyčistí badge na aplikačnej ikone
void _clearAppBadge() async {
  if (!Platform.isIOS) return;

  try {
    await _badgeChannel.invokeMethod('clearBadge');
    _logger.i('iOS badge cleared successfully via native channel');
  } catch (e) {
    _logger.w('Failed to clear badge via native channel: $e');
    // Badge sa vyčistí automaticky keď user otvorí app z notifikácie
  }
}

/// Získa správnu štartovaciu lokalizáciu na základe uloženého nastavenia
Future<Locale> _getStartLocale(String languageCode) async {
  if (languageCode == 'system') {
    // Pre 'system' použij systémový jazyk
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLanguages = ['sk', 'en'];
    final systemLang = supportedLanguages.contains(systemLocale.languageCode)
        ? systemLocale.languageCode
        : 'sk';
    return Locale(systemLang);
  } else {
    // Použij explicitne zvolený jazyk
    return Locale(languageCode);
  }
}

/// Spracovanie kliknutia na push notifikáciu
void _handleNotificationTap(RemoteMessage message) {
  _logger.i('Handling notification tap with message: ${message.data}');

  try {
    _clearAppBadge();

    if (navigatorKey.currentContext != null) {
      final currentRoute = ModalRoute.of(
        navigatorKey.currentContext!,
      )?.settings.name;

      if (currentRoute != '/') {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }

      Future.delayed(const Duration(milliseconds: 800), () {
        if (navigatorKey.currentContext != null) {
          _showNotificationDialog(navigatorKey.currentContext!, message);
        }
      });
    }
  } catch (e) {
    _logger.e('Error handling notification tap: $e');
  }
}

/// Spracovanie kliknutia na lokálnu notifikáciu
void _handleLocalNotificationTap(String? payload) {
  _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  _logger.i('🎯 LOCAL NOTIFICATION TAP HANDLER CALLED!');
  _logger.i('🎯 Payload received: $payload');
  _logger.i(
    '🎯 Current _pendingNotificationPayload before: $_pendingNotificationPayload',
  );
  _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    _clearAppBadge();

    // Jednoducho ulož payload pre neskoršie spracovanie
    _pendingNotificationPayload = payload;
    _logger.i('✅ Successfully stored pending notification payload');
    _logger.i(
      '📍 New _pendingNotificationPayload value: $_pendingNotificationPayload',
    );

    // Ak máme dostupný context a aplikácia je už spustená, zobraz dialóg okamžite
    if (navigatorKey.currentContext != null) {
      _logger.i('🚀 Context available - showing dialog immediately');
      // Počkaj chvíľu kým sa notifikácia zavrie
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentContext != null) {
          final tempPayload = _pendingNotificationPayload;
          _pendingNotificationPayload = null; // Vymaž aby sa neopakoval
          _showLocalNotificationDialog(
            navigatorKey.currentContext!,
            tempPayload,
          );
        }
      });
    } else {
      _logger.i('⏳ No context available - will show dialog on app resume');
    }
  } catch (e) {
    _logger.e('❌ Error handling local notification tap: $e');
  }
}

/// Zobrazí dialóg pre lokálnu notifikáciu
void _showLocalNotificationDialog(BuildContext context, String? payload) async {
  try {
    _logger.i('🎨 SHOW DIALOG: Starting with payload = $payload');

    if (!context.mounted) {
      _logger.e('🎨 Context is not mounted!');
      return;
    }

    String title = 'Notifikácia';
    String body = 'Máte novú notifikáciu.';
    String? actionRoute;

    // Dekóduj payload a nastav obsah
    if (payload != null) {
      try {
        final data = jsonDecode(payload);
        final type = data['type'] as String?;
        _logger.i('🎨 Parsed notification type: $type');

        switch (type) {
          case 'daily_lectio':
            title = '📖 Denné zamyslenie';
            body = 'Čas na dnešné lectio divina. Chcete ho otvoriť?';
            actionRoute = '/lectio';
            break;
          case 'prayer_reminder':
            title = '🙏 Pripomenutie modlitby';
            body =
                'Čas na modlitbu a zamyslenie. Chcete otvoriť lectio divina?';
            actionRoute = '/lectio';
            break;
          case 'welcome':
            title = '✨ Vitajte v aplikácii!';
            body =
                'Ďakujeme, že používate Lectio Divina. Preskúmajte naše denné zamyslenia.';
            break;
        }
      } catch (e) {
        _logger.w('🎨 Error parsing notification payload: $e');
      }
    }

    _logger.i('🎨 Showing dialog with title: $title');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF2D3748),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Zavrieť',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (actionRoute != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Naviguj na cieľovú obrazovku
                  navigatorKey.currentState?.pushNamed(actionRoute!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Otvoriť',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  } catch (e) {
    _logger.e('Error showing local notification dialog: $e');
  }
}

/// Zobrazí dialóg so skutočnou správou z notifikácie
void _showNotificationDialog(
  BuildContext context,
  RemoteMessage message,
) async {
  try {
    if (!context.mounted) return;

    _logger.i('Showing notification dialog');

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Notifikácia';

    final body =
        message.notification?.body ??
        message.data['body'] ??
        'Správa nemá obsah.';

    final imageUrl = message.data['image_url'];

    _logger.i('Dialog data - Title: $title, Body: $body');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.notifications,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Obrázok (ak existuje)
                if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Text správy
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Zavrieť',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  } catch (e) {
    _logger.e('Error showing notification dialog: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Bratislava'));
  _logger.i('✅ Timezone set to Europe/Bratislava');

  // .env
  try {
    await dotenv.load();
  } catch (e) {
    _logger.w('.env loading failed: $e');
  }

  await EasyLocalization.ensureInitialized();

  // Supabase kľúče
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    _logger.e('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env.');
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('sk'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('sk'),
        child: const EnvErrorApp(),
      ),
    );
    return;
  }

  // Firebase pred FCM
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Lokálne notifikácie - NAJPRV nastav callback, POTOM inicializuj
  try {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔧 Setting up LocalNotificationsService...');
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // KRITICKÉ: Najprv nastav callback, potom inicializuj!
    LocalNotificationsService.instance.setNotificationCallback(
      _handleLocalNotificationTap,
    );
    _logger.i('✅ Notification callback set BEFORE initialization');

    await LocalNotificationsService.instance.initialize();
    _logger.i('✅ LocalNotificationsService initialized successfully');

    // 🔥 NOVÉ: Refresh notifikácií pri štarte aplikácie
    // Toto zabezpečí, že ak používateľ neotvoril appku dlhšie ako 7 dní,
    // notifikácie sa znova naplánujú
    await LocalNotificationsService.instance.refreshCacheIfNeeded();
    _logger.i('✅ Notifications cache refreshed on startup');

    // Inicializácia Background Audio Manager
    try {
      await BackgroundAudioManager().initialize();
      _logger.i('✅ BackgroundAudioManager initialized successfully');
    } catch (e) {
      _logger.e('❌ Error initializing BackgroundAudioManager: $e');
    }

    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  } catch (e) {
    _logger.e('❌ Error initializing LocalNotificationsService: $e');
  }

  // Inicializuj ThemeProvider
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Získaj správnu štartovaciu lokalizáciu
  Locale startLocale = await _getStartLocale(themeProvider.languageCode);

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: EasyLocalization(
        supportedLocales: const [Locale('sk'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('sk'),
        startLocale: startLocale,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    // Aplikuj font nastavenia na témy
    final lightTheme = AppTheme.light.copyWith(
      textTheme: themeProvider.applyFontSettings(AppTheme.light.textTheme),
    );

    final darkTheme = AppTheme.dark.copyWith(
      textTheme: themeProvider.applyFontSettings(AppTheme.dark.textTheme),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lectio Divina',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      localizationsDelegates: [...context.localizationDelegates],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const FCMInitializer(child: SessionHandler()),
      routes: {'/lectio': (context) => const LectioScreen()},
    );
  }
}

class FCMInitializer extends StatefulWidget {
  final Widget child;

  const FCMInitializer({super.key, required this.child});

  @override
  State<FCMInitializer> createState() => _FCMInitializerState();
}

class _FCMInitializerState extends State<FCMInitializer>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _openedAppSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logger.i('🚀 FCMInitializer initState() - registered lifecycle observer');

    // Vyčisti badge pri štarte
    _clearAppBadge();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.locale.languageCode;

    _logger.i('Initializing FCM with language: $lang');

    // Nastavím callback pre handling notifikácií
    FcmService.instance.setNotificationCallback(_handleNotificationTap);

    // Použijem rozšírený FCM service, ktorý už má všetky handlery
    FcmService.instance
        .init(lang)
        .then((_) {
          _logger.i('FCM service initialized successfully');
        })
        .catchError((error) {
          _logger.e('FCM service initialization failed: $error');
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔄 App Lifecycle State Changed: $state');
    _logger.i(
      '🔍 Current _pendingNotificationPayload: $_pendingNotificationPayload',
    );
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (state == AppLifecycleState.resumed) {
      _logger.i('✅ App RESUMED from background');
      _clearAppBadge();

      // 🔥 KRITICKÉ: Re-scheduluj notifikácie pri každom resume
      // Toto zabezpečí, že notifikácie budú vždy naplánované na najbližších 7 dní
      LocalNotificationsService.instance.refreshCacheIfNeeded().then((_) {
        _logger.i('✅ Notifications refreshed on app resume');
      }).catchError((e) {
        _logger.e('❌ Failed to refresh notifications: $e');
      });

      // Kontrola pending notifikácie keď aplikácia prejde do popredia
      if (_pendingNotificationPayload != null) {
        _logger.i('🎯 FOUND pending notification on resume!');
        _logger.i('📦 Payload: $_pendingNotificationPayload');

        final payload = _pendingNotificationPayload;
        _pendingNotificationPayload = null; // Vymaž aby sa neopakoval

        // Počkaj na stabilizáciu aplikácie
        Future.delayed(const Duration(milliseconds: 500), () {
          _logger.i('⏱️ Delay completed, showing dialog...');
          _logger.i(
            '🔍 navigatorKey.currentContext available: ${navigatorKey.currentContext != null}',
          );

          if (navigatorKey.currentContext != null) {
            _logger.i('✅ Calling _showLocalNotificationDialog()');
            _showLocalNotificationDialog(navigatorKey.currentContext!, payload);
          } else {
            _logger.e('❌ No context available to show dialog!');
          }
        });
      } else {
        _logger.i('ℹ️ No pending notification on resume');
      }
    }
  }

  @override
  void dispose() {
    _logger.i('🗑️ FCMInitializer dispose() - removing lifecycle observer');
    WidgetsBinding.instance.removeObserver(this);
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔐 SessionHandler initState() CALLED');
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    session = Supabase.instance.client.auth.currentSession;
    _logger.i(
      '🔐 Current session: ${session != null ? "LOGGED IN" : "NOT LOGGED IN"}',
    );

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;

      // Ak sa user prihlásil, nastav welcome notification
      if (data.event == AuthChangeEvent.signedIn) {
        LocalNotificationsService.instance
            .setupRegistrationNotification()
            .catchError((error) {
              _logger.w('Failed to setup welcome notification: $error');
            });
      }

      // Ak sa user odhlásil, deaktivuj FCM token
      if (data.event == AuthChangeEvent.signedOut) {
        FcmService.instance.deactivateToken().catchError((error) {
          _logger.w('Failed to deactivate FCM token on logout: $error');
        });
      }

      setState(() {
        session = Supabase.instance.client.auth.currentSession;
      });
    });

    // Kontrola čakajúcej notifikácie
    _checkPendingNotification();
  }

  /// Kontrola a spracovanie čakajúcej notifikácie
  void _checkPendingNotification() {
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔔 SessionHandler _checkPendingNotification() CALLED');
    _logger.i(
      '🔔 Current _pendingNotificationPayload: $_pendingNotificationPayload',
    );
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Počkaj kým sa context úplne vytvorí
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.i('⏰ PostFrameCallback EXECUTED in SessionHandler');
      _logger.i(
        '🔍 _pendingNotificationPayload = $_pendingNotificationPayload',
      );
      _logger.i('🔍 mounted = $mounted');

      if (_pendingNotificationPayload != null && mounted) {
        _logger.i('✅ CONDITION MET: Will process notification');
        _logger.i(
          '🎯 Processing pending notification: $_pendingNotificationPayload',
        );
        final payload = _pendingNotificationPayload;
        _pendingNotificationPayload = null; // Vymaž aby sa neopakoval
        _logger.i('🗑️ Cleared _pendingNotificationPayload');

        // Počkaj na dokončenie navigácie
        Future.delayed(const Duration(milliseconds: 800), () {
          _logger.i('⏱️ 800ms delay completed');
          _logger.i('🔍 mounted after delay = $mounted');
          _logger.i(
            '🔍 navigatorKey.currentContext = ${navigatorKey.currentContext}',
          );

          if (mounted && navigatorKey.currentContext != null) {
            _logger.i('✅ About to call _showLocalNotificationDialog()');
            _showLocalNotificationDialog(navigatorKey.currentContext!, payload);
          } else {
            _logger.w('⚠️ Cannot show dialog:');
            _logger.w('   - mounted: $mounted');
            _logger.w(
              '   - context available: ${navigatorKey.currentContext != null}',
            );
          }
        });
      } else {
        _logger.i('ℹ️ Condition NOT met:');
        _logger.i(
          '   - _pendingNotificationPayload is null: ${_pendingNotificationPayload == null}',
        );
        _logger.i('   - mounted: $mounted');
      }
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

class EnvErrorApp extends StatelessWidget {
  const EnvErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lectio Divina - Config Error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Konfigurácia chýba / Missing config'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.error_outline, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Chýba SUPABASE_URL alebo SUPABASE_ANON_KEY v súbore .env.\n'
                    'Doplň tieto kľúče a reštartuj aplikáciu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '(EN) SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env.\n'
                    'Please add the keys and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

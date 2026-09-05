import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/services/confession_vault_service.dart';
import 'package:lectio_divina/screens/home_screen.dart';
import 'package:lectio_divina/screens/lectio_screen.dart';
import 'package:lectio_divina/screens/onboarding_screen.dart';
import 'package:lectio_divina/screens/onboarding_update_screen.dart';
import 'package:lectio_divina/widgets/app_update_dialog.dart';
import 'package:lectio_divina/shared/app_theme.dart';
import 'package:lectio_divina/utils/app_logger.dart';
import 'package:lectio_divina/utils/route_observer.dart';
import 'package:lectio_divina/utils/umami_navigation_observer.dart';
import 'package:lectio_divina/widgets/global_mini_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'controllers/notification_controller.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/audio_download_service.dart';
import 'services/connectivity_service.dart';
import 'services/credentials_service.dart';
import 'services/fcm_service.dart';
import 'services/home_widget_service.dart';
import 'services/lectio_audio_player.dart';
import 'services/local_notifications_service.dart';
import 'services/umami_analytics_service.dart';
import '../shared/app_spacing.dart';

final _logger = appLogger;

/// Získa správnu štartovaciu lokalizáciu na základe uloženého nastavenia
Future<Locale> _getStartLocale(String languageCode) async {
  if (languageCode == 'system') {
    // Pre 'system' použij systémový jazyk
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLanguages = ['en', 'sk', 'es', 'fr'];
    final systemLang = supportedLanguages.contains(systemLocale.languageCode)
        ? systemLocale.languageCode
        : 'en';
    return Locale(systemLang);
  } else {
    // Použij explicitne zvolený jazyk
    return Locale(languageCode);
  }
}

/// Krok štartu, ktorý NESMIE zablokovať appku.
///
/// Android splash (`installSplashScreen` v MainActivity) zmizne až po prvom
/// Flutter frame — takže čokoľvek, čo pred `runApp()` zamrzne alebo vyhodí
/// výnimku, nechá používateľa navždy na splash obrazovke. Presne toto ľudia
/// hlásili: appka „zamrzne" po kliknutí na notifikáciu (Android medzitým zrušil
/// Activity → `main()` beží znova) aj bez notifikácie.
///
/// Doteraz bol chránený jediný krok (`dotenv`); ostatných osem mohlo štart
/// zabiť. Timeout je zámerne krátky — v poriadku tieto kroky trvajú desiatky
/// milisekúnd, takže jeho prekročenie znamená, že sa niečo naozaj zaseklo
/// a správne je pokračovať bez daného kroku (degradovaná funkcia je vždy lepšia
/// než zamrznutá appka).
Future<bool> _startupStep(
  String name,
  Future<void> Function() run, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await run().timeout(timeout);
    return true;
  } on TimeoutException {
    _logger.e('⏱️ Štart „$name": prekročil ${timeout.inSeconds} s — pokračujem bez neho');
    return false;
  } catch (e, st) {
    _logger.e('❌ Štart „$name": zlyhalo — pokračujem bez neho', error: e, stackTrace: st);
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uzamkni orientáciu na portrait mode
  await _startupStep('orientácia', () => SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]), timeout: const Duration(seconds: 3));

  // Edge-to-edge display - obsah sa roztiahne za status bar aj navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Spovedné tajomstvo: iOS Keychain prežíva odinštalovanie — po čerstvej
  // inštalácii zmaž prípadné pozostatky trezoru (PIN + odpovede).
  // Siaha na secure storage (Android Keystore), ktorý vie zlyhať aj zamrznúť.
  await _startupStep('trezor spovede',
      () => ConfessionVaultService.instance.ensureWipedAfterReinstall());

  // just_audio_background pre ovládanie na uzamknutej obrazovke.
  //
  // ZÁMERNE ostáva PRED `runApp()`: `GlobalMiniPlayer` v `MyApp.builder`
  // vytvára `AudioPlayer` už pri prvom frame, takže odloženie za `runApp()`
  // by rozbilo audio. Riziko zamrznutia (viaže sa na audio službu, ktorá môže
  // po návrate z pozadia ešte žiť) rieši timeout — bez audia v pozadí sa dá
  // appku používať, so zamrznutou splash nie.
  await _startupStep('audio v pozadí', () => JustAudioBackground.init(
    androidNotificationChannelId: 'sk.lectio.divina.audio',
    androidNotificationChannelName: 'Lectio Divina Audio',
    androidNotificationOngoing: false,
    androidShowNotificationBadge: true,
    androidStopForegroundOnPause: false,
    // Fast forward/rewind intervals
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
    // Notification icon
    notificationColor: const Color(0xFF8B5C2A),
    // IMPORTANT: preloadArtwork must be false to prevent Android crash when offline
    // (artwork URL points to Supabase which is unreachable in airplane mode)
    preloadArtwork: false,
  ));

  tz.initializeTimeZones();

  // .env
  await _startupStep('.env', () => dotenv.load());

  await _startupStep('lokalizácia', () => EasyLocalization.ensureInitialized());

  // Supabase kľúče.
  //
  // `dotenv.env` VYHADZUJE `NotInitializedError`, keď `load()` neprebehol —
  // pôvodný try/catch okolo `load()` teda pred zamrznutím nechránil, len
  // posunul pád o dva riadky nižšie (a `main()` skončil bez `runApp()`).
  // Preto sa najprv pýtame na `isInitialized`.
  final supabaseUrl = dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null;
  final supabaseAnonKey = dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null;

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    _logger.e('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env.');
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

  // Firebase pred FCM. Dlhší timeout — Google Play Services vedia byť na
  // starších Androidoch pomalé, ale nesmú držať splash naveky.
  await _startupStep(
    'Firebase',
    () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    timeout: const Duration(seconds: 10),
  );

  // Supabase (lokálna operácia — session sa obnovuje na pozadí, nie tu)
  await _startupStep('Supabase',
      () => Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey));

  // NOTE: LocalNotificationsService, UmamiAnalytics, ConnectivityService,
  // AudioDownloadService are deferred to _FCMInitializerState to reduce
  // startup time and avoid ANR on slow GPUs (Impeller shader compilation).

  // Inicializuj ThemeProvider
  final themeProvider = ThemeProvider();
  await _startupStep('téma', () => themeProvider.initialize());

  // Získaj správnu štartovaciu lokalizáciu. Pri zlyhaní ostane `null` —
  // EasyLocalization vtedy použije naposledy uložený/systémový jazyk. Natvrdo
  // dosadený jazyk by používateľovi prepol appku na iný, než si zvolil.
  Locale? startLocale;
  await _startupStep('jazyk', () async {
    startLocale = await _getStartLocale(themeProvider.languageCode);
  }, timeout: const Duration(seconds: 3));

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

    // Umami: jazyk appky (nie zariadenia) — build beží znova pri zmene locale.
    UmamiAnalyticsService().setAppLanguage(context.locale.languageCode);

    return MaterialApp(
      navigatorKey: NotificationController.instance.navigatorKey,
      title: 'Lectio Divina',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      navigatorObservers: [UmamiNavigationObserver(), appRouteObserver],
      localizationsDelegates: [...context.localizationDelegates],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        // Ikony NAVIGAČNEJ lišty podľa témy. Nastavovali sa raz pri štarte
        // natvrdo na tmavé, takže v tmavom režime boli čierne na tmavom
        // pozadí (vidno hlavne pri 3-tlačidlovej navigácii). Obrazovky si
        // cez `AnnotatedRegion` prepisujú len stavový riadok — polia
        // navigačnej lišty nechávajú `null`, čiže platí táto hodnota.
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDarkTheme ? Brightness.light : Brightness.dark,
          ),
        );

        // Veľkosť písma z Nastavení aplikuj GLOBÁLNE na všetky Text widgety.
        // Skombinuj so systémovým škálovaním (prístupnosť) a clampni.
        final mq = MediaQuery.of(context);
        final systemFactor = mq.textScaler.scale(10) / 10;
        final scale = (systemFactor * themeProvider.textScale).clamp(0.8, 2.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: GlobalMiniPlayer(child: child ?? const SizedBox.shrink()),
        );
      },
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
  bool _deferredInitDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logger.i('🚀 FCMInitializer initState() - registered lifecycle observer');

    // Vyčisti badge pri štarte
    NotificationController.instance.clearAppBadge();

    // Deferred init — runs after first frame to avoid ANR on slow GPUs
    _initDeferredServices();
  }

  /// Initialize non-critical services after runApp() to reduce cold-start time.
  /// This prevents CPU contention with Impeller shader compilation on the
  /// raster thread, which was causing ANR on MediaTek and other slow GPUs.
  Future<void> _initDeferredServices() async {
    if (_deferredInitDone) return;
    _deferredInitDone = true;

    try {
      LocalNotificationsService.instance.setNotificationCallback(
        NotificationController.instance.handleLocalNotificationTap,
      );
      await LocalNotificationsService.instance.initialize();
      _logger.i('✅ LocalNotificationsService initialized (deferred)');
    } catch (e) {
      _logger.e('❌ Error initializing LocalNotificationsService: $e');
    }

    try {
      await UmamiAnalyticsService().initialize();
      _logger.i('✅ UmamiAnalyticsService initialized (deferred)');
    } catch (e) {
      _logger.e('❌ Error initializing UmamiAnalyticsService: $e');
    }

    try {
      await ConnectivityService.instance.initialize();
      _logger.i('✅ ConnectivityService initialized (deferred)');
    } catch (e) {
      _logger.e('❌ Error initializing ConnectivityService: $e');
    }

    try {
      await AudioDownloadService.instance.initialize();
      _logger.i('✅ AudioDownloadService initialized (deferred)');
    } catch (e) {
      _logger.e('❌ Error initializing AudioDownloadService: $e');
    }

    try {
      await HomeWidgetService.init();
      _logger.i('✅ HomeWidgetService initialized (deferred)');
    } catch (e) {
      _logger.e('❌ Error initializing HomeWidgetService: $e');
    }

    // Staršie verzie appky ukladali do secure storage aj heslo. Prihlasovacia
    // obrazovka ho síce dočistí, ale trvalo prihlásený používateľ ju nemusí
    // otvoriť nikdy — preto sa maže pri každom štarte.
    try {
      await CredentialsService.instance.purgeLegacyPassword();
    } catch (e) {
      _logger.w('Nepodarilo sa dočistiť staré uložené heslo: $e');
    }

    // POZN. (5.9.2026): presun biometrickej kópie kľúča trezoru sa TU
    // ZÁMERNE nerobí. Zápis do úložiska viazaného na biometriu si vyžiada
    // systémový prompt, takže sa pýtal na odtlačok hneď na home screene — a
    // keď neprešiel, stará kópia sa zmazala a odomykanie tvárou/odtlačkom po
    // aktualizácii zmizlo (vo verzii z obchodu fungovalo). Presun teraz beží
    // až v `unlockWithPin`, kde je používateľ overený.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.locale.languageCode;

    _logger.i('Initializing FCM with language: $lang');

    // Nastavím callback pre handling notifikácií
    FcmService.instance.setNotificationCallback(
      NotificationController.instance.handleRemoteNotificationTap,
    );

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
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (state == AppLifecycleState.resumed) {
      _logger.i('✅ App RESUMED from background');
      NotificationController.instance.clearAppBadge();

      // Kontrola pending notifikácie keď aplikácia prejde do popredia
      NotificationController.instance.checkPendingNotification(mounted);
    } else if (state == AppLifecycleState.paused) {
      _logger.i('⏸️ App PAUSED (minimized or in background)');
    } else if (state == AppLifecycleState.inactive) {
      _logger.i('🔕 App INACTIVE (transitioning)');
    } else if (state == AppLifecycleState.detached) {
      _logger.i('🛑 App DETACHED (closing) - stopping audio');
      // Zastaviť audio keď sa aplikácia zavrie
      LectioAudioPlayer()
          .stop()
          .then((_) {
            _logger.i('✅ Audio stopped on app close');
          })
          .catchError((e) {
            _logger.e('❌ Error stopping audio: $e');
          });
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

/// Verzia onboardingu. Zvýš pri väčšom update, ak chceš existujúcim používateľom
/// ukázať „Čo je nové" obrazovku ([OnboardingUpdateScreen]).
///   0            → nový používateľ → plný [OnboardingScreen]
///   1..CURRENT-1 → existujúci po update → [OnboardingUpdateScreen]
///   >= CURRENT   → rovno do appky
const int kCurrentOnboardingVersion = 4; // 4 = v11.2 (pobožnosti v2, celé audio…)

/// DOČASNE: vynúti zobrazenie „Čo je nové" ([OnboardingUpdateScreen]) pri
/// každom štarte (test). Pred vydaním prepnúť na `false`.
const bool kForceOnboardingUpdate = false;

class SessionHandler extends StatefulWidget {
  const SessionHandler({super.key});

  @override
  State<SessionHandler> createState() => _SessionHandlerState();
}

class _SessionHandlerState extends State<SessionHandler> {
  Session? session;
  /// Nullable: bez funkčného Supabase sa odber nedá vytvoriť (appka aj tak beží).
  StreamSubscription<AuthState>? _authSubscription;
  int _onboardingVersion = kCurrentOnboardingVersion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logger.i('🔐 SessionHandler initState() CALLED');
    _logger.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Ak Supabase init pri štarte zlyhal (viď `_startupStep`), `instance`
    // vyhodí výnimku — bez tohto by initState padol a používateľ by ostal na
    // prázdnej obrazovke. Takto sa appka otvorí neprihlásená.
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (e) {
      _logger.e('🔐 Supabase nie je dostupný — pokračujem ako neprihlásený: $e');
      session = null;
    }
    _logger.i(
      '🔐 Current session: ${session != null ? "LOGGED IN" : "NOT LOGGED IN"}',
    );

    _checkOnboarding();

    try {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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
    } catch (e) {
      _logger.e('🔐 Odber zmien prihlásenia sa nepodarilo vytvoriť: $e');
    }

    // Kontrola čakajúcej notifikácie + kontrola verzie appky (force/soft update)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationController.instance.checkPendingNotification(mounted);
      if (mounted) maybeShowAppUpdateDialog(context);
    });
  }

  /// Zistí, či ukázať onboarding.
  ///
  /// `_loading` sa vypína v `finally`: keby `SharedPreferences` zlyhalo alebo
  /// sa zaseklo, appka by inak ostala navždy na točiacom sa kolieske — druhá
  /// cesta k „zamrznutej obrazovke", ktorú ľudia hlásili.
  Future<void> _checkOnboarding() async {
    int version = kCurrentOnboardingVersion;   // pri zlyhaní rovno do appky
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      // Migrácia: starý `onboarding_completed` (bool) → verzia 1 (videli starý
      // onboarding) ; bez ničoho → 0 (nový používateľ).
      final stored = prefs.getInt('onboarding_version');
      final legacyCompleted = prefs.getBool('onboarding_completed') ?? false;
      // DOČASNE: vynútené zobrazenie „Čo je nové" (predchádzajúca verzia → gate).
      version = kForceOnboardingUpdate
          ? (kCurrentOnboardingVersion > 1 ? kCurrentOnboardingVersion - 1 : 1)
          : (stored ?? (legacyCompleted ? 1 : 0));
    } catch (e) {
      _logger.e('Onboarding: nastavenia sa nepodarilo prečítať ($e) — idem do appky');
    } finally {
      if (mounted) {
        setState(() {
          _onboardingVersion = version;
          _loading = false;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onboarding_version', kCurrentOnboardingVersion);
    await prefs.setBool('onboarding_completed', true); // legacy kompatibilita
    if (mounted) {
      setState(() {
        _onboardingVersion = kCurrentOnboardingVersion;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pozn.: Home/Auth NEkľúčujeme jazykom. Skorší `ValueKey('home_$lang')`
    // vynucoval kompletný REMOUNT pri zmene jazyka → počas prechodu existovali
    // dve inštancie HomeScreen naraz so zdieľanými GlobalKeys (showcase) →
    // „Duplicate GlobalKey" + re-entrantný build → pád viewportu
    // (`_doingMountOrUpdate`, prázdny obsah pod hero). HomeScreen si jazyk
    // aktualizuje sám: závisí od `context.locale` (→ `didChangeDependencies`
    // znovu načíta obsah) a `tr()` stringy sa prestavia pri rebuild-e z
    // EasyLocalization (setLocale prestaví celý podstrom).
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Nový používateľ → plný onboarding. Existujúci po update → „Čo je nové".
    // (Onboarding si rebuild pri zmene jazyka rieši sám — bez key, aby sa
    // jeho stav neresetoval pri výbere jazyka v onboardingu.)
    if (_onboardingVersion == 0) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }
    if (_onboardingVersion < kCurrentOnboardingVersion) {
      return OnboardingUpdateScreen(onComplete: _completeOnboarding);
    }

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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'Chýba SUPABASE_URL alebo SUPABASE_ANON_KEY v súbore .env.\n'
                    'Doplň tieto kľúče a reštartuj aplikáciu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: AppSpacing.lg),
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

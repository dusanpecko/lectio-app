import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../services/connectivity_service.dart';
import '../services/umami_analytics_service.dart';
import '../services/lectio_cache_service.dart';
import '../shared/app_colors.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../widgets/speed_dial_fab.dart';
import 'about_screen.dart';
import 'feedback_screen.dart';
import 'intentions_list_screen.dart';
import 'intro_screen.dart';
import 'lectio_screen.dart';
import 'news_detail_screen.dart';
import 'news_list_screen.dart';
import 'notes_list_screen.dart';
import 'notifications_screen.dart';
import 'rosary_screen.dart';
import 'settings_screen.dart';
import 'spiritual_exercise_detail_screen.dart';
import 'spiritual_exercises_list_screen.dart';
import 'donation_screen.dart';
import 'adoration_screen.dart';
import 'stations_of_cross_screen.dart';
import 'newsletter_list_screen.dart';
import 'lectio_survey_screen.dart';
import '../shared/app_spacing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Slider properties
  final List<String> imagePaths = [
    'assets/images/slide1.webp',
    'assets/images/slide0.webp',
    'assets/images/slide2.webp',
    'assets/images/slide3.webp',
    'assets/images/slide4.webp',
    'assets/images/slide5.webp',
  ];

  final List<String> slideTitleKeys = [
    'god_word',
    'silencio',
    'lectio_divina',
    'meditatio',
    'oratio',
    'contemplatio',
  ];

  final List<String> slideSubtitleKeys = [
    'slider_subtitle_god_word',
    'slider_subtitle_silencio',
    'slider_subtitle_lectio',
    'slider_subtitle_meditatio',
    'slider_subtitle_oratio',
    'slider_subtitle_contemplatio',
  ];

  // Slider control
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Actio data (z lectio_sources namiesto daily_quotes)
  String? actioText;
  bool isLoading = true;
  bool _dataLoaded = false;
  String? _lastLocale;

  // News data
  List<Map<String, dynamic>> newsArticles = [];
  bool isLoadingNews = true;

  // Spiritual exercise data (pre hero sekciu)
  SpiritualExercise? _featuredExercise;
  bool _isLoadingExercise = true;

  // Featured carousel controller
  final PageController _featuredCarouselController = PageController();
  int _currentFeaturedPage = 0;

  // Offline state
  bool _isOffline = false;

  // FAB menu state
  bool _isFabOpen = false;
  VoidCallback? _closeFabMenu;
  StreamSubscription<bool>? _connectivitySubscription;
  final Set<String> _cachedDates = {};

  // Survey bell pulse animation
  late final AnimationController _pulseController;
  bool _showSurveyIcon = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _checkSurveyVisibility();
    _startSliderTimer();
    _initConnectivity();
  }

  Future<void> _checkSurveyVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('survey_completed') ?? false;
    if (completed) return;
    final count = (prefs.getInt('survey_launch_count') ?? 0) + 1;
    await prefs.setInt('survey_launch_count', count);
    // Zobraziť od 6. spustenia, potom vždy kým nevyplní
    final show = count >= 6;
    appLogger.i('📊 Survey launch count: $count, show icon: $show');
    if (mounted && show) {
      setState(() => _showSurveyIcon = true);
    }
  }

  void _initConnectivity() {
    _isOffline = !ConnectivityService.instance.isOnline;
    _connectivitySubscription = ConnectivityService
        .instance
        .onConnectivityChanged
        .listen((isOnline) {
          if (mounted) {
            final wasOffline = _isOffline;
            setState(() {
              _isOffline = !isOnline;
            });
            // Ak sme sa práve prepli na online, refreshneme dáta
            if (wasOffline && isOnline) {
              _onRefresh();
            }
          }
        });
    if (_isOffline) {
      _checkCachedDates();
    }
  }

  Future<void> _checkCachedDates() async {
    final today = DateTime.now();
    final lang = context.locale.languageCode;
    final dates = <String>{};
    for (int i = -3; i < 7; i++) {
      final date = today.add(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final cached = await LectioCacheService.instance.getCachedLectio(
        dateStr,
        lang,
      );
      if (cached != null) {
        dates.add(dateStr);
      }
    }
    if (mounted) {
      setState(() {
        _cachedDates.clear();
        _cachedDates.addAll(dates);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale.languageCode;

    // Načítaj dáta pri prvom načítaní
    if (!_dataLoaded) {
      _fetchQuoteData();
      _fetchNewsData();
      _fetchFeaturedExercise();
      _dataLoaded = true;
      _lastLocale = currentLocale;
    }
    // Alebo keď sa zmení jazyk
    else if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _fetchQuoteData();
      _fetchNewsData();
      _fetchFeaturedExercise();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    _featuredCarouselController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Start automatic slider
  void _startSliderTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentPage < imagePaths.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        }
      });
    });
  }

  // Fetch daily actio from lectio_sources (rovnaký princíp ako web homepage)
  Future<void> _fetchQuoteData() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final locale = context.locale.languageCode;

      // 1. NAJPRV nájdeme správny liturgický rok na základe DÁTUMOVÉHO ROZSAHU
      // (nie z calendar entry, ale priamo podľa date range)
      final liturgicalYearsResponse = await supabase
          .from('liturgical_years')
          .select()
          .eq('locale_code', locale)
          .lte('start_date', today)
          .gte('end_date', today);

      Map<String, dynamic>? correctLiturgicalYear;
      final liturgicalYearsList = liturgicalYearsResponse as List;
      if (liturgicalYearsList.isNotEmpty) {
        final yearData = liturgicalYearsList[0] as Map<String, dynamic>;
        correctLiturgicalYear = yearData;
        appLogger.i(
          '✅ Home: Nájdený liturgický rok: ${yearData['year']} '
          '(${yearData['start_date']} - ${yearData['end_date']}), '
          'cyklus: ${yearData['lectionary_cycle']}',
        );
      } else {
        // Fallback na slovenčinu ak aktuálny jazyk nemá liturgický rok
        if (locale != 'sk') {
          appLogger.d('🔄 Home: Hľadám liturgický rok v slovenčine...');
          final skYearsResponse = await supabase
              .from('liturgical_years')
              .select()
              .eq('locale_code', 'sk')
              .lte('start_date', today)
              .gte('end_date', today);

          final skYearsList = skYearsResponse as List;
          if (skYearsList.isNotEmpty) {
            final skYearData = skYearsList[0] as Map<String, dynamic>;
            correctLiturgicalYear = skYearData;
            appLogger.i(
              '✅ Home: Nájdený SK liturgický rok: ${skYearData['year']} '
              '(${skYearData['start_date']} - ${skYearData['end_date']}), '
              'cyklus: ${skYearData['lectionary_cycle']}',
            );
          }
        }
      }

      // 2. Nájdi dnešný liturgický deň v kalendári
      final calendarResponse = await supabase
          .from('liturgical_calendar')
          .select()
          .eq('datum', today)
          .eq('locale_code', locale)
          .maybeSingle();

      if (calendarResponse == null ||
          calendarResponse['lectio_hlava'] == null) {
        if (!mounted) return;
        setState(() {
          actioText = null;
          isLoading = false;
        });
        return;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      // 3. Určíme či použiť cyklus (A/B/C) alebo 'N' pre všedné dni
      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday).+(týždňa|Week)',
      ).hasMatch(celebrationTitle);

      final isSpecialDay =
          !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      // POUŽIJEME správny liturgický rok (nájdený podľa dátumu, nie z calendar entry)
      final lectionaryCycle = correctLiturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      appLogger.d(
        '🔍 Home: Hľadám actio pre rok: $rokToSearch, hlava: $lectioHlava, '
        'lang: $locale, liturgický cyklus: $lectionaryCycle',
      );

      // 4. Nájdi lectio source s actio textom
      var lectioSource = await supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', locale)
          .eq('rok', rokToSearch)
          .maybeSingle();

      // Fallback logika
      if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
        appLogger.d(
          '🔄 Home: Sviatok nenájdený s rokom A/B/C, skúšam rok N...',
        );
        lectioSource = await supabase
            .from('lectio_sources')
            .select()
            .eq('hlava', lectioHlava)
            .eq('lang', locale)
            .eq('rok', 'N')
            .maybeSingle();
      }

      // Fallback na slovenčinu ak aktuálny jazyk nemá záznam
      if (lectioSource == null && locale != 'sk') {
        appLogger.d(
          '🔄 Home: Actio nenájdené pre $locale, skúšam slovenčinu...',
        );
        lectioSource = await supabase
            .from('lectio_sources')
            .select()
            .eq('hlava', lectioHlava)
            .eq('lang', 'sk')
            .eq('rok', rokToSearch)
            .maybeSingle();

        // Ešte jeden fallback pre sviatky v slovenčine
        if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
          lectioSource = await supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', 'sk')
              .eq('rok', 'N')
              .maybeSingle();
        }
      }

      if (!mounted) return;

      setState(() {
        actioText = lectioSource?['actio_text'];
        isLoading = false;
      });

      appLogger.i(
        '✅ Home: Actio načítané: ${actioText != null ? "ano" : "nie"}',
      );
    } catch (e) {
      appLogger.e('❌ Home: Error fetching actio: $e');
      // Ak je to sieťová chyba, označ ako offline
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('network') ||
          errorStr.contains('clientexception')) {
        ConnectivityService.instance.markOffline();
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
          _checkCachedDates();
        }
      }
      if (!mounted) return;
      setState(() {
        actioText = null;
        isLoading = false;
      });
    }
  }

  // Fetch news data
  Future<void> _fetchNewsData() async {
    final supabase = Supabase.instance.client;

    try {
      final locale = context.locale.languageCode;
      final now = DateTime.now().toIso8601String();

      final newsRes = await supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      setState(() {
        newsArticles = List<Map<String, dynamic>>.from(newsRes);
        isLoadingNews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingNews = false;
      });
    }
  }

  // Fetch featured spiritual exercise for current locale
  Future<void> _fetchFeaturedExercise() async {
    final supabase = Supabase.instance.client;

    try {
      final locale = context.locale.languageCode;
      final now = DateTime.now().toIso8601String().substring(0, 10);

      // Najprv nájdi locale_id pre aktuálny jazyk
      final localeData = await supabase
          .from('locales')
          .select('id')
          .eq('code', locale)
          .maybeSingle();

      if (localeData == null) {
        appLogger.d('🔍 Home: Locale $locale not found');
        if (mounted) {
          setState(() => _isLoadingExercise = false);
        }
        return;
      }

      // Nájdi najbližšie aktívne duchovné cvičenie pre daný jazyk
      final response = await supabase
          .from('spiritual_exercises')
          .select('''
            id,
            title,
            slug,
            description,
            image_url,
            home_image_url,
            start_date,
            end_date,
            location_name,
            location_city,
            location_country,
            leader_name,
            max_capacity,
            locale:locales(id, code, native_name)
          ''')
          .eq('is_published', true)
          .eq('is_active', true)
          .eq('locale_id', localeData['id'])
          .gte('end_date', now) // Len budúce alebo prebiehajúce
          .order('start_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        setState(() {
          _featuredExercise = SpiritualExercise.fromJson(response);
          _isLoadingExercise = false;
        });
        appLogger.i(
          '✅ Home: Featured exercise found: ${_featuredExercise?.title}',
        );
      } else {
        setState(() {
          _featuredExercise = null;
          _isLoadingExercise = false;
        });
        appLogger.d('🔍 Home: No featured exercise for locale $locale');
      }
    } catch (e) {
      appLogger.e('❌ Home: Error fetching featured exercise: $e');
      if (mounted) {
        setState(() => _isLoadingExercise = false);
      }
    }
  }

  // Handle refresh
  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchQuoteData(),
      _fetchNewsData(),
      _fetchFeaturedExercise(),
    ]);
  }

  // Helper methods
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(DateTime date) {
    // Použijeme DateFormat pre lokalizáciu dní v týždni
    return DateFormat.E(context.locale.languageCode).format(date);
  }

  // Show date picker for Lectio
  Future<void> _showDatePickerForLectio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateLimitsConfig.getMinDate(),
      lastDate: DateLimitsConfig.getMaxDate(),
      locale: context.locale,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _openLectioForDate(picked);
    }
  }

  // Open Lectio for specific date
  void _openLectioForDate(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectioScreen(selectedDate: date),
        settings: const RouteSettings(name: '/lectio'),
      ),
    );
  }

  // Open today's Lectio - hlavná akcia FAB
  void _openTodaysLectio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectioScreen(selectedDate: DateTime.now()),
        settings: const RouteSettings(name: '/lectio'),
      ),
    );
  }

  void _showActioDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: Text(
            tr('actio'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/icon/lectio_logo.png',
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    actioText ?? tr('quote_not_available'),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('close')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openTodaysLectio();
              },
              child: Text(tr('start_lectio_today')),
            ),
          ],
        );
      },
    );
  }

  // Handle Speed Dial secondary actions
  void _handleSpeedDialAction(String action) {
    if (!mounted) return;

    switch (action) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
            settings: const RouteSettings(name: '/settings'),
          ),
        );
        break;

      case 'notes':
        final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

        if (isLoggedIn) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotesListScreen(),
              settings: const RouteSettings(name: '/notes'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('login_required')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;

      case 'support':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DonationScreen(),
            settings: const RouteSettings(name: '/donation'),
          ),
        );
        break;

      case 'about':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AboutScreen(),
            settings: const RouteSettings(name: '/about'),
          ),
        );
        break;

      case 'feedback':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FeedbackScreen(),
            settings: const RouteSettings(name: '/feedback'),
          ),
        );
        break;

      case 'notifications':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
            settings: const RouteSettings(name: '/notifications'),
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action not handled: $action'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 15), // Priestor pre FAB
                child: Column(
                  children: [
                    // Hero Slider Section
                    Stack(
                      children: [
                        _buildHeroSlider(),
                        // Survey ikona — zvonček s pulzom
                        if (_showSurveyIcon)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          right: 16,
                          child: SafeArea(
                            top: false,
                            child: GestureDetector(
                              onTap: () {
                                UmamiAnalyticsService().trackEvent(
                                  'survey_icon_clicked',
                                  eventData: {'source': 'home_screen'},
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LectioSurveyScreen(),
                                    settings: const RouteSettings(name: '/survey'),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Vonkajší pulz 1
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final scale = 1.0 + _pulseController.value * 0.8;
                                        final opacity = (1.0 - _pulseController.value).clamp(0.0, 0.5);
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF800020).withValues(alpha: opacity),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Vonkajší pulz 2 (oneskorený)
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final delayed = (_pulseController.value + 0.4) % 1.0;
                                        final scale = 1.0 + delayed * 0.8;
                                        final opacity = (1.0 - delayed).clamp(0.0, 0.5);
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF800020).withValues(alpha: opacity),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Hlavná ikona
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF800020),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF800020).withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.circle_notifications,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Main Content
                    SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          // Slider dots
                          _buildSliderDots(),

                          // Offline banner
                          if (_isOffline) _buildOfflineBanner(),

                          // Lectio Divina Calendar
                          _buildLectioCalendar(),
                          const SizedBox(height: AppSpacing.sm),
                          // Daily quote
                          _buildQuoteCard(),
                          const SizedBox(height: AppSpacing.sm),
                          // Navigation buttons
                          _buildNavigationButtons(),
                          const SizedBox(height: 15),
                          // Rosary section
                          if (!_isOffline) _buildRosarySection(),

                          // Support button
                          if (!_isOffline) _buildSupportButton(),

                          // News section
                          if (!_isOffline) _buildNewsSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Backdrop pre FAB menu - zachytáva kliky mimo menu
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isFabOpen,
                child: GestureDetector(
                  onTap: () {
                    debugPrint('🔄 Backdrop tapped - closing FAB menu');
                    _closeFabMenu?.call();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // SpeedDial FAB
            Positioned(
              right: 16,
              bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
              child: SpeedDialFAB(
                onPrimaryAction: _openTodaysLectio,
                onSecondaryAction: _handleSpeedDialAction,
                onOpenChanged: (isOpen) {
                  if (mounted) {
                    setState(() {
                      _isFabOpen = isOpen;
                    });
                  }
                },
                onCloseCallback: (closeFunc) {
                  _closeFabMenu = closeFunc;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build hero slider
  Widget _buildHeroSlider() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    // Responsive sizing
    final sliderHeight = isTablet ? 500.0 : 350.0;
    final textPadding = isTablet ? AppSpacing.xxl * 1.5 : AppSpacing.xl;

    return Container(
      height: sliderHeight,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        itemCount: imagePaths.length,
        onPageChanged: (index) {
          if (!mounted) return;
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePaths[index], fit: BoxFit.cover),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(textPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slideTitleKeys[index].tr(),
                        style: TextStyle(
                          fontSize: isTablet ? 34 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: isTablet ? AppSpacing.md : AppSpacing.sm,
                      ),
                      Text(
                        slideSubtitleKeys[index].tr(),
                        style:
                            (isTablet
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.titleMedium)!
                                .copyWith(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Build slider dots
  Widget _buildSliderDots() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    final dotSize = isTablet ? 16.0 : 12.0;
    final dotSizeInactive = isTablet ? 12.0 : 8.0;
    final containerHeight = isTablet ? 32.0 : 24.0;

    return Container(
      height: containerHeight,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(imagePaths.length, (index) {
          final isActive = _currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? AppSpacing.sm : AppSpacing.xs,
            ),
            width: isActive ? dotSize : dotSizeInactive,
            height: isActive ? dotSize : dotSizeInactive,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primary : Colors.grey.shade400,
            ),
          );
        }),
      ),
    );
  }

  // Build Offline Banner
  Widget _buildOfflineBanner() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.orange.shade700,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              tr('offline.offline_banner'),
              style: theme.textTheme.bodySmall!.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Lectio Divina Calendar
  Widget _buildLectioCalendar() {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysBack = DateLimitsConfig.daysBack;
    final daysForward = DateLimitsConfig.daysForward;
    final totalDays = daysBack + daysForward + 1;
    final startDate = today.subtract(Duration(days: daysBack));

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('lectio_divina'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              GestureDetector(
                onTap: _showDatePickerForLectio,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Calendar slider
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: ScrollController(
                initialScrollOffset: (daysBack - 2) * 78.0,
              ),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              itemCount: totalDays,
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final isToday = _isSameDay(date, today);
                final dateStr = date.toIso8601String().substring(0, 10);
                final isCached = _isOffline && _cachedDates.contains(dateStr);
                final isUnavailable =
                    _isOffline && !_cachedDates.contains(dateStr);

                return GestureDetector(
                  onTap: isUnavailable ? null : () => _openLectioForDate(date),
                  child: Opacity(
                    opacity: isUnavailable ? 0.35 : 1.0,
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primary
                            : AppColors.isDark(context)
                            ? AppColors.darkCard
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: isCached && !isToday
                            ? Border.all(color: Colors.green.shade400, width: 2)
                            : null,
                        boxShadow: isToday
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4A5085,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            date.day.toString(),
                            style: theme.textTheme.headlineSmall!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? Colors.white
                                  : AppColors.adaptiveCardTitle(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (isCached && !isToday)
                            Icon(
                              Icons.cloud_done_outlined,
                              size: 14,
                              color: Colors.green.shade600,
                            )
                          else
                            Text(
                              _getDayName(date),
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: isToday
                                    ? Colors.white70
                                    : AppColors.adaptiveCardSubtitle(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build quote card - kompaktná verzia
  Widget _buildQuoteCard() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        _showActioDialog();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Card(
          elevation: AppElevation
              .none, // Vypnuté Card elevation, používame vlastný shadow
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.03),
                  AppColors.primary.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Quote icon - menší
                        const Icon(
                          Icons.format_quote,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Actio content (z lectio_sources)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Actio text
                              Text(
                                actioText ?? tr('quote_not_available'),
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.adaptiveCardTitle(context),
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Build navigation buttons
  Widget _buildNavigationButtons() {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return Container(
      height: 60,
      margin: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 1. Na úvod
          _ModuleButton(
            labelKey: 'intro_title',
            icon: Icons.article,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 2. Lectio divina
          _ModuleButton(
            labelKey: 'lectio_divina',
            icon: Icons.menu_book,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 3. Aktuality
          _ModuleButton(
            labelKey: 'news',
            icon: Icons.campaign,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 4. Poznámky (len pre prihlásených)
          if (isLoggedIn) ...[
            _ModuleButton(
              labelKey: 'notes_title',
              icon: Icons.notes,
              isOffline: _isOffline,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          // 5. Modlitby
          _ModuleButton(
            labelKey: 'pray_intentions',
            icon: Icons.favorite,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 6. Adorácie
          _ModuleButton(
            labelKey: 'adoration_title',
            icon: Icons.favorite_rounded,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 7. Ruženec
          _ModuleButton(
            labelKey: 'rosary_title',
            icon: Icons.auto_stories_rounded,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 7b. Krížové cesty
          _ModuleButton(
            labelKey: 'stations_of_cross_title',
            icon: Icons.add_rounded,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 7c. Newslettre
          _ModuleButton(
            labelKey: 'newsletter_title',
            icon: Icons.mail_rounded,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 8. O aplikácii
          _ModuleButton(
            labelKey: 'about_title',
            icon: Icons.info,
            isOffline: _isOffline,
          ),
          const SizedBox(width: AppSpacing.md),
          // 9. Nastavenie
          _ModuleButton(
            labelKey: 'settings',
            icon: Icons.settings,
            isOffline: _isOffline,
          ),
        ],
      ),
    );
  }

  // Build support button
  Widget _buildSupportButton() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DonationScreen(),
              settings: const RouteSettings(name: '/donation'),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: Text(
          tr('support_full'),
          style: theme.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Build Featured Section (Spiritual Exercise or Rosary)
  Widget _buildRosarySection() {
    // Ak sa ešte načítava, zobraz loading
    if (_isLoadingExercise) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        height: 300,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    // Vytvor zoznam kariet pre carousel
    final List<Widget> carouselItems = [];

    // 1. Pridaj duchovné cvičenie ak existuje
    if (_featuredExercise != null) {
      carouselItems.add(_buildSpiritualExerciseCardContent(_featuredExercise!));
    }

    // 2. Pridaj Krížové cesty
    carouselItems.add(_buildStationsOfCrossCardContent());

    // 3. Vždy pridaj Rosary
    carouselItems.add(_buildRosaryCardContent());

    // 4. Pridaj Adorácie
    carouselItems.add(_buildAdorationCardContent());

    // Pre tablety: zoskup karty po 2
    List<Widget> pages = [];
    if (isTablet) {
      for (int i = 0; i < carouselItems.length; i += 2) {
        if (i + 1 < carouselItems.length) {
          // Dvojica kariet
          pages.add(
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: carouselItems[i],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: carouselItems[i + 1],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Posledná karta je sama
          pages.add(
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: carouselItems[i],
                  ),
                ),
                const Expanded(child: SizedBox()), // Prázdny priestor
              ],
            ),
          );
        }
      }
    } else {
      // Pre mobily: jedna karta na page
      pages = carouselItems;
    }

    // Ak je len jedna page (mobil s 1 kartou alebo tablet s 1-2 kartami), nezobrazuj dots
    if (pages.length == 1) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        height: 300,
        child: pages.first,
      );
    }

    // Carousel s viacerými pages
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Carousel
          SizedBox(
            height: 300,
            child: PageView.builder(
              controller: _featuredCarouselController,
              itemCount: pages.length,
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() {
                  _currentFeaturedPage = index;
                });
              },
              itemBuilder: (context, index) {
                return isTablet
                    ? pages[index]
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: pages[index],
                      );
              },
            ),
          ),

          // Dots indicator
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (index) {
              final isActive = _currentFeaturedPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: isActive ? 12 : 8,
                height: isActive ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.primary : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Build Spiritual Exercise card content (bez margin pre carousel)
  Widget _buildSpiritualExerciseCardContent(SpiritualExercise exercise) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d. MMM', context.locale.languageCode);
    final dateRange =
        '${dateFormat.format(exercise.startDate)} - ${dateFormat.format(exercise.endDate)}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SpiritualExerciseDetailScreen(slug: exercise.slug),
            settings: const RouteSettings(name: '/spiritual-exercise'),
          ),
        );
      },
      child: Card(
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child:
                    exercise.homeImageUrl != null || exercise.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: exercise.homeImageUrl ?? exercise.imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) {
                          return _buildExerciseFallbackBackground();
                        },
                      )
                    : _buildExerciseFallbackBackground(),
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.self_improvement,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              exercise.title,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.adaptiveCardTitle(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.adaptiveCardSubtitle(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateRange,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: AppColors.adaptiveCardSubtitle(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.adaptiveCardSubtitle(context),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              exercise.locationDisplay,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: AppColors.adaptiveCardSubtitle(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
        ),
      ),
    );
  }

  // Build Rosary card content (bez margin pre carousel)
  Widget _buildRosaryCardContent() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RosaryScreen(),
            settings: const RouteSettings(name: '/rosary'),
          ),
        );
      },
      child: Card(
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/images/rosary_backround.webp',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback ak sa obrázok nenačíta
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.8),
                            AppColors.primary,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gradient overlay pre lepšiu čitateľnosť textu
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('rosary_title'),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tr('rosary_description'),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Adoration card content (bez margin pre carousel)
  Widget _buildAdorationCardContent() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdorationScreen(),
            settings: const RouteSettings(name: '/adoration'),
          ),
        );
      },
      child: Card(
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/images/adoration_bg.webp',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback ak sa obrázok nenačíta
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.liveRed.withValues(alpha: 0.8),
                            AppColors.liveRed,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gradient overlay pre lepšiu čitateľnosť textu
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('adoration_title'),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tr('adoration_main_subtitle'),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Stations of the Cross card content (pre carousel)
  Widget _buildStationsOfCrossCardContent() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StationsOfCrossScreen(),
            settings: const RouteSettings(name: '/stations-of-cross'),
          ),
        );
      },
      child: Card(
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/images/station_cross_backround.webp',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                            AppColors.primary.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gradient overlay pre lepšiu čitateľnosť textu
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('stations_of_cross_title'),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tr('stations_of_cross_explore'),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build News section
  Widget _buildNewsSection() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('news'),
                style: theme.textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.adaptiveCardTitle(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewsListScreen(),
                      settings: const RouteSettings(name: '/news'),
                    ),
                  );
                },
                child: Text(
                  tr('see_all'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // News list
          isLoadingNews
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : newsArticles.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.isDark(context)
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tr('no_news_available'),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: AppColors.adaptiveCardSubtitle(context),
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = MediaQuery.of(context).size.width >= 600;
                    return SizedBox(
                      height: isTablet ? 420 : 320,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: newsArticles.length,
                        itemBuilder: (context, index) {
                          final article = newsArticles[index];
                          return Container(
                            width: isTablet ? 380 : 280,
                            margin: const EdgeInsets.only(right: AppSpacing.lg),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        NewsDetailScreen(newsData: article),
                                    settings: const RouteSettings(
                                      name: '/news-detail',
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: AppElevation.high,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image section - fixed height
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(AppRadius.lg),
                                        topRight: Radius.circular(AppRadius.lg),
                                      ),
                                      child: SizedBox(
                                        height: isTablet ? 200 : 160,
                                        width: double.infinity,
                                        child: article['image_url'] != null
                                            ? CachedNetworkImage(
                                                imageUrl: article['image_url'],
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) {
                                                      return Container(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                          size: 50,
                                                        ),
                                                      );
                                                    },
                                              )
                                            : Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.article,
                                                  color: Colors.grey,
                                                  size: 50,
                                                ),
                                              ),
                                      ),
                                    ),

                                    // Content section
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.lg,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Title
                                            Flexible(
                                              child: Text(
                                                article['title'] ??
                                                    tr('untitled_article'),
                                                style: theme
                                                    .textTheme
                                                    .titleMedium!
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.adaptiveCardTitle(
                                                            context,
                                                          ),
                                                      height: 1.4,
                                                    ),
                                                maxLines: isTablet ? 5 : 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),

                                            const Spacer(),

                                            // "Zobraziť článok" button
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (AppColors.isDark(context)
                                                            ? AppColors
                                                                  .darkPrimaryLight
                                                            : AppColors.primary)
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    tr('show_article'),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall!
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              AppColors.isDark(
                                                                context,
                                                              )
                                                              ? AppColors
                                                                    .darkPrimaryLight
                                                              : AppColors
                                                                    .primary,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    width: AppSpacing.xs,
                                                  ),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 14,
                                                    color:
                                                        AppColors.isDark(
                                                          context,
                                                        )
                                                        ? AppColors
                                                              .darkPrimaryLight
                                                        : AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

// Module Button Widget
class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.labelKey,
    required this.icon,
    this.isOffline = false,
  });

  final String labelKey;
  final IconData icon;
  final bool isOffline;

  // Moduly vyžadujúce internet
  static const _onlineOnlyModules = {
    'pray_intentions',
    'news',
    'notes_title',
    'newsletter_title',
  };

  bool get _isDisabled => isOffline && _onlineOnlyModules.contains(labelKey);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 170,
      child: Opacity(
        opacity: _isDisabled ? 0.4 : 1.0,
        child: ElevatedButton.icon(
          onPressed: _isDisabled ? null : () => _handlePress(context),
          icon: Icon(icon, size: 23),
          label: Text(labelKey.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDisabled
                ? Colors.grey.shade400
                : AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            textStyle: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePress(BuildContext context) {
    switch (labelKey) {
      case 'lectio_divina':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LectioScreen(),
            settings: const RouteSettings(name: '/lectio'),
          ),
        );
        break;

      case 'pray_intentions':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const IntentionsListScreen(),
            settings: const RouteSettings(name: '/intentions'),
          ),
        );
        break;

      case 'rosary_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RosaryScreen(),
            settings: const RouteSettings(name: '/rosary'),
          ),
        );
        break;

      case 'adoration_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdorationScreen(),
            settings: const RouteSettings(name: '/adoration'),
          ),
        );
        break;

      case 'stations_of_cross_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StationsOfCrossScreen(),
            settings: const RouteSettings(name: '/stations-of-cross'),
          ),
        );
        break;

      case 'spiritual_exercises':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SpiritualExercisesListScreen(),
            settings: const RouteSettings(name: '/spiritual-exercises'),
          ),
        );
        break;

      case 'news':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NewsListScreen(),
            settings: const RouteSettings(name: '/news'),
          ),
        );
        break;

      case 'newsletter_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NewsletterListScreen(),
            settings: const RouteSettings(name: '/newsletters'),
          ),
        );
        break;

      case 'notes_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotesListScreen(),
            settings: const RouteSettings(name: '/notes'),
          ),
        );
        break;

      case 'intro_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const IntroScreen(),
            settings: const RouteSettings(name: '/intro'),
          ),
        );
        break;

      case 'about_title':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AboutScreen(),
            settings: const RouteSettings(name: '/about'),
          ),
        );
        break;

      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
            settings: const RouteSettings(name: '/settings'),
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('module_not_available', args: [labelKey.tr()])),
          ),
        );
        break;
    }
  }
}

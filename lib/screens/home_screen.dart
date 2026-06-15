import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/podcast_episode.dart';
import '../models/spiritual_exercise.dart';
import '../services/actio_service.dart';
import '../services/connectivity_service.dart';
import '../services/lectio_cache_service.dart';
import '../services/podcast_service.dart';
import '../services/spiritual_exercise_service.dart';
import '../services/support_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_spacing.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../widgets/home_v2/daily_actio_card.dart';
import '../widgets/home_v2/daily_podcast_card.dart';
import '../widgets/home_v2/featured_exercise_card.dart';
import '../widgets/home_v2/glass_bottom_nav.dart';
import '../widgets/home_v2/hero_pulse_button.dart';
import '../widgets/home_v2/home_hero_section.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/home_v2/lectio_date_selector.dart';
import '../widgets/home_v2/news_horizontal_list.dart';
import 'about_screen.dart';
import 'adoration_screen.dart';
import 'donation_screen.dart';
import 'feedback_screen.dart';
import 'intentions_list_screen.dart';
import 'intro_screen.dart';
import 'lectio_screen.dart';
import 'lectio_survey_screen.dart';
import 'news_detail_screen.dart';
import 'news_list_screen.dart';
import 'newsletter_list_screen.dart';
import 'notes_list_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'rosary_screen.dart';
import 'settings_screen.dart';
import 'spiritual_exercise_detail_screen.dart';
import 'stations_of_cross_screen.dart';

/// Prémiový HomeScreen (v2) — nová verzia popri pôvodnom [HomeScreen].
/// Hero → denný podcast → výber dňa → actio → aktuality, plávajúce glass menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Hero obrázky — rotujú (náhodný pri každom spustení).
  static const List<String> _heroImages = [
    'assets/images/slide0.webp',
    'assets/images/slide1.webp',
    'assets/images/slide2.webp',
    'assets/images/slide3.webp',
    'assets/images/slide4.webp',
    'assets/images/slide5.webp',
  ];

  late final String _heroImage =
      _heroImages[Random().nextInt(_heroImages.length)];

  DateTime _selectedDate = DateTime.now();
  // -1 = žiadna položka nie je trvalo zvýraznená (menu je launcher, nie taby).
  final int _navIndex = -1;

  PodcastEpisode? _podcast;
  bool _loadingPodcast = true;

  String? _actio;
  bool _loadingActio = true;

  List<Map<String, dynamic>> _news = [];
  bool _loadingNews = true;

  SpiritualExercise? _exercise;

  String? _avatarUrl;
  bool _isSupporter = false;

  bool _heartEligible = false;
  bool _profileLoaded = false;
  bool _surveyPending = false;

  bool _isOffline = false;
  final Set<String> _cachedDates = {};
  StreamSubscription<bool>? _connSub;

  bool _dataLoaded = false;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    _checkHeroNudges();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    // Predpokladaj online → žiadny offline „flash" pri štarte, kým prebehne
    // prvá (asynchrónna) kontrola reálneho internetu.
    _connSub = ConnectivityService.instance.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (!mounted) return;
      final wasOffline = _isOffline;
      setState(() => _isOffline = !isOnline);
      if (wasOffline && isOnline) {
        _loadAll(); // refresh po obnovení pripojenia
      } else if (!isOnline) {
        _checkCachedDates();
      }
    });
    // Potvrď stav asynchrónne (nie prechodný sync isOnline).
    ConnectivityService.instance.checkConnectivity().then((online) {
      if (!mounted || online) return;
      setState(() => _isOffline = true);
      _checkCachedDates();
    });
  }

  /// Označí dni, ktoré sú stiahnuté (dostupné offline) — pre kalendár.
  Future<void> _checkCachedDates() async {
    final today = DateTime.now();
    final lang = _localeCode;
    final dates = <String>{};
    for (int i = -3; i <= 6; i++) {
      final date = today.add(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final cached = await LectioCacheService.instance.getCachedLectio(
        dateStr,
        lang,
      );
      if (cached != null) dates.add(dateStr);
    }
    if (!mounted) return;
    setState(() {
      _cachedDates
        ..clear()
        ..addAll(dates);
    });
  }

  /// Pripraví stredový „spotlight" badge. Priorita: dotazník (od 6. spustenia,
  /// kým nie je vyplnený — ako v1) > donation srdce (každé 10. otvorenie,
  /// nie podporovateľom). Konkrétny badge sa skladá v [_buildHeroBadge].
  Future<void> _checkHeroNudges() async {
    final prefs = await SharedPreferences.getInstance();

    // Donation srdce — každé 10. otvorenie.
    final heartCount = (prefs.getInt('support_heart_open_count') ?? 0) + 1;
    await prefs.setInt('support_heart_open_count', heartCount);
    _heartEligible = heartCount % 10 == 0;

    // Dotazník — po 6. spustení, kým nie je vyplnený.
    final completed = prefs.getBool('survey_completed') ?? false;
    final surveyCount = (prefs.getInt('survey_launch_count') ?? 0) + 1;
    await prefs.setInt('survey_launch_count', surveyCount);
    _surveyPending = !completed && surveyCount >= 6;

    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale.languageCode;
    if (!_dataLoaded) {
      _dataLoaded = true;
      _lastLocale = locale;
      _loadAll();
    } else if (_lastLocale != locale) {
      _lastLocale = locale;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPodcast(),
      _loadActio(),
      _loadNews(),
      _loadProfile(),
      _loadExercise(),
    ]);
  }

  Future<void> _loadExercise() async {
    // Produkcia: len publikované, aktívne a budúce cvičenia.
    final ex = await SpiritualExerciseService.instance.fetchFeatured(
      _localeCode,
    );
    if (!mounted) return;
    setState(() => _exercise = ex);
  }

  Future<void> _loadProfile() async {
    final summary = await SupportService.instance.fetchProfileSummary();
    if (!mounted) return;
    setState(() {
      _avatarUrl = summary.avatarUrl;
      _isSupporter = summary.isSupporter;
      _profileLoaded = true;
    });
  }

  Future<void> _loadPodcast() async {
    if (mounted) setState(() => _loadingPodcast = true);
    final ep = await PodcastService.instance.fetchTodaysEpisode(_localeCode);
    if (!mounted) return;
    setState(() {
      _podcast = ep;
      _loadingPodcast = false;
    });
  }

  Future<void> _loadActio() async {
    if (mounted) setState(() => _loadingActio = true);
    final actio = await ActioService.instance.fetchTodaysActio(_localeCode);
    if (!mounted) return;
    setState(() {
      _actio = actio;
      _loadingActio = false;
    });
  }

  Future<void> _loadNews() async {
    if (mounted) setState(() => _loadingNews = true);
    try {
      final now = DateTime.now().toIso8601String();
      final res = await Supabase.instance.client
          .from('news')
          .select()
          .eq('lang', _localeCode)
          .lte('published_at', now)
          .order('published_at', ascending: false)
          .limit(8);
      if (!mounted) return;
      setState(() {
        _news = List<Map<String, dynamic>>.from(res);
        _loadingNews = false;
      });
    } catch (e) {
      appLogger.e('❌ HomeV2 news: $e');
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  String get _localeCode => context.locale.languageCode;

  // ── Navigácia ─────────────────────────────────────────────────────────────

  void _push(Widget screen, String routeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
        settings: RouteSettings(name: routeName),
      ),
    );
  }

  void _openLectio(DateTime date) {
    setState(() => _selectedDate = date);
    _push(LectioScreen(selectedDate: date), '/lectio');
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateLimitsConfig.getMinDate(),
      lastDate: DateLimitsConfig.getMaxDate(),
      locale: context.locale,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => HomeV2.datePickerTheme(context, child!),
    );
    if (picked != null) _openLectio(picked);
  }

  Future<void> _openSpotify() async {
    final url = PodcastService.spotifyShowUrl(_localeCode);
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSurvey() {
    UmamiAnalyticsService().trackEvent(
      'survey_icon_clicked',
      eventData: {'source': 'home_v2'},
    );
    _push(const LectioSurveyScreen(), '/survey');
  }

  /// Stredový „spotlight" badge: dotazník má prioritu pred donation srdcom.
  Widget? _buildHeroBadge() {
    if (_surveyPending) {
      return HeroPulseButton(
        icon: Icons.assignment_rounded,
        gradient: const [Color(0xFF800020), Color(0xFFB23A52)],
        glowColor: const Color(0xFF800020),
        tooltip: tr('survey_nudge'),
        onTap: _openSurvey,
      );
    }
    if (_heartEligible && _profileLoaded && !_isSupporter) {
      return HeroPulseButton(
        icon: Icons.favorite_rounded,
        gradient: const [HomeV2.gold, HomeV2.goldLight],
        glowColor: HomeV2.gold,
        tooltip: tr('support'),
        onTap: () => _push(const DonationScreen(), '/donation'),
      );
    }
    return null;
  }

  void _onNavTap(int index) {
    // Launcher (Domov odstránený — menu je viditeľné len na home):
    // 0 Lectio · 1 Poznámky · 2 Modlitby · 3 Na úvod · 4 Viac
    switch (index) {
      case 0:
        _openLectio(DateTime.now());
        break;
      case 1:
        if (Supabase.instance.client.auth.currentSession != null) {
          _push(const NotesListScreen(), '/notes');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('login_required'))),
          );
        }
        break;
      case 2:
        _push(const IntentionsListScreen(), '/intentions');
        break;
      case 3:
        _push(const IntroScreen(), '/intro');
        break;
      case 4:
        _showMoreMenu();
        break;
    }
  }

  void _showActioDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          title: Text(
            tr('actio'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              (_actio != null && _actio!.trim().isNotEmpty)
                  ? _actio!
                  : tr('quote_not_available'),
              style: HomeV2.serifQuote(dialogContext, size: 19),
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
                _openLectio(DateTime.now());
              },
              child: Text(tr('start_lectio_today')),
            ),
          ],
        );
      },
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeV2.card(context),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) {
        Widget tile(IconData icon, String labelKey, VoidCallback onTap) {
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeV2.iconAccent(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: HomeV2.iconAccent(context), size: 20),
            ),
            title: Text(tr(labelKey)),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: HomeV2.textMuted(context),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: HomeV2.textMuted(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        tile(
                          Icons.favorite_rounded,
                          'support_lectio',
                          () => _push(const DonationScreen(), '/donation'),
                        ),
                        tile(
                          Icons.church_rounded,
                          'devotions',
                          _showDevotionsMenu,
                        ),
                        tile(
                          Icons.campaign_rounded,
                          'news',
                          () => _push(const NewsListScreen(), '/news-list'),
                        ),
                        tile(
                          Icons.mail_rounded,
                          'newsletter_title',
                          () => _push(
                            const NewsletterListScreen(),
                            '/newsletter',
                          ),
                        ),
                        tile(
                          Icons.notifications_rounded,
                          'notifications.title',
                          () => _push(
                            const NotificationsScreen(),
                            '/notifications',
                          ),
                        ),
                        tile(
                          Icons.settings_rounded,
                          'settings',
                          () => _push(const SettingsScreen(), '/settings'),
                        ),
                        tile(
                          Icons.feedback_rounded,
                          'feedback.title',
                          () => _push(const FeedbackScreen(), '/feedback'),
                        ),
                        tile(
                          Icons.info_rounded,
                          'about_title',
                          () => _push(const AboutScreen(), '/about'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Submenu „Pobožnosti" — Ruženec, Adorácia, Krížové cesty.
  void _showDevotionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeV2.card(context),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) {
        Widget tile(IconData icon, String labelKey, VoidCallback onTap) {
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeV2.iconAccent(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: HomeV2.iconAccent(context), size: 20),
            ),
            title: Text(tr(labelKey)),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: HomeV2.textMuted(context),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: HomeV2.textMuted(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: HomeV2.textDark(context),
                      ),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showMoreMenu();
                      },
                    ),
                    Text(
                      tr('devotions'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ],
                ),
              ),
              tile(
                Icons.auto_stories_rounded,
                'rosary_title',
                () => _push(const RosaryScreen(), '/rosary'),
              ),
              tile(
                Icons.brightness_7_rounded,
                'adoration_title',
                () => _push(const AdorationScreen(), '/adoration'),
              ),
              tile(
                Icons.add_rounded,
                'stations_of_cross_title',
                () => _push(const StationsOfCrossScreen(), '/stations'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        96 + MediaQuery.of(context).viewPadding.bottom + AppSpacing.lg;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Stack(
          children: [
            RefreshIndicator(
              color: HomeV2.primary,
              onRefresh: _loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomClearance),
                children: [
                  HomeHeroSection(
                    imageAsset: _heroImage,
                    avatarUrl: _avatarUrl,
                    isSupporter: _isSupporter,
                    floatingBadge: _isOffline ? null : _buildHeroBadge(),
                    onProfileTap: () =>
                        _push(const ProfileScreen(), '/profile'),
                    onNotificationsTap: () =>
                        _push(const NotificationsScreen(), '/notifications'),
                  ),
                  // Blok pod hero. Online: podcast prekrýva spodok hera (overlap
                  // −84). Offline: žiadny overlap (0) — hore banner, sieťové
                  // sekcie (podcast/cvičenia/aktuality) sú skryté.
                  Transform.translate(
                    offset: Offset(0, _isOffline ? 0 : -84),
                    child: Column(
                      children: [
                        if (_isOffline) ...[
                          _buildOfflineBanner(),
                          const SizedBox(height: AppSpacing.lg),
                        ] else ...[
                          _buildPodcastSection(),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                        LectioDateSelector(
                          selectedDate: _selectedDate,
                          onDateSelected: _openLectio,
                          onCalendarTap: _openDatePicker,
                          isOffline: _isOffline,
                          cachedDates: _cachedDates,
                        ),
                        const SizedBox(height: 28),
                        DailyActioCard(
                          actioText: _actio,
                          isLoading: _loadingActio,
                          onTap: _showActioDialog,
                        ),
                        if (!_isOffline && _exercise != null) ...[
                          const SizedBox(height: 28),
                          FeaturedExerciseCard(
                            exercise: _exercise!,
                            onTap: () => _push(
                              SpiritualExerciseDetailScreen(
                                slug: _exercise!.slug,
                              ),
                              '/spiritual-exercise',
                            ),
                          ),
                        ],
                        if (!_isOffline) ...[
                          const SizedBox(height: 28),
                          NewsHorizontalList(
                            articles: _news,
                            isLoading: _loadingNews,
                            onArticleTap: (article) => _push(
                              NewsDetailScreen(newsData: article),
                              '/news-detail',
                            ),
                            onSeeAll: () =>
                                _push(const NewsListScreen(), '/news-list'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Plávajúce glass menu
            Align(
              alignment: Alignment.bottomCenter,
              child: GlassBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastSection() {
    if (_loadingPodcast) {
      return const _PodcastLoadingCard();
    }
    if (_podcast == null) {
      return const SizedBox.shrink();
    }
    final hasSpotify = PodcastService.spotifyShowUrl(_localeCode) != null;
    return DailyPodcastCard(
      episode: _podcast!,
      onSpotify: hasSpotify ? _openSpotify : null,
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        border: Border.all(color: const Color(0xFFF1D2A0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFFB26A00), size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('offline.no_connection'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A5200),
                  ),
                ),
                Text(
                  tr('offline.cached_data'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB26A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastLoadingCard extends StatelessWidget {
  const _PodcastLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      height: 220,
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Center(
        child: CircularProgressIndicator(color: HomeV2.primary, strokeWidth: 2),
      ),
    );
  }
}

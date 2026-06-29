import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/podcast_episode.dart';
import '../models/spiritual_exercise.dart';
import '../services/actio_service.dart';
import '../services/home_widget_service.dart';
import '../services/connectivity_service.dart';
import '../services/documents_service.dart';
import '../services/lectio_admin_service.dart';
import '../services/lectio_cache_service.dart';
import '../services/podcast_service.dart';
import '../services/spiritual_exercise_service.dart';
import '../services/support_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_spacing.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../utils/scripture_reference.dart';
import '../widgets/home_v2/daily_actio_card.dart';
import '../widgets/home_v2/daily_podcast_card.dart';
import '../widgets/home_v2/featured_exercise_card.dart';
import '../widgets/home_v2/featured_project_card.dart';
import '../widgets/home_v2/glass_bottom_nav.dart';
import '../widgets/home_v2/hero_pulse_button.dart';
import '../widgets/home_v2/home_hero_section.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/home_v2/lectio_date_selector.dart';
import '../widgets/home_v2/news_horizontal_list.dart';
import 'about_screen.dart';
import 'adoration_screen.dart';
import 'documents_list_screen.dart';
import 'donation_screen.dart';
import 'feedback_screen.dart';
import 'help_screen.dart';
import 'projects/potulky_bibliou_screen.dart';
import 'projects/kurz_lectio_screen.dart';
import 'shop/shop_screen.dart';
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
import 'prayers_screen.dart';
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
  // Režim „celého Lectio" audia (Nastavenia): 'long' (default) / 'short'.
  String _lectioAudioMode = 'long';

  String? _actio;
  bool _loadingActio = true;

  List<Map<String, dynamic>> _news = [];
  bool _loadingNews = true;

  SpiritualExercise? _exercise;

  // Featured carousel (cvičenie + projekty Slovo bez hraníc)
  final PageController _featuredController = PageController();
  int _featuredPage = 0;
  bool _featuredRandomized = false; // náhodný štartovací slide raz za spustenie

  String? _avatarUrl;
  bool _isSupporter = false;
  String? _supportTier; // tier predplatného → farba prstenca okolo avatara
  bool _canViewDocuments = false;
  bool _isAdmin =
      false; // projektové stránky (Potulky, Kurz) sú len pre adminov

  bool _heartEligible = false;
  bool _profileLoaded = false;

  /// Dotazník je dočasne vypnutý (spustili sme podporu kurzu Lectio).
  /// Logiku ani stránku [LectioSurveyScreen] nemažeme — pre budúci dotazník
  /// stačí prepnúť tento flag na `true`.
  static const bool _surveyFeatureEnabled = false;
  bool _surveyPending = false;

  bool _isOffline = false;
  final Set<String> _cachedDates = {};
  StreamSubscription<bool>? _connSub;

  bool _dataLoaded = false;
  String? _lastLocale;

  // ── Coach marks (prvé spustenie) ─────────────────────────────────────────
  // DOČASNE true → sprievodca sa ukáže pri každom reštarte (vývoj/testovanie).
  // Pred vydaním prepnúť na false → ukáže sa len raz (flag `_kCoachFlag`).
  static const bool _kCoachAlwaysShow = false;
  static const String _kCoachFlag = 'coach_marks_v1';
  final GlobalKey _scProfile = GlobalKey();
  final GlobalKey _scAudio = GlobalKey();
  final GlobalKey _scLectio = GlobalKey();
  final GlobalKey _scIntro = GlobalKey();
  final GlobalKey _scIntentions = GlobalKey();
  final GlobalKey _scMore = GlobalKey();
  ShowcaseView? _showcase;

  @override
  void initState() {
    super.initState();
    _showcase = ShowcaseView.register(
      // Offline/bez Spotify → chýbajúce ciele preskočí (nezasekne sa sekvencia).
      skipIfTargetNotPresent: true,
      // Posunie obsah tak, aby bol cieľ viditeľný (tour ide cez scrollovaný obsah).
      enableAutoScroll: true,
    );
    _checkHeroNudges();
    _initConnectivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartCoachMarks();
      // Home je nasadený ako root → bezpečné otvoriť Lectio z widgetu
      // (ak appka štartovala ťuknutím na Actio widget).
      HomeWidgetService.markHomeReady();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _showcase?.unregister();
    _featuredController.dispose();
    super.dispose();
  }

  /// Featured carousel: odporúčané cvičenie + projekty Slovo bez hraníc.
  Widget _buildFeaturedCarousel() {
    final mq = MediaQuery.of(context);
    // Na tablete vyššia karta (telefón 180); v landscape ešte vyššia, inak je
    // featured karta na šírku neproporčne nízka.
    final cardH = mq.size.shortestSide < 600
        ? 180.0
        : (mq.orientation == Orientation.landscape ? 300.0 : 240.0);

    final pages = <Widget>[
      if (_exercise != null)
        FeaturedExerciseCard(
          exercise: _exercise!,
          height: cardH,
          onTap: () => _push(
            SpiritualExerciseDetailScreen(slug: _exercise!.slug),
            '/spiritual-exercise',
          ),
        ),
      FeaturedProjectCard(
        imageAsset: 'assets/images/potulky_hero.webp',
        height: cardH,
        icon: Icons.volunteer_activism_rounded,
        badge: tr('projects.support_button'),
        title: tr('projects.potulky.hero_title'),
        subtitle: tr('projects.potulky.hero_badge'),
        onTap: () =>
            _push(const PotulkyBibliouScreen(), '/potulky-bibliou'),
      ),
      FeaturedProjectCard(
        imageAsset: 'assets/images/course.webp',
        height: cardH,
        icon: Icons.volunteer_activism_rounded,
        badge: tr('projects.support_button'),
        title: tr('projects.kurz.hero_title'),
        subtitle: tr('projects.kurz.hero_badge'),
        onTap: () => _push(const KurzLectioScreen(), '/kurz-lectio'),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: cardH,
          child: PageView.builder(
            controller: _featuredController,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _featuredPage = i),
            itemBuilder: (_, i) => pages[i],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pages.length, (i) {
            final active = i == _featuredPage.clamp(0, pages.length - 1);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? HomeV2.primary
                    : HomeV2.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _maybeStartCoachMarks() async {
    if (!_kCoachAlwaysShow) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kCoachFlag) ?? false) return;
      await prefs.setBool(_kCoachFlag, true);
    }
    if (!mounted) return;
    // Krátke oneskorenie — nech je hero vykreslený a layout ustálený.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _showcase?.startShowCase([
      _scProfile,
      _scAudio,
      _scLectio,
      _scIntro,
      _scIntentions,
      _scMore,
    ]);
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
        ignoreExpiry: true,
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

    // Dotazník — po 6. spustení, kým nie je vyplnený. Výpočet je ponechaný,
    // no brána `_surveyFeatureEnabled` ho drží vypnutý (beží podpora kurzu).
    final completed = prefs.getBool('survey_completed') ?? false;
    final surveyCount = (prefs.getInt('survey_launch_count') ?? 0) + 1;
    await prefs.setInt('survey_launch_count', surveyCount);
    _surveyPending = !completed && surveyCount >= 6 && _surveyFeatureEnabled;

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
      _loadDocumentsAccess(),
      _loadAdmin(),
    ]);
  }

  Future<void> _loadDocumentsAccess() async {
    final allowed = await DocumentsService.instance.hasAccess();
    if (!mounted) return;
    setState(() => _canViewDocuments = allowed);
  }

  Future<void> _loadAdmin() async {
    final admin = await LectioAdminService.instance.isAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = admin);
  }

  Future<void> _loadExercise() async {
    // Produkcia: len publikované, aktívne a budúce cvičenia.
    final ex = await SpiritualExerciseService.instance.fetchFeatured(
      _localeCode,
    );
    if (!mounted) return;
    setState(() => _exercise = ex);
    _randomizeFeaturedStart();
  }

  /// Pri každom spustení zobrazí náhodný slide vo featured carouseli
  /// (raz za mount; poradie strán: cvičenie? + Potulky + Kurz).
  void _randomizeFeaturedStart() {
    if (_featuredRandomized) return;
    _featuredRandomized = true;
    final count = (_exercise != null ? 1 : 0) + 2;
    if (count <= 1) return;
    final target = Random().nextInt(count);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_featuredController.hasClients) {
        _featuredController.jumpToPage(target);
      }
      setState(() => _featuredPage = target);
    });
  }

  Future<void> _loadProfile() async {
    final summary = await SupportService.instance.fetchProfileSummary();
    if (!mounted) return;
    setState(() {
      _avatarUrl = summary.avatarUrl;
      _isSupporter = summary.isSupporter;
      _supportTier = summary.supportTier;
      _profileLoaded = true;
    });
  }

  Future<void> _loadPodcast() async {
    if (mounted) setState(() => _loadingPodcast = true);
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('lectio_audio_mode') == 'short'
        ? 'short'
        : 'long';
    final ep = await PodcastService.instance.fetchTodaysEpisode(_localeCode);
    if (!mounted) return;
    setState(() {
      _podcast = ep;
      _lectioAudioMode = mode;
      _loadingPodcast = false;
    });
  }

  Future<void> _loadActio() async {
    if (mounted) setState(() => _loadingActio = true);
    final quote = await ActioService.instance.fetchTodaysActio(_localeCode);
    if (!mounted) return;
    setState(() {
      _actio = quote?.text;
      _loadingActio = false;
    });
    // Aktualizuj domovský widget „Actio" — text + súradnice dňa.
    HomeWidgetService.pushActio(
      text: quote?.text,
      reference: ScriptureReference.format(quote?.suradnice, _localeCode),
      date: DateTime.now(),
    );
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
    // Admin: bez obmedzenia (široký rozsah); bežný používateľ: limity.
    final firstDate = _isAdmin ? DateTime(2000) : DateLimitsConfig.getMinDate();
    final lastDate = _isAdmin ? DateTime(2100) : DateLimitsConfig.getMaxDate();
    // initialDate MUSÍ byť v [firstDate, lastDate], inak sa picker v release
    // builde na Androide správa chybne (nedá sa posúvať).
    var initialDate = _selectedDate;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('login_required'))));
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
        final actio = (_actio != null && _actio!.trim().isNotEmpty)
            ? _actio!
            : tr('quote_not_available');
        return Dialog(
          backgroundColor: HomeV2.card(dialogContext),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HomeV2.radius),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overline „ACTIO" v brand štýle (namiesto generického titulku)
                Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      size: 18,
                      color: HomeV2.iconAccent(dialogContext),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      tr('actio').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: HomeV2.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      actio,
                      style: HomeV2.serifQuote(
                        dialogContext,
                        size: 20,
                        color: HomeV2.textDark(dialogContext),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeV2.textMuted(dialogContext),
                      ),
                      child: Text(tr('close')),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _openLectio(DateTime.now());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                        ),
                      ),
                      child: Text(tr('start_lectio_today')),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                        // E-shop je len pre SK → dlaždica len v SK mutácii.
                        if (context.locale.languageCode == 'sk')
                          tile(
                            Icons.shopping_bag_rounded,
                            'shop.title',
                            () => _push(const ShopScreen(), '/shop'),
                          ),
                        // Projektové stránky (Slovo bez hraníc) — pre všetkých.
                        tile(
                          Icons.explore_rounded,
                          'projects.potulky.hero_title',
                          () => _push(
                            const PotulkyBibliouScreen(),
                            '/potulky-bibliou',
                          ),
                        ),
                        tile(
                          Icons.school_rounded,
                          'projects.kurz.hero_title',
                          () => _push(const KurzLectioScreen(), '/kurz-lectio'),
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
                        if (_canViewDocuments)
                          tile(
                            Icons.folder_special_rounded,
                            'documents.title',
                            () => _push(
                              const DocumentsListScreen(),
                              '/documents',
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
                          Icons.help_outline_rounded,
                          'help.title',
                          () => _push(const HelpScreen(), '/help'),
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
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
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
                Icons.menu_book_rounded,
                'prayers.title',
                () => _push(const PrayersScreen(), '/prayers'),
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

  /// Branded showcase obal (coach mark) okolo cieľového widgetu.
  /// [radius] = zaoblenie zvýraznenia (pre väčšie karty napr. HomeV2.radius).
  Widget _coachMark(
    GlobalKey key,
    String titleKey,
    String descKey,
    Widget child, {
    bool circle = false,
    double radius = 14,
    EdgeInsets targetPadding = const EdgeInsets.all(6),
  }) {
    return Showcase(
      key: key,
      title: tr(titleKey),
      description: tr(descKey),
      titleTextAlign: TextAlign.center,
      descriptionTextAlign: TextAlign.center,
      tooltipBackgroundColor: HomeV2.card(context),
      textColor: HomeV2.textDark(context),
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: HomeV2.primary,
      ),
      descTextStyle: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: HomeV2.textMuted(context),
      ),
      tooltipBorderRadius: BorderRadius.circular(HomeV2.radiusSm),
      tooltipPadding: const EdgeInsets.all(AppSpacing.md),
      overlayColor: Colors.black,
      overlayOpacity: 0.78,
      targetShapeBorder: circle
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      targetBorderRadius: circle ? null : BorderRadius.circular(radius),
      targetPadding: targetPadding,
      child: child,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Priestor pod poslednou kartou (aktuality) tak, aby ju neprekryla plávajúca
    // navigácia. Blok pod hero je posunutý o −84 (Transform), čo už dole pridáva
    // medzeru — preto stačí menšia rezerva.
    final bottomClearance =
        56 + MediaQuery.of(context).viewPadding.bottom + AppSpacing.lg;

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
                    supportTier: _supportTier,
                    floatingBadge: _isOffline ? null : _buildHeroBadge(),
                    onProfileTap: () =>
                        _push(const ProfileScreen(), '/profile'),
                    onNotificationsTap: () =>
                        _push(const NotificationsScreen(), '/notifications'),
                    wrapProfile: (child) => _coachMark(
                      _scProfile,
                      'coach.profile_title',
                      'coach.profile_desc',
                      child,
                      circle: true,
                    ),
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
                        // Mierne odsadenie zľava/sprava — aby coach-mark
                        // zvýraznenie selectora nešlo od kraja po kraj.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: _coachMark(
                            _scLectio,
                            'coach.lectio_title',
                            'coach.lectio_desc',
                            LectioDateSelector(
                              selectedDate: _selectedDate,
                              onDateSelected: _openLectio,
                              onCalendarTap: _openDatePicker,
                              isOffline: _isOffline,
                              cachedDates: _cachedDates,
                            ),
                            radius: HomeV2.radius,
                            targetPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        DailyActioCard(
                          actioText: _actio,
                          isLoading: _loadingActio,
                          onTap: _showActioDialog,
                        ),
                        if (!_isOffline) ...[
                          const SizedBox(height: 28),
                          _buildFeaturedCarousel(),
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
              child: GlassBottomNav(
                currentIndex: _navIndex,
                onTap: _onNavTap,
                wrapItem: (i, child) {
                  if (i == 2) {
                    return _coachMark(
                      _scIntentions,
                      'coach.intentions_title',
                      'coach.intentions_desc',
                      child,
                    );
                  }
                  if (i == 3) {
                    return _coachMark(
                      _scIntro,
                      'coach.intro_title',
                      'coach.intro_desc',
                      child,
                    );
                  }
                  if (i == 4) {
                    return _coachMark(
                      _scMore,
                      'coach.more_title',
                      'coach.more_desc',
                      child,
                    );
                  }
                  return child;
                },
              ),
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
    // Margin riešime zvonka (Padding) a karte ho vynulujeme → coach-mark
    // zvýraznenie sadne presne na bielu kartu, bez pozadia po stranách.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: _coachMark(
        _scAudio,
        'coach.audio_title',
        'coach.audio_desc',
        DailyPodcastCard(
          episode: _podcast!,
          onSpotify: hasSpotify ? _openSpotify : null,
          margin: EdgeInsets.zero,
          audioMode: _lectioAudioMode,
        ),
        radius: HomeV2.radius,
        targetPadding: EdgeInsets.zero,
      ),
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
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFB26A00),
            size: 22,
          ),
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

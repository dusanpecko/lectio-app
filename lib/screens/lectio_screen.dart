import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/podcast_episode.dart';
import '../services/audio_download_service.dart';
import '../services/lectio_admin_service.dart';
import '../services/lectio_cache_service.dart';
import '../services/lectio_data_service.dart';
import '../services/podcast_service.dart';
import '../shared/app_spacing.dart';
import '../shared/date_limits_config.dart';
import '../utils/app_logger.dart';
import '../utils/route_observer.dart';
import '../utils/scripture_reference.dart';
import '../services/media_player_bus.dart';
import '../widgets/home_v2/daily_podcast_card.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/lectio_v2/lectio_step_card.dart';
import 'lectio_reader_screen.dart';
import 'note_detail_screen.dart';
import 'settings_screen.dart';

/// Prémiový Lectio screen (v2) — popri pôvodnom [LectioScreen].
/// Hero → podcast → výber biblie → karty krokov (s per-step audiom) → poznámky.
class LectioScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final String? selectedLang;

  const LectioScreen({super.key, this.selectedDate, this.selectedLang});

  @override
  State<LectioScreen> createState() => _LectioScreenState();
}

class _LectioScreenState extends State<LectioScreen> with RouteAware {
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

  late DateTime _date = widget.selectedDate ?? DateTime.now();

  Map<String, dynamic>? _data;
  bool _loading = true;

  String _selectedBible = 'biblia_1';

  /// Režim prehrávania Lectio audia (Nastavenia):
  /// 'long' = celé s hudbou (default), 'short' = celé bez hudby, 'steps' = po krokoch.
  String _lectioAudioMode = 'long';

  PodcastEpisode? _episode;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Textové kroky pre fullscreen čítačku (Biblia + Lectio…Actio), bez poznámok.
  List<LectioReaderStep> _readerSteps = [];

  static const int _offlineDays = 7;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isDownloaded = false;

  bool _loaded = false;
  bool _isAdmin = false;

  String get _locale => widget.selectedLang ?? context.locale.languageCode;

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WakelockPlus.disable();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
    if (!_loaded) {
      _loaded = true;
      _load();
      _checkAdmin();
    }
  }

  /// Návrat na túto obrazovku (napr. z Nastavení) — obnov nastavenia, ktoré sa
  /// mohli zmeniť (režim Lectio audia, výber biblie). Bez nového sieťového loadu.
  @override
  void didPopNext() {
    _refreshSettings();
  }

  Future<void> _refreshSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('lectio_audio_mode') ?? 'long';
    final bible = prefs.getString('selectedBible');
    if (!mounted) return;
    setState(() {
      _lectioAudioMode = mode;
      if (bible != null && bible.startsWith('biblia_')) _selectedBible = bible;
    });
  }

  Future<void> _checkAdmin() async {
    final admin = await LectioAdminService.instance.isAdmin();
    if (mounted && admin) setState(() => _isAdmin = admin);
  }

  /// Po uložení upraveného textu kroku — aktualizuj lokálne dáta + rebuild.
  void _onStepTextSaved(String textField, String newText) {
    if (_data != null) setState(() => _data![textField] = newText);
  }

  /// Po pregenerovaní audia kroku — aktualizuj URL + rebuild.
  void _onStepAudioRegenerated(String audioField, String newUrl) {
    if (_data != null) setState(() => _data![audioField] = newUrl);
  }

  /// Admin: pregeneruje CELÉ audio dňa — podcast epizódu + dlhé/krátke
  /// kombinované audio (`/api/podcast/generate`). Spustiť po úprave krokov.
  bool _regeneratingFullAudio = false;
  Future<void> _regenerateFullAudio() async {
    if (_regeneratingFullAudio) return;
    final sourceId = (_data?['id'] as num?)?.toInt();
    if (sourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre tento deň nie je lectio v databáze.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pregenerovať celé audio?'),
        content: const Text(
          'Z aktuálnych krokov sa nanovo poskladá podcast epizóda aj '
          'dlhé (s hudbou) a krátke audio. Trvá to desiatky sekúnd až minúty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generovať'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _regeneratingFullAudio = true);
    final messenger = ScaffoldMessenger.of(context);
    // Blokujúci progres (môže trvať aj minúty).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: AppSpacing.md),
              Flexible(child: Text('Generujem celé audio…')),
            ],
          ),
        ),
      ),
    );

    try {
      final r = await LectioAdminService.instance.regenerateFullAudio(sourceId);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await _load(); // znovu načítaj deň → nové URL audia
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Hotovo — dlhé ${r.long ? "✓" : "✗"}, krátke ${r.short ? "✓" : "✗"}'
            '${r.durationSeconds != null ? " (podcast ${r.durationSeconds}s)" : ""}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Generovanie zlyhalo: $e'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    } finally {
      if (mounted) setState(() => _regeneratingFullAudio = false);
    }
  }

  Future<void> _load() async {
    final reqDate = _date;
    // Ak hrá audio z INÉHO dňa (napr. zostalo hrať a z home sme otvorili iný
    // deň), zastav ho — nový deň začne od začiatku. V rámci toho istého dňa
    // (rovnaké contentId) audio pokračuje, takže pauza/play funguje.
    final reqDayId = DateFormat('yyyy-MM-dd').format(reqDate);
    final bus = MediaPlayerBus.instance;
    if (bus.currentId != null && bus.currentContentId != reqDayId) {
      bus.stop();
    }
    final prefs = await SharedPreferences.getInstance();
    final savedBible = prefs.getString('selectedBible');
    if (savedBible != null && savedBible.startsWith('biblia_')) {
      _selectedBible = savedBible;
    }
    _lectioAudioMode = prefs.getString('lectio_audio_mode') ?? 'long';

    // Keep-awake počas Lectio (podľa nastavenia).
    if (prefs.getBool('keep_screen_on') ?? true) {
      WakelockPlus.enable();
    }

    final results = await Future.wait([
      LectioDataService.instance.getDailyLectio(date: reqDate, locale: _locale),
      PodcastService.instance.fetchEpisodeForDate(reqDate, _locale),
    ]);
    final dateStr = DateFormat('yyyy-MM-dd').format(reqDate);
    // ignoreExpiry: stiahnuté dni musia platiť celé 7-dňové okno, nie len 24 h.
    final cached = await LectioCacheService.instance.getCachedLectio(
      dateStr,
      _locale,
      ignoreExpiry: true,
    );
    // Ignoruj výsledok ak sa medzitým zmenil deň (rýchle prepínanie).
    if (!mounted || reqDate != _date) return;
    final networkData = results[0] as Map<String, dynamic>?;
    setState(() {
      // Offline / výpadok siete: padni na stiahnuté dáta z cache. `_episode`
      // ostane null a kombinované audio sa vyrobí z `_data` v `_audioEpisode`.
      _data = networkData ?? cached?.rawData;
      _episode = results[1] as PodcastEpisode?;
      _isDownloaded = cached != null;
      _loading = false;
    });
  }

  // ── Prepínanie dňa ────────────────────────────────────────────────────────
  void _changeDate(DateTime d) {
    setState(() {
      _date = DateTime(d.year, d.month, d.day);
      _loading = true;
      _data = null;
      _episode = null;
      _isDownloaded = false;
      _currentPage = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _load();
  }

  // Admin nemá obmedzenie pohybu po dátumoch (môže do minulosti aj budúcnosti).
  bool get _canPrev => _isAdmin || DateLimitsConfig.canGoToPreviousDay(_date);
  bool get _canNext => _isAdmin || DateLimitsConfig.canGoToNextDay(_date);

  void _previousDay() {
    if (!_canPrev) return;
    _changeDate(_date.subtract(const Duration(days: 1)));
  }

  void _nextDay() {
    if (!_canNext) return;
    _changeDate(_date.add(const Duration(days: 1)));
  }

  Future<void> _showDatePicker() async {
    // Admin: bez obmedzenia (široký rozsah); bežný používateľ: limity.
    final firstDate = _isAdmin ? DateTime(2000) : DateLimitsConfig.getMinDate();
    final lastDate = _isAdmin ? DateTime(2100) : DateLimitsConfig.getMaxDate();
    // initialDate MUSÍ byť v [firstDate, lastDate], inak sa picker v release
    // builde (vypnuté asserty) na Androide správa chybne (nedá sa posúvať).
    var initialDate = _date;
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
    if (picked != null) _changeDate(picked);
  }

  Future<void> _downloadOffline() async {
    if (_isDownloading || _isDownloaded || _data == null) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    try {
      // Aktuálny deň + 6 nasledujúcich (text do cache + audio).
      for (int i = 0; i < _offlineDays; i++) {
        final day = _date.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final dayData = i == 0
            ? _data!
            : await LectioDataService.instance.getDailyLectio(
                date: day,
                locale: _locale,
              );
        if (dayData == null) continue;

        await LectioCacheService.instance.cacheLectio(
          _toCache(dateStr, dayData),
        );
        await AudioDownloadService.instance.downloadAllForDay(
          lectioData: dayData,
          date: dateStr,
          selectedBible: _selectedBible,
          onProgress: (current, total, progress) {
            if (mounted) {
              setState(() => _downloadProgress = (i + progress) / _offlineDays);
            }
          },
        );

        // Podcast epizóda pre daný deň (ak existuje).
        final ep = i == 0
            ? _episode
            : await PodcastService.instance.fetchEpisodeForDate(day, _locale);
        if (ep?.audioUrl != null && ep!.audioUrl!.isNotEmpty) {
          await AudioDownloadService.instance.downloadAudio(
            ep.audioUrl!,
            dateKey: dateStr,
            trackKey: 'podcast',
          );
        }

        // Cover obrázok do offline (rovnaká disk-cache, akú číta
        // CachedNetworkImage v DailyPodcastCard) — inak je offline len placeholder.
        await _precacheCover(
          ep?.coverImageUrl ?? dayData['podcast_cover_url'] as String?,
        );
      }
      // Kanálový fallback cover (keď epizóda nemá vlastný) — stačí raz.
      await _precacheCover(PodcastService.channelCover(_locale));
      if (mounted) setState(() => _isDownloaded = true);
    } catch (e) {
      appLogger.e('❌ Offline download: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('offline.download_error'))));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Predcachuje cover URL do disk-cache zdieľanej s CachedNetworkImage.
  /// Best-effort — `getSingleFile` stiahne len ak ešte nie je v cache.
  Future<void> _precacheCover(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (e) {
      appLogger.d('🖼️ Cover precache zlyhalo: $e');
    }
  }

  CachedLectioData _toCache(String dateStr, Map<String, dynamic> d) =>
      CachedLectioData(
        date: dateStr,
        locale: _locale,
        lectioHlava: d['hlava'] as String?,
        actioText: d['actio_text'] as String?,
        lectioText: d['lectio_text'] as String?,
        meditatioText: d['meditatio_text'] as String?,
        oratioText: d['oratio_text'] as String?,
        contemplatioText: d['contemplatio_text'] as String?,
        reference: d['reference'] as String?,
        cachedAt: DateTime.now(),
        rawLectioSource: d,
      );

  Future<void> _confirmRemove() async {
    const danger = Color(0xFFD9544D);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HomeV2.card(ctx),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: danger.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('offline.remove_confirm'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: HomeV2.textDark(ctx),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomeV2.textMuted(ctx),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: HomeV2.textMuted(ctx).withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(tr('delete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _removeOffline();
  }

  Future<void> _removeOffline() async {
    for (int i = 0; i < _offlineDays; i++) {
      final dateStr = DateFormat(
        'yyyy-MM-dd',
      ).format(_date.add(Duration(days: i)));
      await LectioCacheService.instance.removeCachedLectio(dateStr, _locale);
      await AudioDownloadService.instance.deleteAudioForDate(dateStr);
    }
    if (mounted) {
      setState(() {
        _isDownloaded = false;
        _downloadProgress = 0;
      });
    }
  }

  void _addNote() {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('login_required'))));
      return;
    }
    final note = {
      'id': null,
      'title': DateFormat('d.M.yyyy').format(_date),
      'content': '',
      'bible_reference': ScriptureReference.format(
        _data?['suradnice_pismo'] as String?,
        _locale,
      ),
      'bible_quote': _data?[_selectedBible] ?? '',
    };
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: _loading ? const _LectioLoading() : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (data == null) {
      return Column(
        children: [
          _buildHero(title: tr('lectio_divina')),
          Expanded(child: Center(child: Text(tr('quote_not_available')))),
        ],
      );
    }

    final title = (data['hlava'] as String?)?.trim();
    final slides = _buildSlides(data);
    final safe = _currentPage.clamp(0, slides.length - 1);

    return Column(
      children: [
        _buildHero(
          title: title?.isNotEmpty == true ? title! : tr('lectio_divina'),
        ),
        if (_audioEpisode(data) != null) ...[
          const SizedBox(height: AppSpacing.md),
          DailyPodcastCard(
            episode: _audioEpisode(data)!,
            showPrimaryButton: false,
            dense: true,
            audioMode: _lectioAudioMode,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => slides[i].child,
          ),
        ),
        _buildProgress(slides, safe),
      ],
    );
  }

  /// Epizóda pre prehrávač „Lectio audio (celé)". Preferuje reálnu podcast
  /// epizódu (kvôli coveru/Spotify), ale ak pre daný deň+jazyk neexistuje a
  /// lectio_source MÁ kombinované audio (`full_long_audio`/`full_short_audio`),
  /// vyrobí syntetickú epizódu priamo z dát — aby sa prehrávač zobrazil aj bez
  /// vygenerovaného podcastu (napr. sviatky / jazyky bez podcast epizódy).
  PodcastEpisode? _audioEpisode(Map<String, dynamic> data) {
    if (_episode != null) return _episode;

    final long = (data['full_long_audio'] as String?)?.trim();
    final short = (data['full_short_audio'] as String?)?.trim();
    final hasCombined =
        (long != null && long.isNotEmpty) ||
        (short != null && short.isNotEmpty);
    if (!hasCombined) return null;

    final hlava = (data['hlava'] as String?)?.trim() ?? '';
    final sur = ScriptureReference.format(
      data['suradnice_pismo'] as String?,
      _locale,
    );
    return PodcastEpisode(
      id: (data['id']).toString(),
      lang: _locale,
      title: sur.isNotEmpty ? '$hlava — $sur' : hlava,
      coverImageUrl: data['podcast_cover_url'] as String?,
      fullLongAudio: long,
      fullShortAudio: short,
    );
  }

  void _openReader(int index) {
    if (_readerSteps.isEmpty) return;
    // Reader index ↔ slide index je 1:1 (čítací krok sa pridáva paralelne so
    // slidom). Po zatvorení čítačky zosynchronizujeme malý slide na krok, na
    // ktorom používateľ skončil — nech sa nevráti tam, kde čítačku otvoril.
    var lastIndex = index;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LectioReaderScreen(
          steps: List.of(_readerSteps),
          initialIndex: index,
          onIndexChanged: (i) => lastIndex = i,
        ),
      ),
    ).then((_) {
      if (!mounted || lastIndex == index) return;
      if (_pageController.hasClients) _pageController.jumpToPage(lastIndex);
    });
  }

  List<({String label, Widget child})> _buildSlides(Map<String, dynamic> data) {
    final suradnice = ScriptureReference.format(
      data['suradnice_pismo'] as String?,
      _locale,
    );
    final dateId = DateFormat('yyyy-MM-dd').format(_date);
    final slides = <({String label, Widget child})>[];
    _readerSteps = []; // textové kroky pre fullscreen čítačku (paralelne)

    // Biblický text (preklad z Nastavení) — prvý slide
    // (podcast je tlačidlo nad slidmi)
    final bibleText = (data[_selectedBible] as String?) ?? '';
    if (bibleText.trim().isNotEmpty) {
      final bibleTitle =
          (data['nazov_$_selectedBible'] as String?)?.trim().isNotEmpty == true
          ? data['nazov_$_selectedBible'] as String
          : tr('lectio_divina');
      final readerIndex = _readerSteps.length;
      _readerSteps.add(
        LectioReaderStep(
          stepKey: '${_selectedBible}_audio',
          title: bibleTitle,
          text: bibleText,
          reference: suradnice.isNotEmpty ? suradnice : null,
          audioUrl: data['${_selectedBible}_audio'] as String?,
          analyticsId: dateId,
          language: _locale,
        ),
      );
      slides.add((
        label: suradnice.isNotEmpty ? suradnice : bibleTitle,
        child: LectioStepCard(
          stepKey: '${_selectedBible}_audio',
          title: bibleTitle,
          text: bibleText,
          reference: suradnice.isNotEmpty ? suradnice : null,
          audioUrl: data['${_selectedBible}_audio'] as String?,
          analyticsId: dateId,
          language: _locale,
          onExpand: () => _openReader(readerIndex),
        ),
      ));
    }

    final sourceId = (data['id'] as num?)?.toInt();

    void addStep(String labelKey, String textField, String audioField) {
      final text = (data[textField] as String?) ?? '';
      if (text.trim().isEmpty) return;
      final readerIndex = _readerSteps.length;
      _readerSteps.add(
        LectioReaderStep(
          stepKey: audioField,
          title: tr(labelKey),
          text: text,
          audioUrl: data[audioField] as String?,
          analyticsId: dateId,
          language: _locale,
          isAdmin: _isAdmin,
          sourceId: sourceId,
          stepField: labelKey,
          textField: textField,
          onTextSaved: (t) => _onStepTextSaved(textField, t),
          onAudioRegenerated: (url) => _onStepAudioRegenerated(audioField, url),
        ),
      );
      slides.add((
        label: tr(labelKey),
        child: LectioStepCard(
          stepKey: audioField,
          title: tr(labelKey),
          text: text,
          audioUrl: data[audioField] as String?,
          analyticsId: dateId,
          language: _locale,
          onExpand: () => _openReader(readerIndex),
          // Admin in-app editácia
          isAdmin: _isAdmin,
          sourceId: sourceId,
          stepField: labelKey,
          textField: textField,
          onTextSaved: (t) => _onStepTextSaved(textField, t),
          onAudioRegenerated: (url) => _onStepAudioRegenerated(audioField, url),
        ),
      ));
    }

    addStep('lectio', 'lectio_text', 'lectio_audio');
    addStep('meditatio', 'meditatio_text', 'meditatio_audio');
    addStep('oratio', 'oratio_text', 'oratio_audio');
    addStep('contemplatio', 'contemplatio_text', 'contemplatio_audio');
    addStep('actio', 'actio_text', 'actio_audio');

    // Poznámky + offline (posledný slide)
    slides.add((
      label: tr('notes_title'),
      child: _scrollSlide(
        Column(
          children: [
            _buildNotesCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildOfflineCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildSettingsCard(),
          ],
        ),
      ),
    ));

    return slides;
  }

  /// Slide pre obsah, ktorý nevypĺňa celú výšku (podcast, poznámky).
  Widget _scrollSlide(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: child,
  );

  // ── Spodný progres ──────────────────────────────────────────────────────
  Widget _buildProgress(
    List<({String label, Widget child})> slides,
    int current,
  ) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: HomeV2.primary,
                disabledColor: HomeV2.textMuted(context).withValues(alpha: 0.3),
                tooltip: 'a11y_previous_section'.tr(),
                onPressed: current > 0
                    ? () => _pageController.animateToPage(
                        current - 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  slides[current].label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: HomeV2.primary,
                disabledColor: HomeV2.textMuted(context).withValues(alpha: 0.3),
                tooltip: 'a11y_next_section'.tr(),
                onPressed: current < slides.length - 1
                    ? () => _pageController.animateToPage(
                        current + 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == current;
              return AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? HomeV2.primary
                      : HomeV2.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _heroDateArrow(
    IconData icon,
    bool enabled,
    VoidCallback onTap, {
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        // Väčšia tap plocha (~44×40) pre pohodlné prepínanie — ikona ostáva 22px.
        child: SizedBox(
          width: 44,
          height: 40,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero({required String title}) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final dateLabel = DateFormat.yMMMMd(_locale).format(_date);

    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(HomeV2.radius + 6),
            ),
            child: Image.asset(
              _heroImage,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: HomeV2.primary.withValues(alpha: 0.15)),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(HomeV2.radius + 6),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.55),
                    Colors.transparent,
                    bg.withValues(alpha: 0.6),
                    bg,
                  ],
                  stops: const [0.0, 0.25, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // Späť
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // Admin: pregenerovať celé audio dňa (podcast + dlhé/krátke)
          if (_isAdmin)
            Positioned(
              top: topPad + AppSpacing.sm,
              right: AppSpacing.lg,
              child: _CircleButton(
                icon: Icons.podcasts_rounded,
                onTap: _regenerateFullAudio,
              ),
            ),
          // Titul + dátum
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prepínanie dňa: ‹ dátum (→ kalendár) › — zaoblený priesvitný
                // podklad (primary) s bielymi šípkami/kalendárom/textom, aby boli
                // čitateľné na svetlej aj tmavej časti hero obrázka.
                // Kompaktný prepínač — bez globálneho škálovania písma.
                MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _heroDateArrow(
                          Icons.chevron_left_rounded,
                          _canPrev,
                          _previousDay,
                          semanticLabel: 'a11y_previous_day'.tr(),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showDatePicker,
                          child: Padding(
                            // Väčšia tap plocha aj pre dátum (otvára kalendár).
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 11,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _heroDateArrow(
                          Icons.chevron_right_rounded,
                          _canNext,
                          _nextDay,
                          semanticLabel: 'a11y_next_day'.tr(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: HomeV2.serifTitle(context, size: 19, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Poznámky ────────────────────────────────────────────────────────────
  Widget _buildNotesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          onTap: _addNote,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeV2.iconAccent(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: HomeV2.iconAccent(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('notes_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                      Text(
                        tr('add_note'),
                        style: TextStyle(
                          fontSize: 13,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Nastavenia ────────────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeV2.iconAccent(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: HomeV2.iconAccent(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    tr('settings'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stiahnuť na offline ───────────────────────────────────────────────────
  Widget _buildOfflineCard() {
    final accent = HomeV2.iconAccent(context);
    final green = const Color(0xFF3FAE6B);

    Widget leading;
    String title;
    String subtitle;

    if (_isDownloaded) {
      leading = Icon(Icons.cloud_done_rounded, color: green, size: 24);
      title = tr('offline.download_success');
      subtitle = tr('offline.cached_data');
    } else if (_isDownloading) {
      leading = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: _downloadProgress > 0 ? _downloadProgress : null,
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      );
      title = tr('offline.download_progress');
      subtitle = '${(_downloadProgress * 100).round()} %';
    } else {
      leading = Icon(Icons.download_rounded, color: accent, size: 24);
      title = tr('offline.download_7_days');
      subtitle = tr('offline.download_description');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          onTap: (_isDownloading || _isDownloaded) ? null : _downloadOffline,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_isDownloaded ? green : accent).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: leading,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: HomeV2.textMuted(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_isDownloaded)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: HomeV2.textMuted(context),
                    ),
                    tooltip: tr('delete'),
                    onPressed: _confirmRemove,
                  )
                else if (!_isDownloading)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: HomeV2.textMuted(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

/// Brandovaný loading počas načítavania dňa (jemné pulzovanie loga na pozadí
/// obrazovky). Zobrazí sa pri prvom načítaní aj pri prepínaní medzi dňami.
class _LectioLoading extends StatefulWidget {
  const _LectioLoading();

  @override
  State<_LectioLoading> createState() => _LectioLoadingState();
}

class _LectioLoadingState extends State<_LectioLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return Center(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.06).animate(curved),
          child: Image.asset(
            'assets/icon/lectio_logo.png',
            width: 88,
            height: 88,
            errorBuilder: (_, _, _) =>
                CircularProgressIndicator(color: HomeV2.primary),
          ),
        ),
      ),
    );
  }
}

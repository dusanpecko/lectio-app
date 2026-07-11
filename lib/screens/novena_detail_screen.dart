import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/novena.dart';
import '../services/novena_progress_service.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_player_factory.dart';
import '../widgets/audio/audio_progress_bar.dart';
import '../widgets/collapsible_hero_app_bar.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// Jeden slide dňa deviatnika (úvod / denný text / záver).
class _Slide {
  final String label;
  final String? title;
  final String html;
  final String? audioUrl;
  final bool isConclusion;
  const _Slide({
    required this.label,
    this.title,
    required this.html,
    this.audioUrl,
    this.isConclusion = false,
  });
}

/// Detail deviatnika — pred začatím úvodná obrazovka s pripomienkou,
/// po začatí denné slidy (úvod → deň N → záver) vo vizuáli lectio.
/// Progres je kalendárny od štartu (lokálny, viď [NovenaProgressService]).
class NovenaDetailScreen extends StatefulWidget {
  const NovenaDetailScreen({super.key, required this.variants});

  /// Jazykové verzie toho istého deviatnika (aktuálny jazyk prvý).
  final List<Novena> variants;

  @override
  State<NovenaDetailScreen> createState() => _NovenaDetailScreenState();
}

class _NovenaDetailScreenState extends State<NovenaDetailScreen> {
  int _variantIndex = 0;
  NovenaProgress? _progress;
  bool _loading = true;

  /// Deň, ktorý si používateľ prezerá (1-based; ≤ unlockedDay).
  int _viewDay = 1;
  int _slideIndex = 0;
  late PageController _pageController;

  // Nastavenie pripomienky pred štartom
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Audio
  final AudioPlayer _player = createAppAudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _isPlaying = false;
  bool _audioLoading = false;
  String? _loadedUrl;

  Novena get _novena => widget.variants[_variantIndex];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _playerSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      if (completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      setState(() => _isPlaying = state.playing && !completed);
    });
    _loadProgress();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final p = await NovenaProgressService.instance.getProgress(
      _novena.baseCode,
    );
    if (!mounted) return;
    setState(() {
      _progress = p;
      _loading = false;
      if (p != null) {
        _viewDay = p.unlockedDayFor(_novena.totalDays);
        _reminderEnabled = p.reminderEnabled;
        _reminderTime = TimeOfDay(
          hour: p.reminderHour,
          minute: p.reminderMinute,
        );
      }
    });
  }

  // ── Akcie ───────────────────────────────────────────────────────────────────

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    final p = await NovenaProgressService.instance.start(
      _novena.baseCode,
      novenaTitle: _novena.title,
      totalDays: _novena.totalDays,
      reminderEnabled: _reminderEnabled,
      reminderHour: _reminderTime.hour,
      reminderMinute: _reminderTime.minute,
    );
    if (!mounted) return;
    setState(() {
      _progress = p;
      _viewDay = 1;
      _slideIndex = 0;
    });
  }

  Future<void> _completeDay() async {
    HapticFeedback.mediumImpact();
    final p = await NovenaProgressService.instance.markCompleted(
      _novena.baseCode,
      _viewDay,
    );
    if (!mounted) return;
    setState(() => _progress = p);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('novena.completed_day'.tr())));
  }

  Future<void> _restart() async {
    // Zruš pripomienky podľa VÄČŠIEHO z počtov (uložený pri štarte vs. živý),
    // nech nezostane visieť notifikácia, ak sa počet dní medzitým zmenil.
    final storedTotal = _progress?.totalDays ?? 0;
    await NovenaProgressService.instance.reset(
      _novena.baseCode,
      storedTotal > _novena.totalDays ? storedTotal : _novena.totalDays,
    );
    if (!mounted) return;
    setState(() {
      _progress = null;
      _viewDay = 1;
      _slideIndex = 0;
    });
  }

  Future<void> _openReminderSheet() async {
    var enabled = _reminderEnabled;
    var time = _reminderTime;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HomeV2.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewPadding.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'novena.reminder'.tr(),
                style: HomeV2.serifTitle(ctx, size: 20, height: 1.2),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('novena.reminder_daily'.tr()),
                value: enabled,
                activeThumbColor: HomeV2.primary,
                onChanged: (v) => setSheet(() => enabled = v),
              ),
              if (enabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('novena.reminder_time'.tr()),
                  trailing: Text(
                    time.format(ctx),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HomeV2.primary,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time,
                    );
                    if (picked != null) setSheet(() => time = picked);
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeV2.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('save'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        _reminderEnabled = enabled;
        _reminderTime = time;
      });
      if (_progress != null) {
        final p = await NovenaProgressService.instance.setReminder(
          _novena.baseCode,
          novenaTitle: _novena.title,
          enabled: enabled,
          hour: time.hour,
          minute: time.minute,
        );
        if (mounted) setState(() => _progress = p);
      }
    }
  }

  /// Skopíruje text aktuálneho slidu (HTML → čistý text).
  Future<void> _copyCurrentSlide() async {
    final slides = _slidesFor(_viewDay);
    final slide = slides[_slideIndex.clamp(0, slides.length - 1)];
    final text = _htmlToPlain(slide.html);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HomeV2.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        duration: const Duration(seconds: 2),
        content: Text('copied_to_clipboard'.tr()),
      ),
    );
  }

  String _htmlToPlain(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── Audio ───────────────────────────────────────────────────────────────────

  Future<void> _toggleAudio(String url) async {
    HapticFeedback.lightImpact();
    try {
      if (_loadedUrl != url) {
        setState(() => _audioLoading = true);
        await _player.stop();
        // just_audio_background vyžaduje MediaItem tag na každom zdroji.
        await _player.setAudioSource(
          // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
          LockCachingAudioSource(
            Uri.parse(url),
            tag: MediaItem(
              id: url,
              album: 'novena.title'.tr(),
              title: _novena.title,
            ),
          ),
        );
        _loadedUrl = url;
        if (mounted) setState(() => _audioLoading = false);
        await _player.play();
      } else if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _stopAudio() async {
    if (_loadedUrl != null) {
      await _player.stop();
      _loadedUrl = null;
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  // ── Slidy ───────────────────────────────────────────────────────────────────

  List<_Slide> _slidesFor(int day) {
    final n = _novena;
    final d = n.days.firstWhere(
      (x) => x.dayNumber == day,
      orElse: () => n.days.first,
    );
    return [
      if (n.hasIntro)
        _Slide(
          label: 'novena.intro'.tr(),
          title: n.introTitle,
          html: n.introContent!,
          audioUrl: n.introAudioUrl,
        ),
      _Slide(
        label: 'novena.day_label'.tr(namedArgs: {'day': '$day'}),
        title: d.title,
        html: d.content,
        audioUrl: d.audioUrl,
      ),
      if (n.hasConclusion)
        _Slide(
          label: 'novena.conclusion'.tr(),
          title: n.conclusionTitle,
          html: n.conclusionContent!,
          audioUrl: n.conclusionAudioUrl,
          isConclusion: true,
        ),
    ];
  }

  void _goToDay(int day) {
    _stopAudio();
    setState(() {
      _viewDay = day;
      _slideIndex = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context)
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: HomeV2.primary),
              )
            : _progress == null
            ? _buildStartView()
            : _progress!.isFinishedFor(_novena.totalDays) &&
                  _viewDay >= _progress!.unlockedDayFor(_novena.totalDays)
            ? _buildFinishedView()
            : _buildDayView(),
      ),
    );
  }

  // ── Hero — jednotný zbaliteľný (CollapsibleHeroAppBar, vzor krížové cesty) ──

  Widget _heroSliver({String? subtitle, bool showActions = false}) {
    return CollapsibleHeroAppBar(
      collapsedTitle: _novena.title,
      imageUrl: _novena.imageUrl,
      expandedContent: HeroCenteredContent(
        title: _novena.title,
        subtitle: subtitle,
        // Bez ilustrácie dostane hero aspoň ikonu (ako adorácie/ruženec).
        icon: _novena.imageUrl == null
            ? Icons.local_fire_department_rounded
            : null,
      ),
      actions: showActions
          ? [
              IconButton(
                onPressed: _copyCurrentSlide,
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: _openReminderSheet,
                icon: Icon(
                  _reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: Colors.white,
                ),
              ),
            ]
          : const [],
    );
  }

  /// Jazykové prepínače — pod hero, na pozadí obrazovky.
  Widget _langChips() {
    if (widget.variants.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.variants.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) {
            final active = i == _variantIndex;
            return GestureDetector(
              onTap: () {
                _stopAudio();
                setState(() => _variantIndex = i);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active ? HomeV2.primary : HomeV2.card(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  widget.variants[i].langBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : HomeV2.textMuted(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 1) Pred začatím ────────────────────────────────────────────────────────

  Widget _buildStartView() {
    final n = _novena;
    return CustomScrollView(
      slivers: [
        _heroSliver(
          subtitle: 'novena.days_count'.tr(
            namedArgs: {'count': '${n.totalDays}'},
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _langChips(),
                if (n.description != null) ...[
                  Text(
                    n.description!,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Pripomienka
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: HomeV2.card(context),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'novena.reminder_daily'.tr(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'novena.reminder_hint'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                        value: _reminderEnabled,
                        activeThumbColor: HomeV2.primary,
                        onChanged: (v) => setState(() => _reminderEnabled = v),
                      ),
                      if (_reminderEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'novena.reminder_time'.tr(),
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: Text(
                            _reminderTime.format(context),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HomeV2.primary,
                            ),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime,
                            );
                            if (picked != null) {
                              setState(() => _reminderTime = picked);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    onPressed: n.totalDays > 0 ? _start : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      'novena.start'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 2) Dokončený ───────────────────────────────────────────────────────────

  Widget _buildFinishedView() {
    return CustomScrollView(
      slivers: [
        _heroSliver(subtitle: 'novena.finished_badge'.tr()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                Icon(Icons.emoji_events_rounded, size: 64, color: HomeV2.gold),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'novena.finished_title'.tr(),
                  textAlign: TextAlign.center,
                  style: HomeV2.serifTitle(context, size: 24, height: 1.2),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'novena.finished_body'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: HomeV2.textMuted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _dayChips(),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeV2.primary,
                      side: const BorderSide(color: HomeV2.primary),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text('novena.restart'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 3) Denný pohľad (slidy ako lectio) ─────────────────────────────────────

  Widget _buildDayView() {
    final p = _progress!;
    final slides = _slidesFor(_viewDay);
    final slide = slides[_slideIndex.clamp(0, slides.length - 1)];
    final isCompleted = p.completedDays.contains(_viewDay);

    return Column(
      children: [
        // Slidy — každý má vlastný zbaliteľný hero (vzor krížové cesty).
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (i) {
              _stopAudio();
              setState(() => _slideIndex = i);
            },
            itemBuilder: (_, i) => CustomScrollView(
              slivers: [
                _heroSliver(
                  subtitle: 'novena.day_of'.tr(
                    namedArgs: {
                      'day': '$_viewDay',
                      'total': '${_novena.totalDays}',
                    },
                  ),
                  showActions: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_langChips(), _dayChips()],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSlide(slides[i], isCompleted)),
              ],
            ),
          ),
        ),
        // Audio riadok
        if (slide.audioUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                _AudioButton(
                  isPlaying: _isPlaying && _loadedUrl == slide.audioUrl,
                  loading: _audioLoading,
                  onTap: () => _toggleAudio(slide.audioUrl!),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AudioProgressBar(
                    audioPlayer: _player,
                    accentColor: HomeV2.primary,
                    showDuration: false,
                    onSeek: (pos) => _player.seek(pos),
                  ),
                ),
              ],
            ),
          ),
        // Spodná navigácia slidov (ako lectio)
        _buildSlideNav(slides),
      ],
    );
  }

  Widget _dayChips() {
    final p = _progress!;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _novena.totalDays,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final day = i + 1;
          // Dni sa nezamykajú — budúce sú len tlmené (šedé), prejdené tmavé.
          final reached =
              day <= p.unlockedDayFor(_novena.totalDays) ||
              p.isFinishedFor(_novena.totalDays);
          final completed = p.completedDays.contains(day);
          final active = day == _viewDay;
          return GestureDetector(
            onTap: () => _goToDay(day),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active
                    ? HomeV2.primary
                    : completed
                    ? HomeV2.primary.withValues(alpha: 0.15)
                    : HomeV2.card(context),
                shape: BoxShape.circle,
                border: active
                    ? null
                    : Border.all(
                        color: HomeV2.primary.withValues(
                          alpha: reached ? 0.2 : 0.08,
                        ),
                      ),
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : completed
                        ? HomeV2.primary
                        : reached
                        ? HomeV2.textMuted(context)
                        : HomeV2.textMuted(context).withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlide(_Slide slide, bool dayCompleted) {
    final p = _progress!;
    final showComplete = slide.isConclusion || _slidesFor(_viewDay).length == 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slide.title != null) ...[
            Text(
              slide.title!,
              style: HomeV2.serifTitle(context, size: 20, height: 1.2),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Html(
            data: slide.html,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(17),
                lineHeight: const LineHeight(1.7),
                color: HomeV2.textDark(context),
              ),
            },
          ),
          if (showComplete && !p.isFinishedFor(_novena.totalDays)) ...[
            const SizedBox(height: AppSpacing.xl),
            dayCompleted
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'novena.completed_day'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      onPressed: _completeDay,
                      icon: const Icon(Icons.check_rounded),
                      label: Text('novena.complete_day'.tr()),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlideNav(List<_Slide> slides) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
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
                onPressed: _slideIndex > 0
                    ? () => _pageController.animateToPage(
                        _slideIndex - 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  slides[_slideIndex.clamp(0, slides.length - 1)].label,
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
                onPressed: _slideIndex < slides.length - 1
                    ? () => _pageController.animateToPage(
                        _slideIndex + 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == _slideIndex;
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
}

class _AudioButton extends StatelessWidget {
  final bool isPlaying;
  final bool loading;
  final VoidCallback onTap;
  const _AudioButton({
    required this.isPlaying,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      ),
    );
  }
}

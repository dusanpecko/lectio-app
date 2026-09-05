// lib/screens/adoration_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';

import '../models/adoration_model.dart';
import '../services/adoration_service.dart';
import '../services/media_player_bus.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_constants.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/lectio_v2/lectio_step_card.dart';
import 'lectio_reader_screen.dart';

// Detail adorácie vo v2 štýle (rovnako ako lectio_screen / krížová cesta):
//   hero adorácie → „Celé audio" karta (spojené sekcie + meditačná hudba medzi
//   nimi) → PageView kariet sekcií (každá hrá svoju stopu cez MediaPlayerBus) →
//   progress dots. Ťuknutie na text karty (alebo ikonka rozbalenia) otvorí
//   fullscreen čítačku (LectioReaderScreen).
// Prehrávanie ide výhradne cez zdieľaný MediaPlayerBus (single-source → presná
// dĺžka/seek; DB dĺžky obchádzajú chybný iOS odhad).

// Poradie sekcií = poradie v spojenom „celom audiu" (backend: úvod →
// úvodné modlitby → lectio → komentár → meditatio → oratio → contemplatio →
// actio). Biblický text je bez audia (prvá karta).
String _processAdorationContent(String content) {
  final hasBlockTags =
      RegExp(r'<(p|div|br|h[1-6]|ul|ol|li)', caseSensitive: false).hasMatch(content);
  return hasBlockTags ? content : content.replaceAll('\n', '<br>');
}

/// Jedna sekcia adorácie ako karta.
class _AdorationSection {
  final String key;
  final String title;
  final String? subtitle;
  final String html; // '' = bez textu
  final String? audioUrl;
  final double? durSec;

  const _AdorationSection({
    required this.key,
    required this.title,
    this.subtitle,
    this.html = '',
    this.audioUrl,
    this.durSec,
  });

  bool get hasHtml => html.trim().isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
}

class AdorationDetailScreen extends StatefulWidget {
  final String adorationId;
  final Adoration? initialAdoration;

  const AdorationDetailScreen({
    super.key,
    required this.adorationId,
    this.initialAdoration,
  });

  @override
  State<AdorationDetailScreen> createState() => _AdorationDetailScreenState();
}

class _AdorationDetailScreenState extends State<AdorationDetailScreen> {
  final AdorationService _service = AdorationService();

  Adoration? _adoration;
  bool _isLoading = true;
  String? _error;

  List<_AdorationSection> _sections = [];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Prefix identifikátorov média pre MediaPlayerBus (aby sme pri odchode zastavili
  // len naše audio, nie iné).
  String get _mediaPrefix => 'adoration_${widget.adorationId}';

  String? get _artUri {
    final img = _adoration?.illustrationImage;
    if (img != null && img.isNotEmpty) {
      return AudioConstants.sizedArtwork(img);
    }
    return AudioConstants.defaultArtworkUrl;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAdoration != null) {
      _adoration = widget.initialAdoration;
      _isLoading = false;
      _rebuildSections();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdoration();
  }

  @override
  void dispose() {
    // Pri odchode zastav len audio tejto adorácie.
    final bus = MediaPlayerBus.instance;
    if (bus.currentId != null && bus.currentId!.startsWith(_mediaPrefix)) {
      bus.stop();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAdoration() async {
    if (!mounted) return;
    setState(() {
      _isLoading = _adoration == null; // initialAdoration len potlačí spinner
      _error = null;
    });
    try {
      // Vždy dotiahni čerstvý detail (kvôli full_audio_url a úplným sekciám),
      // aj keď máme initialAdoration zo zoznamu.
      final detail = await _service.getAdoration(widget.adorationId);
      if (detail == null) throw Exception(tr('adoration_not_found'));
      if (mounted) {
        setState(() {
          _adoration = detail;
          _isLoading = false;
        });
        _rebuildSections();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Zostaví usporiadaný zoznam sekcií (poradie = poradie v „celom audiu").
  void _rebuildSections() {
    final a = _adoration;
    if (a == null) {
      _sections = [];
      return;
    }
    final d = a.audioDurations;
    // Biblický odkaz (súradnica) + autor sú v hero, nie ako karta.
    final raw = <_AdorationSection>[
      _AdorationSection(
        key: 'intro',
        title: tr('audio_intro'),
        html: a.introduction,
        audioUrl: a.introAudio,
        durSec: d['uvod'],
      ),
      _AdorationSection(
        key: 'introductory_prayers',
        title: tr('introductory_prayers'),
        html: a.introductoryPrayers ?? '',
        audioUrl: a.introductoryPrayersAudio,
        durSec: d['uvodne_modlitby'],
      ),
      _AdorationSection(
        key: 'lectio',
        title: 'Lectio',
        subtitle: tr('reading'),
        html: a.lectioText ?? '',
        audioUrl: a.lectioAudio,
        durSec: d['lectio'],
      ),
      _AdorationSection(
        key: 'commentary',
        title: tr('comment'),
        html: a.commentary ?? '',
        audioUrl: a.commentaryAudio,
        durSec: d['komentar'],
      ),
      _AdorationSection(
        key: 'meditatio',
        title: 'Meditatio',
        subtitle: tr('meditation'),
        html: a.meditatioText ?? '',
        audioUrl: a.meditatioAudio,
        durSec: d['meditatio'],
      ),
      _AdorationSection(
        key: 'oratio',
        title: 'Oratio',
        subtitle: tr('prayer'),
        html: a.oratioHtml ?? '',
        audioUrl: a.oratioAudio,
        durSec: d['oratio'],
      ),
      _AdorationSection(
        key: 'contemplatio',
        title: 'Contemplatio',
        subtitle: tr('contemplation'),
        html: a.contemplatioText ?? '',
        audioUrl: a.contemplatioAudio,
        durSec: d['contemplatio'],
      ),
      _AdorationSection(
        key: 'actio',
        title: 'Actio',
        subtitle: tr('action'),
        html: a.actioText ?? '',
        audioUrl: a.actioAudio,
        durSec: d['actio'],
      ),
    ];
    // Karta má zmysel len ak má text alebo audio.
    _sections = raw.where((s) => s.hasHtml || s.hasAudio).toList();
  }

  // Fullscreen čítačka sekcií (rovnaká ako Lectio/krížová cesta). Zdieľa stepKey
  // s kartami, takže prehrávanie plynulo nadväzuje.
  void _openReader(int index) {
    if (_sections.isEmpty) return;

    final steps = <LectioReaderStep>[];
    for (var i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      if (!s.hasHtml) continue; // preskoč karty bez textu
      steps.add(
        LectioReaderStep(
          stepKey: '${_mediaPrefix}_$i',
          title: s.title,
          text: _processAdorationContent(s.html),
          reference: s.subtitle,
          audioUrl: s.hasAudio ? s.audioUrl : null,
          analyticsId: widget.adorationId,
          language: _adoration?.lang,
          isHtml: true,
          contentType: 'adoration',
          artUri: _artUri,
        ),
      );
    }
    if (steps.isEmpty) return;

    // Index v čítačke = index v odfiltrovanom zozname (bez kariet bez textu).
    final readerIndex =
        _sections.take(index + 1).where((s) => s.hasHtml).length - 1;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LectioReaderScreen(
          steps: steps,
          initialIndex: readerIndex.clamp(0, steps.length - 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: _isLoading
          ? _buildLoading()
          : (_error != null || _adoration == null)
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final a = _adoration!;
    final safe = _sections.isEmpty ? 0 : _currentPage.clamp(0, _sections.length - 1);

    return Column(
      children: [
        _AdorationHero(adoration: a),
        if (a.fullAudioUrl != null && a.fullAudioUrl!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _FullAudioCard(
            mediaId: '${_mediaPrefix}_full',
            url: a.fullAudioUrl!,
            title: a.title,
            durationSeconds: a.fullAudioDuration,
            artUri: _artUri,
            contentId: widget.adorationId,
            language: a.lang,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: _sections.isEmpty
              ? Center(child: Text(tr('adoration_not_found'),
                  style: TextStyle(color: HomeV2.textMuted(context))))
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _sections.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _AdorationCard(
                    section: _sections[i],
                    mediaId: '${_mediaPrefix}_$i',
                    contentId: widget.adorationId,
                    language: a.lang,
                    artUri: _artUri,
                    onExpand: () => _openReader(i),
                  ),
                ),
        ),
        if (_sections.length > 1) _buildProgress(_sections.length, safe),
      ],
    );
  }

  Widget _buildProgress(int count, int current) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? HomeV2.primary : HomeV2.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(HomeV2.primary),
            strokeWidth: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(tr('loading_adoration'),
              style: TextStyle(color: HomeV2.textMuted(context))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const Spacer(),
            Icon(Icons.error_outline_rounded, size: 48, color: HomeV2.textMuted(context)),
            const SizedBox(height: AppSpacing.md),
            Text(tr('adoration_not_found'),
                textAlign: TextAlign.center,
                style: TextStyle(color: HomeV2.textMuted(context))),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// ── Hero adorácie ────────────────────────────────────────────────────────────
class _AdorationHero extends StatelessWidget {
  final Adoration adoration;
  const _AdorationHero({required this.adoration});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final img = adoration.hasImage ? adoration.illustrationImage : null;

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: img != null
                ? Image.network(img,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => _HeroFallback())
                : _HeroFallback(),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: 0.45), Colors.transparent, bg.withValues(alpha: 0.7), bg],
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  adoration.title,
                  style: HomeV2.serifTitle(context, size: 20, color: HomeV2.textDark(context), height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (adoration.biblicalText.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    adoration.biblicalText,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: HomeV2.iconAccent(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (adoration.author != null && adoration.author!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    adoration.author!,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeV2.textMuted(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeV2.primary, HomeV2.primary.withValues(alpha: 0.65)],
        ),
      ),
      child: Center(
        child: Icon(Icons.favorite_rounded,
            size: 64, color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }
}

// ── Karta sekcie (accent podnadpis + názov + play + text) ────────────────────
class _AdorationCard extends StatelessWidget {
  final _AdorationSection section;
  final String mediaId;
  final String contentId;
  final String language;
  final String? artUri;
  final VoidCallback? onExpand;

  const _AdorationCard({
    required this.section,
    required this.mediaId,
    required this.contentId,
    required this.language,
    this.artUri,
    this.onExpand,
  });

  String _fmt(double s) {
    final d = Duration(seconds: s.round());
    final m = d.inMinutes;
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final processed = _processAdorationContent(section.html);
    final canExpand = onExpand != null && section.hasHtml;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (section.subtitle != null && section.subtitle!.isNotEmpty)
                        Text(section.subtitle!.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                letterSpacing: 1.1, color: HomeV2.iconAccent(context))),
                      const SizedBox(height: 2),
                      Text(section.title,
                          style: HomeV2.serifTitle(context, size: 20, color: HomeV2.primary)),
                      if (section.durSec != null && section.durSec! > 0) ...[
                        const SizedBox(height: 2),
                        Text(_fmt(section.durSec!),
                            style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context))),
                      ],
                    ],
                  ),
                ),
                if (canExpand) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ExpandButton(onTap: onExpand!),
                ],
                if (section.hasAudio) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StepPlayButton(
                    stepKey: mediaId,
                    url: section.audioUrl!,
                    title: section.title,
                    analyticsId: contentId,
                    language: language,
                    contentType: 'adoration',
                    artUri: artUri,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: section.hasHtml
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canExpand ? onExpand : null,
                      child: Html(
                        data: processed,
                        style: {
                          // Typografia musí byť aj na `body`, nielen na `p`:
                          // časť textov v DB je uložená BEZ `<p>` tagov (napr.
                          // 9 zo 60 úvodov ruženca), tie by inak vypadli na
                          // predvolený štýl a v tej istej pobožnosti by sa
                          // striedali dve rôzne písma.
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            lineHeight: const LineHeight(1.6),
                            color: theme.colorScheme.onSurface,
                            fontSize: FontSize(theme.textTheme.bodyLarge?.fontSize ?? 16),
                            fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                            textAlign: TextAlign.justify,
                          ),
                          "p": Style(
                            lineHeight: const LineHeight(1.6),
                            color: theme.colorScheme.onSurface,
                            fontSize: FontSize(theme.textTheme.bodyLarge?.fontSize ?? 16),
                            fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                            margin: Margins.only(top: 0, bottom: 12),
                            textAlign: TextAlign.justify,
                          ),
                          "hr": Style(
                            margin: Margins.only(top: 8, bottom: 8),
                            border: const Border(bottom: BorderSide(color: Colors.grey, width: 1)),
                          ),
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── „Celé audio" karta (spojený súbor cez MediaPlayerBus) ────────────────────
class _FullAudioCard extends StatelessWidget {
  final String mediaId;
  final String url;
  final String title;
  final double? durationSeconds;
  final String? artUri;
  final String contentId;
  final String language;

  const _FullAudioCard({
    required this.mediaId,
    required this.url,
    required this.title,
    required this.durationSeconds,
    required this.contentId,
    required this.language,
    this.artUri,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bus = MediaPlayerBus.instance;
    final accent = HomeV2.primary;
    final dbTotal = (durationSeconds != null && durationSeconds! > 0)
        ? Duration(milliseconds: (durationSeconds! * 1000).round())
        : null;

    void toggle() => bus.toggle(
          id: mediaId,
          url: url,
          title: '${tr('full_audio')} — $title',
          artUri: artUri,
          contentType: 'adoration',
          contentId: contentId,
          language: language,
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: ListenableBuilder(
        listenable: bus,
        builder: (context, _) {
          final isCurrent = bus.isCurrent(mediaId);
          return StreamBuilder<PlayerState>(
            stream: bus.playerStateStream,
            initialData: bus.playerState,
            builder: (context, stSnap) {
              final st = stSnap.data;
              final isCompleted = isCurrent && st?.processingState == ProcessingState.completed;
              final isPlaying = isCurrent && (st?.playing ?? false) && !isCompleted;
              return StreamBuilder<Duration>(
                stream: bus.positionStream,
                initialData: bus.position,
                builder: (context, posSnap) {
                  final pos = isCurrent ? (posSnap.data ?? Duration.zero) : Duration.zero;
                  final total = dbTotal ?? (isCurrent ? bus.duration : null) ?? Duration.zero;
                  final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                  final value = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
                  return Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.headphones_rounded, size: 18, color: accent),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(tr('full_audio'),
                                style: TextStyle(fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
                          ),
                          GestureDetector(
                            onTap: toggle,
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                              child: Icon(
                                isCompleted ? Icons.replay_rounded : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                color: Colors.white, size: 26,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: accent,
                          inactiveTrackColor: accent.withValues(alpha: 0.2),
                          thumbColor: accent,
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: maxMs,
                          onChanged: isCurrent ? (v) => bus.seek(Duration(milliseconds: v.round())) : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(pos), style: TextStyle(fontSize: 11, color: HomeV2.textMuted(context))),
                            Text(_fmt(total), style: TextStyle(fontSize: 11, color: HomeV2.textMuted(context))),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Okrúhle tlačidlo (späť) ──────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// lib/screens/stations_of_cross_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';

import '../models/stations_of_cross_model.dart';
import '../services/stations_of_cross_service.dart';
import '../services/media_player_bus.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_constants.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/lectio_v2/lectio_step_card.dart';
import 'lectio_reader_screen.dart';

// Detail krížovej cesty vo v2 štýle (ako lectio_screen):
//   hero krížovej cesty → „Celé audio" karta (spojené audio) → PageView kariet
//   zastavení (každá hrá svoju stopu cez MediaPlayerBus) → progress dots.
// Ťuknutie na text karty (alebo ikonka rozbalenia) otvorí fullscreen čítačku
// (LectioReaderScreen) — rovnako ako v lectio_screen.
// Prehrávanie ide výhradne cez zdieľaný MediaPlayerBus (single-source → presná
// dĺžka/seek; DB `audio_duration` obchádza chybný iOS odhad).

const String _kStationHeroFallback = 'assets/images/station_cross_backround.webp';

// HTML obsah zastavenia pripravený na render (holý text → <br>). Zdieľané kartou
// aj fullscreen čítačkou, aby vyzerali rovnako.
String _processStationContent(String content) {
  final hasBlockTags =
      RegExp(r'<(p|div|br|h[1-6]|ul|ol|li)', caseSensitive: false).hasMatch(content);
  return hasBlockTags ? content : content.replaceAll('\n', '<br>');
}

class StationsOfCrossDetailScreen extends StatefulWidget {
  final String stationsOfCrossId;
  final StationsOfCross? initialData;

  const StationsOfCrossDetailScreen({
    super.key,
    required this.stationsOfCrossId,
    this.initialData,
  });

  @override
  State<StationsOfCrossDetailScreen> createState() =>
      _StationsOfCrossDetailScreenState();
}

class _StationsOfCrossDetailScreenState
    extends State<StationsOfCrossDetailScreen> {
  final StationsOfCrossService _service = StationsOfCrossService();

  StationsOfCross? _data;
  bool _isLoading = true;
  String? _error;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Prefix identifikátorov média pre MediaPlayerBus (aby sme pri odchode zastavili
  // len naše audio, nie iné).
  String get _mediaPrefix => 'stations_${widget.stationsOfCrossId}';

  String? get _artUri {
    final img = _data?.illustrationImage;
    if (img != null && img.isNotEmpty) {
      return AudioConstants.sizedArtwork(img);
    }
    return AudioConstants.defaultArtworkUrl;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDetail();
  }

  @override
  void dispose() {
    // Pri odchode zastav len audio tejto krížovej cesty.
    final bus = MediaPlayerBus.instance;
    if (bus.currentId != null && bus.currentId!.startsWith(_mediaPrefix)) {
      bus.stop();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = _data == null;
      _error = null;
    });
    try {
      final detail = await _service.getStationsOfCrossDetail(widget.stationsOfCrossId);
      if (detail == null) throw Exception(tr('stations_not_found'));
      if (mounted) {
        setState(() {
          _data = detail;
          _isLoading = false;
        });
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

  String _stationLabel(Station s) {
    if (s.isIntro) return tr('station_intro');
    if (s.isConclusion) return tr('station_conclusion');
    return s.title.isNotEmpty ? s.title : '${tr('station_number')} ${s.romanNumeral}';
  }

  // Fullscreen čítačka zastavení (rovnaká ako Lectio). Zdieľa stepKey s kartami,
  // takže prehrávanie plynulo nadväzuje. Prelistovanie v čítačke posunie aj
  // malý PageView na pozadí.
  void _openReader(int index) {
    final data = _data;
    if (data == null || data.stations.isEmpty) return;

    final steps = <LectioReaderStep>[];
    for (var i = 0; i < data.stations.length; i++) {
      final s = data.stations[i];
      if (!s.hasText) continue; // preskoč prázdne zastavenia
      steps.add(
        LectioReaderStep(
          stepKey: '${_mediaPrefix}_$i',
          title: _stationLabel(s),
          text: _processStationContent(s.content),
          reference: (s.isStation && s.romanNumeral.isNotEmpty) ? s.romanNumeral : null,
          audioUrl: s.hasAudio ? s.audio : null,
          analyticsId: widget.stationsOfCrossId,
          language: data.lang,
          isHtml: true,
          contentType: 'stations_of_cross',
          artUri: _artUri,
        ),
      );
    }
    if (steps.isEmpty) return;

    // Index v čítačke = index v odfiltrovanom zozname (bez prázdnych).
    final readerIndex = data.stations
        .take(index + 1)
        .where((s) => s.hasText)
        .length -
        1;

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
          : (_error != null || _data == null)
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data!;
    final stations = data.stations;
    final safe = stations.isEmpty ? 0 : _currentPage.clamp(0, stations.length - 1);

    return Column(
      children: [
        _StationsHero(
          data: data,
          station: stations.isNotEmpty ? stations[safe] : null,
          stationLabel: stations.isNotEmpty ? _stationLabel(stations[safe]) : null,
        ),
        if (data.fullAudioUrl != null && data.fullAudioUrl!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _FullAudioCard(
            mediaId: '${_mediaPrefix}_full',
            url: data.fullAudioUrl!,
            title: data.title,
            durationSeconds: data.fullAudioDuration,
            artUri: _artUri,
            contentId: widget.stationsOfCrossId,
            language: data.lang,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: stations.isEmpty
              ? Center(child: Text(tr('stations_not_found'),
                  style: TextStyle(color: HomeV2.textMuted(context))))
              : PageView.builder(
                  controller: _pageController,
                  itemCount: stations.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _StationCard(
                    station: stations[i],
                    label: _stationLabel(stations[i]),
                    mediaId: '${_mediaPrefix}_$i',
                    contentId: widget.stationsOfCrossId,
                    language: data.lang,
                    artUri: _artUri,
                    onExpand: () => _openReader(i),
                  ),
                ),
        ),
        if (stations.length > 1) _buildProgress(stations.length, safe),
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
          Text(tr('stations_of_cross_loading_detail'),
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
            Text(tr('stations_not_found'),
                textAlign: TextAlign.center,
                style: TextStyle(color: HomeV2.textMuted(context))),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// ── Hero krížovej cesty — obrázok AKTUÁLNEHO zastavenia (mení sa pri swipe) ───
class _StationsHero extends StatelessWidget {
  final StationsOfCross data;
  final Station? station;
  final String? stationLabel;
  const _StationsHero({required this.data, this.station, this.stationLabel});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    // Obrázok aktuálneho zastavenia; fallback na ilustráciu krížovej cesty, potom asset.
    final img = (station?.hasImage ?? false)
        ? station!.image
        : (data.hasImage ? data.illustrationImage : null);

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              // Default layoutBuilder používa Stack(StackFit.loose) → obrázok
              // nevyplní box (iný orez ako v adorácii). Expand = tesné rozmery,
              // takže cover+topCenter vyplní hero presne ako ostatné pobožnosti.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: img != null
                  ? Image.network(img,
                      key: ValueKey(img),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => Image.asset(_kStationHeroFallback, fit: BoxFit.cover, alignment: Alignment.topCenter))
                  : Image.asset(_kStationHeroFallback, key: const ValueKey('fallback'), fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
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
          // Názov krížovej cesty + aktuálne zastavenie
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: HomeV2.serifTitle(context, size: 20, color: HomeV2.textDark(context), height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stationLabel != null && stationLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stationLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

// ── Karta zastavenia (obrázok + label + play + text) ─────────────────────────
class _StationCard extends StatelessWidget {
  final Station station;
  final String label;
  final String mediaId;
  final String contentId;
  final String language;
  final String? artUri;
  final VoidCallback? onExpand;

  const _StationCard({
    required this.station,
    required this.label,
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
    final processed = _processStationContent(station.content);
    // Rozbaliť na celé okno vieme len keď je čo čítať.
    final canExpand = onExpand != null && station.hasText;

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
                      if (station.isStation && station.romanNumeral.isNotEmpty)
                        Text(station.romanNumeral,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                letterSpacing: 1.1, color: HomeV2.iconAccent(context))),
                      const SizedBox(height: 2),
                      Text(label,
                          style: HomeV2.serifTitle(context, size: 20, color: HomeV2.primary)),
                      if (station.audioDuration != null && station.audioDuration! > 0) ...[
                        const SizedBox(height: 2),
                        Text(_fmt(station.audioDuration!),
                            style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context))),
                      ],
                    ],
                  ),
                ),
                if (canExpand) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ExpandButton(onTap: onExpand!),
                ],
                if (station.hasAudio) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StepPlayButton(
                    stepKey: mediaId,
                    url: station.audio!,
                    title: label,
                    analyticsId: contentId,
                    language: language,
                    contentType: 'stations_of_cross',
                    artUri: artUri,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              // Ťuknutie na text otvorí fullscreen čítačku (ako v lectio).
              child: station.hasText
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
    // DB dĺžka má prednosť pred (nepresným) odhadom prehrávača.
    final dbTotal = (durationSeconds != null && durationSeconds! > 0)
        ? Duration(milliseconds: (durationSeconds! * 1000).round())
        : null;

    void toggle() => bus.toggle(
          id: mediaId,
          url: url,
          title: '${tr('stations_full_audio')} — $title',
          artUri: artUri,
          contentType: 'stations_of_cross',
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
                            child: Text(tr('stations_full_audio'),
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

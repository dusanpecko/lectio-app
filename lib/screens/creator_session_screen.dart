import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';

import '../models/creator.dart';
import '../services/audio_exclusive.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_player_factory.dart';
import '../widgets/audio/audio_progress_bar.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/video/in_app_video.dart';

/// Časť série tvorcu — vykreslí médiá v poradí (text/obrázok/audio/video).
/// Audio aj video hrajú priamo v appke (video cez [InAppVideo]: YouTube/Vimeo
/// oficiálnym embedom, priame súbory cez video_player).
class CreatorSessionScreen extends StatefulWidget {
  const CreatorSessionScreen({
    super.key,
    required this.session,
    required this.accent,
    required this.programId,
  });
  final CreatorSession session;
  final Color accent;
  final String programId; // pre event tracking (play/complete)

  @override
  State<CreatorSessionScreen> createState() => _CreatorSessionScreenState();
}

class _CreatorSessionScreenState extends State<CreatorSessionScreen> {
  final AudioPlayer _player = createAppAudioPlayer();
  String? _playingUrl;
  StreamSubscription<PlayerState>? _stateSub;
  bool _completeFired = false; // aby sa 'complete' poslal raz na prehratie

  @override
  void initState() {
    super.initState();
    // Event 'complete' keď dohrá aktuálne audio (creator štatistiky).
    _stateSub = _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && !_completeFired) {
        _completeFired = true;
        CreatorsService.instance.track(
          programId: widget.programId,
          sessionId: widget.session.id,
          action: 'complete',
          secondsListened: (_player.duration ?? _player.position).inSeconds,
        );
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    AudioExclusive.release(_player);
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String url, String title) async {
    if (url.isEmpty) return;
    try {
      if (_playingUrl == url) {
        _player.playing ? await _player.pause() : await _player.play();
        return;
      }
      await AudioExclusive.acquire(_player);
      await _player.setAudioSource(
        // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
        LockCachingAudioSource(
          Uri.parse(url),
          tag: MediaItem(id: url, album: widget.session.title, title: title),
        ),
      );
      if (!mounted) return;
      setState(() => _playingUrl = url);
      _completeFired = false;
      await _player.play();
      // Event 'play' pri štarte novej stopy (creator štatistiky).
      CreatorsService.instance.track(
        programId: widget.programId,
        sessionId: widget.session.id,
        action: 'play',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.session.media;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _hero(),
            Expanded(
              child: StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  // Susedné slidy tvoria jeden swipovateľný blok — inak by sa
                  // z rozjímania po krokoch stal obyčajný zoznam kariet.
                  final blocks = _groupMedia(media);
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    itemCount: blocks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
                    itemBuilder: (_, i) {
                      final b = blocks[i];
                      if (b.length > 1 || (b.length == 1 && b.first.isSlide)) {
                        return _SlideDeck(slides: b, accent: widget.accent);
                      }
                      return _mediaWidget(context, b.first, playing);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero časti (v2 vzor: obrázok + gradient do pozadia, „Časť N" + názov) ───
  Widget _hero() {
    final s = widget.session;
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final img = (s.imageUrl != null && s.imageUrl!.isNotEmpty) ? s.imageUrl : null;

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: img != null
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, _) => _heroFallback(),
                    errorWidget: (_, _, _) => _heroFallback(),
                  )
                : _heroFallback(),
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
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
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
                Row(
                  children: [
                    Text(
                      tr('creator_part_number', namedArgs: {'n': '${s.order}'}).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: widget.accent,
                      ),
                    ),
                    if (s.durationMinutes != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('· ${s.durationMinutes} min',
                          style: TextStyle(fontSize: 11, color: HomeV2.textMuted(context))),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  s.title,
                  style: HomeV2.serifTitle(context, size: 22, color: HomeV2.textDark(context), height: 1.1),
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

  Widget _heroFallback() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.accent, widget.accent.withValues(alpha: 0.65)],
          ),
        ),
      );

  /// Zoskupí po sebe idúce slidy; ostatné médiá ostávajú samostatne.
  List<List<CreatorMedia>> _groupMedia(List<CreatorMedia> media) {
    final out = <List<CreatorMedia>>[];
    for (final m in media) {
      if (m.isSlide && out.isNotEmpty && out.last.first.isSlide) {
        out.last.add(m);
      } else {
        out.add([m]);
      }
    }
    return out;
  }

  /// HTML blok v jednotnom štýle. `serif`/`italic` odlišujú citát Písma
  /// a modlitbu od bežného výkladu.
  Widget _prose(BuildContext context, String html, {bool serif = false, bool italic = false, TextAlign? align}) =>
      Html(
        data: html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.7),
            color: HomeV2.textDark(context),
            fontFamily: serif ? 'Georgia' : null,
            fontStyle: italic ? FontStyle.italic : null,
            textAlign: align,
          ),
        },
      );

  /// Nadpis bloku. Word v režime „bloky" ukladá medzinadpisy práve sem —
  /// bez tohto by sa v appke stratili.
  Widget _blockTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
      );

  /// Text, Písmo, otázka a modlitba — rovnaký obsah, iné čítanie.
  /// Preto sa líšia rámom a typografiou, nie len odsadením.
  Widget _proseBlock(BuildContext context, CreatorMedia m, String content) {
    final accent = widget.accent;
    switch (m.type) {
      // Citát Písma: pruh v akcentnej farbe vľavo, serif kurzíva,
      // referencia pod textom ako v liturgických knihách.
      case 'bible':
        return Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          decoration: BoxDecoration(
            color: HomeV2.card(context),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _prose(context, content, serif: true, italic: true),
              if (m.sourceRef != null && m.sourceRef!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  m.sourceRef!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: accent,
                  ),
                ),
              ],
            ],
          ),
        );

      // Otázka na zamyslenie: podfarbená, aby sa nedala prečítať mimochodom.
      case 'question':
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: _prose(context, content),
        );

      // Modlitba: centrovaná, serif — text sa modlí, nečíta.
      case 'prayer':
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: HomeV2.card(context),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
          ),
          child: _prose(context, content, serif: true, align: TextAlign.center),
        );

      default:
        return _prose(context, content);
    }
  }

  Widget _mediaWidget(BuildContext context, CreatorMedia m, bool playing) {
    final content = m.content ?? '';
    final title = m.title;
    final hasTitle = title != null && title.isNotEmpty;

    // Nadpis nesú textové bloky aj obrázok. Audio a video si ho riešia samy —
    // audio ho používa ako názov stopy, video ho vykresľuje v prehrávači.
    if (m.isProse || m.type == 'image') {
      final body = m.isProse ? _proseBlock(context, m, content) : _mediaBody(context, m, content, playing);
      if (!hasTitle) return body;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_blockTitle(context, title), body],
      );
    }
    return _mediaBody(context, m, content, playing);
  }

  /// Médiá s URL (obrázok, audio, video) — nadpis rieši volajúci.
  Widget _mediaBody(BuildContext context, CreatorMedia m, String content, bool playing) {

    switch (m.type) {
      case 'image':
        // Na celú šírku a proporčnú výšku — `BoxFit.cover` bez rozmerov
        // nechával menšie obrázky v pôvodnej veľkosti a väčšie orezával.
        // Na webe je to `w-full h-auto`, tu `fitWidth`.
        return content.isEmpty
            ? const SizedBox.shrink()
            : ClipRRect(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: content,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
              );
      case 'audio':
        return _AudioTile(
          title: (m.title == null || m.title!.isEmpty) ? widget.session.title : m.title!,
          accent: widget.accent,
          isCurrent: _playingUrl == content,
          isPlaying: playing && _playingUrl == content,
          player: _player,
          onToggle: () => _toggleAudio(content, m.title ?? widget.session.title),
        );
      case 'video':
        return content.isEmpty
            ? const SizedBox.shrink()
            : InAppVideo(
                url: content,
                accent: widget.accent,
                title: (m.title == null || m.title!.isEmpty) ? null : m.title,
              );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.title, required this.accent, required this.isCurrent,
    required this.isPlaying, required this.player, required this.onToggle,
  });
  final String title;
  final Color accent;
  final bool isCurrent;
  final bool isPlaying;
  final AudioPlayer player;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeV2.textDark(context)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (isCurrent) ...[
            const SizedBox(height: AppSpacing.sm),
            AudioProgressBar(audioPlayer: player, accentColor: accent),
          ],
        ],
      ),
    );
  }
}

/// Blok slidov — karta s obrázkom a krátkym textom, listuje sa prstom.
///
/// Zámerne pevná výška a swipe (nie zoznam pod sebou): slide je určený na
/// rozjímanie po krokoch, tak ako sekcie adorácie či zastavenia krížovej cesty.
class _SlideDeck extends StatefulWidget {
  const _SlideDeck({required this.slides, required this.accent});
  final List<CreatorMedia> slides;
  final Color accent;

  @override
  State<_SlideDeck> createState() => _SlideDeckState();
}

class _SlideDeckState extends State<_SlideDeck> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.slides.length > 1;
    // Výšku určuje tvar slidu (tvorca ho volí): na výšku pre telefón,
    // na šírku pre katechézu s projektorom. Berieme prvý slide v bloku —
    // miešať tvary v jednom swipe by pôsobilo rozbito.
    final aspect = widget.slides.first.slideAspect;
    final w = MediaQuery.of(context).size.width - AppSpacing.lg * 2;
    final raw = w / aspect;
    // Strop, aby karta na výšku nezabrala celú obrazovku.
    final h = aspect < 1 ? raw.clamp(320.0, 560.0) : raw;

    return Column(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideCard(slide: widget.slides[i], accent: widget.accent),
          ),
        ),
        if (multi) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.slides.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? widget.accent : widget.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, required this.accent});
  final CreatorMedia slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final img = slide.imageUrl;
    final text = slide.content ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img != null && img.isNotEmpty)
            CachedNetworkImage(
              imageUrl: img,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: accent.withValues(alpha: 0.25)),
              errorWidget: (_, _, _) => _fallback(),
            )
          else
            _fallback(),

          // Gradient pre čitateľnosť textu nad fotkou.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black26, Colors.black87],
                stops: [0.25, 0.55, 1.0],
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (slide.title != null && slide.title!.trim().isNotEmpty) ...[
                  Text(
                    slide.title!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                      color: HomeV2.goldLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (text.trim().isNotEmpty)
                  Html(
                    data: text,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        color: Colors.white,
                        fontSize: FontSize(17),
                        lineHeight: const LineHeight(1.55),
                      ),
                      'p': Style(margin: Margins.only(bottom: 8)),
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, accent.withValues(alpha: 0.6)],
          ),
        ),
      );
}

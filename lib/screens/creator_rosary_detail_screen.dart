import 'dart:async';

import 'package:audio_service/audio_service.dart';
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

// Detail ruženca tvorcu vo v2 štýle (ako adorácia / hlavná appka):
//   fixný hero → voliteľná „Celé audio" karta (súvislé počúvanie) → PageView
//   kariet sekcií (O ruženci → úvod → desiatky → záver) → progress dots.
// Ak je nahraté celé audio, hrá súvisle cez slajdy (slajdy sú len na čítanie);
// inak má každý slajd svoju čiastočnú stopu, ktorá sa pri prepnutí zastaví.
// Prehrávanie ide cez vlastný AudioPlayer (creator branding cez widget.accent).

/// HTML obsah sekcie pripravený na render (holý text → <br>).
String _processContent(String content) {
  final hasBlockTags =
      RegExp(r'<(p|div|br|h[1-6]|ul|ol|li)', caseSensitive: false).hasMatch(content);
  return hasBlockTags ? content : content.replaceAll('\n', '<br>');
}

/// Jeden slajd ruženca (info / úvod / desiatok / záver).
class _RSlide {
  final String label;
  final String? title;
  final String html;
  final String? audioUrl;
  final bool isInfo; // prvý slajd — info o ruženci (jazyk/popis)
  const _RSlide({required this.label, this.title, this.html = '', this.audioUrl, this.isInfo = false});
}

class CreatorRosaryDetailScreen extends StatefulWidget {
  const CreatorRosaryDetailScreen({super.key, required this.item, required this.accent});
  final CreatorContentItem item;
  final Color accent;

  @override
  State<CreatorRosaryDetailScreen> createState() => _CreatorRosaryDetailScreenState();
}

class _CreatorRosaryDetailScreenState extends State<CreatorRosaryDetailScreen> {
  CreatorRosaryDetail? _rosary;
  bool _loading = true;

  final AudioPlayer _player = createAppAudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _isPlaying = false;
  bool _audioLoading = false;
  String? _loadedUrl;

  final PageController _pageController = PageController();
  int _slideIndex = 0;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      if (completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      setState(() => _isPlaying = state.playing && !completed);
    });
    _load();
  }

  Future<void> _load() async {
    final data = await CreatorsService.instance.fetchRosary(widget.item.id);
    if (!mounted) return;
    setState(() {
      _rosary = data;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    AudioExclusive.release(_player);
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasFull => _rosary?.fullAudioUrl != null && _rosary!.fullAudioUrl!.isNotEmpty;

  List<_RSlide> _slides() {
    final r = _rosary;
    if (r == null) return const [];
    final out = <_RSlide>[];
    final full = _hasFull;
    // O ruženci — len ak je popis alebo jazyk (kategória/autor sú v hero).
    if ((r.description != null && r.description!.trim().isNotEmpty) ||
        (r.lang != null && r.lang!.isNotEmpty)) {
      out.add(_RSlide(label: tr('rosary_about'), isInfo: true));
    }
    if ((r.introContent != null && r.introContent!.isNotEmpty) || (!full && r.introAudioUrl != null)) {
      out.add(_RSlide(label: tr('rosary_intro'), title: r.introTitle, html: r.introContent ?? '', audioUrl: full ? null : r.introAudioUrl));
    }
    for (final d in r.decades) {
      out.add(_RSlide(label: '${tr('rosary_decade')} ${d.number}', title: d.title, html: d.content, audioUrl: full ? null : d.audioUrl));
    }
    if ((r.conclusionContent != null && r.conclusionContent!.isNotEmpty) || (!full && r.conclusionAudioUrl != null)) {
      out.add(_RSlide(label: tr('rosary_conclusion'), title: r.conclusionTitle, html: r.conclusionContent ?? '', audioUrl: full ? null : r.conclusionAudioUrl));
    }
    return out;
  }

  Future<void> _toggleAudio(String url) async {
    HapticFeedback.lightImpact();
    try {
      await AudioExclusive.acquire(_player);
      if (_loadedUrl != url) {
        setState(() => _audioLoading = true);
        await _player.stop();
        await _player.setAudioSource(
          // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
          LockCachingAudioSource(
            Uri.parse(url),
            tag: MediaItem(id: url, album: _rosary?.title ?? '', title: widget.item.title),
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _rosary == null) return _buildLoading();
    final r = _rosary;
    final slides = _slides();
    if (r == null || slides.isEmpty) return _buildError();

    final safe = _slideIndex.clamp(0, slides.length - 1);
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Column(
        children: [
          _RosaryHero(rosary: r, accent: widget.accent),
          if (_hasFull) ...[
            const SizedBox(height: AppSpacing.md),
            _fullAudioCard(r.fullAudioUrl!),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: (i) {
                // Celé audio hrá súvisle → pri swipe NEzastavujeme.
                // Čiastočné stopy sa pri prepnutí slajdu zastavia.
                if (!_hasFull) _stopAudio();
                setState(() => _slideIndex = i);
              },
              itemBuilder: (_, i) => _slideCard(slides[i]),
            ),
          ),
          if (slides.length > 1) _buildProgress(slides.length, safe),
        ],
      ),
    );
  }

  // ── „Celé audio" karta (súvislé počúvanie cez vlastný prehrávač) ────────────
  Widget _fullAudioCard(String url) {
    final playing = _isPlaying && _loadedUrl == url;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.headphones_rounded, size: 18, color: widget.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(tr('rosary_full_audio'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
              ),
              _AudioButton(
                isPlaying: playing,
                loading: _audioLoading,
                accent: widget.accent,
                onTap: () => _toggleAudio(url),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AudioProgressBar(
            audioPlayer: _player,
            accentColor: widget.accent,
            onSeek: (pos) => _player.seek(pos),
          ),
        ],
      ),
    );
  }

  // ── Karta slajdu ─────────────────────────────────────────────────────────────
  Widget _slideCard(_RSlide slide) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: slide.isInfo ? _aboutBody() : _contentBody(slide),
    );
  }

  Widget _contentBody(_RSlide slide) {
    final theme = Theme.of(context);
    final hasTitle = slide.title != null && slide.title!.isNotEmpty;
    final showAudio = !_hasFull && slide.audioUrl != null && slide.audioUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle) ...[
                Text(slide.label.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 1.1, color: widget.accent)),
                const SizedBox(height: 2),
                Text(slide.title!, style: HomeV2.serifTitle(context, size: 20, color: widget.accent)),
              ] else
                Text(slide.label, style: HomeV2.serifTitle(context, size: 20, color: widget.accent)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: slide.html.trim().isNotEmpty
                ? Html(
                    data: _processContent(slide.html),
                    style: {
                      'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                      'p': Style(
                        lineHeight: const LineHeight(1.6),
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize(theme.textTheme.bodyLarge?.fontSize ?? 16),
                        margin: Margins.only(top: 0, bottom: 12),
                        textAlign: TextAlign.justify,
                      ),
                      'hr': Style(
                        margin: Margins.only(top: 8, bottom: 8),
                        border: const Border(bottom: BorderSide(color: Colors.grey, width: 1)),
                      ),
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (showAudio)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: _audioRow(slide.audioUrl!),
          ),
      ],
    );
  }

  Widget _aboutBody() {
    final r = _rosary!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('rosary_about'), style: HomeV2.serifTitle(context, size: 20)),
          const SizedBox(height: AppSpacing.md),
          _infoRow(tr('rosary_language'), r.lang?.toUpperCase()),
          if (r.description != null && r.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: Text(r.description!,
                    style: TextStyle(fontSize: 16, height: 1.6, color: HomeV2.textDark(context))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 13, color: HomeV2.textMuted(context)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeV2.textDark(context)))),
        ],
      ),
    );
  }

  Widget _audioRow(String url) {
    return Row(
      children: [
        _AudioButton(
          isPlaying: _isPlaying && _loadedUrl == url,
          loading: _audioLoading,
          accent: widget.accent,
          onTap: () => _toggleAudio(url),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AudioProgressBar(
            audioPlayer: _player,
            accentColor: widget.accent,
            showDuration: false,
            onSeek: (pos) => _player.seek(pos),
          ),
        ),
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
            duration: HomeV2.anim,
            curve: HomeV2.curve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? widget.accent : widget.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
              ),
              const Spacer(),
              Icon(Icons.error_outline_rounded, size: 48, color: HomeV2.textMuted(context)),
              const SizedBox(height: AppSpacing.md),
              Text(tr('creator_open_failed'),
                  textAlign: TextAlign.center, style: TextStyle(color: HomeV2.textMuted(context))),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ruženca ─────────────────────────────────────────────────────────────
class _RosaryHero extends StatelessWidget {
  final CreatorRosaryDetail rosary;
  final Color accent;
  const _RosaryHero({required this.rosary, required this.accent});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final img = (rosary.imageUrl != null && rosary.imageUrl!.isNotEmpty) ? rosary.imageUrl : null;

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
                    errorBuilder: (_, _, _) => _HeroFallback(accent: accent))
                : _HeroFallback(accent: accent),
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
            child: _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
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
                  rosary.title,
                  style: HomeV2.serifTitle(context, size: 20, color: HomeV2.textDark(context), height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (rosary.categoryLabel != null && rosary.categoryLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    rosary.categoryLabel!,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (rosary.author != null && rosary.author!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rosary.author!,
                    style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
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
  final Color accent;
  const _HeroFallback({required this.accent});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.65)],
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.white.withValues(alpha: 0.35)),
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _AudioButton extends StatelessWidget {
  final bool isPlaying;
  final bool loading;
  final Color accent;
  final VoidCallback onTap;
  const _AudioButton({required this.isPlaying, required this.loading, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
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
                  child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
              : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

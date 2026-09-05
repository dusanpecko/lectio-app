import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/creator.dart';
import '../services/audio_exclusive.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../shared/audio_player_factory.dart';
import '../widgets/audio/audio_progress_bar.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// Detail podcastu tvorcu — dizajn v2 (vzor spiritual_exercise_detail):
/// 320px hero s obálkou + gradient, section karty (O podcaste / Počúvať na /
/// Epizódy). Epizódy z RSS hrajú priamo v appke.
class CreatorPodcastDetailScreen extends StatefulWidget {
  const CreatorPodcastDetailScreen({super.key, required this.podcast, required this.accent});
  final CreatorContentItem podcast;
  final Color accent;

  @override
  State<CreatorPodcastDetailScreen> createState() => _CreatorPodcastDetailScreenState();
}

class _CreatorPodcastDetailScreenState extends State<CreatorPodcastDetailScreen> {
  final AudioPlayer _player = createAppAudioPlayer();
  List<PodcastEpisodeItem> _episodes = const [];
  bool _loading = true;
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final eps = await CreatorsService.instance.fetchPodcastEpisodes(widget.podcast.id);
    if (!mounted) return;
    setState(() {
      _episodes = eps;
      _loading = false;
    });
  }

  @override
  void dispose() {
    AudioExclusive.release(_player);
    _player.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggle(PodcastEpisodeItem ep) async {
    if (ep.audioUrl.isEmpty) return;
    try {
      if (_playingUrl == ep.audioUrl) {
        _player.playing ? await _player.pause() : await _player.play();
        return;
      }
      await AudioExclusive.acquire(_player);
      final art = ep.image ?? widget.podcast.imageUrl;
      await _player.setAudioSource(
        // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
        LockCachingAudioSource(
          Uri.parse(ep.audioUrl),
          tag: MediaItem(
            id: ep.audioUrl,
            album: widget.podcast.title,
            title: ep.title,
            artUri: art != null ? Uri.tryParse(art) : null,
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _playingUrl = ep.audioUrl);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('creator_open_failed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.podcast;
    final links = <(String, IconData, Color, String?)>[
      ('Spotify', Icons.music_note_rounded, const Color(0xFF1DB954), p.spotifyUrl),
      ('Apple Podcasts', Icons.podcasts_rounded, const Color(0xFF9933CC), p.appleUrl),
      ('YouTube', Icons.play_arrow_rounded, const Color(0xFFFF0000), p.youtubeUrl),
    ].where((e) => e.$4 != null && e.$4!.isNotEmpty).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHero(p),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
                  MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.subtitle != null && p.subtitle!.isNotEmpty) ...[
                    _sectionCard(tr('podcast_about'),
                        Text(p.subtitle!, style: TextStyle(fontSize: 15, height: 1.55, color: HomeV2.textDark(context)))),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (links.isNotEmpty) ...[
                    _sectionCard(
                      tr('podcast_listen_on'),
                      Column(
                        children: [
                          for (final l in links)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _LinkButton(label: l.$1, icon: l.$2, color: l.$3, onTap: () => _open(l.$4!)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_loading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
                  else if (_episodes.isNotEmpty) ...[
                    Text(tr('podcast_episodes'), style: HomeV2.serifTitle(context, size: 19)),
                    const SizedBox(height: AppSpacing.md),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snap) {
                        final playing = snap.data?.playing ?? false;
                        return Column(
                          children: [
                            for (final ep in _episodes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _EpisodeCard(
                                  episode: ep,
                                  accent: widget.accent,
                                  isCurrent: _playingUrl == ep.audioUrl,
                                  isPlaying: playing && _playingUrl == ep.audioUrl,
                                  player: _player,
                                  onToggle: () => _toggle(ep),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero (vzor v2) ──────────────────────────────────────────────────────────
  Widget _buildHero(CreatorContentItem p) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: p.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: p.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
                    errorWidget: (_, _, _) => ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
                  )
                : ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    widget.accent.withValues(alpha: 0.7),
                    bg,
                  ],
                  stops: const [0.0, 0.3, 0.9, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(onTap: () => Navigator.of(context).maybePop(), overImage: true, accent: widget.accent),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.podcasts_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 6),
                    Text('PODCAST',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, shadows: halo)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  p.title,
                  style: HomeV2.serifTitle(context, size: 26, color: Colors.white, height: 1.15).copyWith(shadows: halo),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HomeV2.serifTitle(context, size: 19)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.accent,
    required this.isCurrent,
    required this.isPlaying,
    required this.player,
    required this.onToggle,
  });
  final PodcastEpisodeItem episode;
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(episode.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeV2.textDark(context)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (episode.duration != null && episode.duration!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(episode.duration!, style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context))),
                    ],
                  ],
                ),
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

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool overImage;
  final Color accent;
  const _CircleButton({required this.onTap, required this.overImage, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: overImage ? Colors.white.withValues(alpha: 0.22) : HomeV2.card(context).withValues(alpha: 0.92),
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
          child: Icon(Icons.arrow_back_rounded, color: overImage ? Colors.white : accent, size: 22),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/podcast_episode.dart';
import '../../services/media_player_bus.dart';
import '../../services/podcast_service.dart';
import '../../shared/app_spacing.dart';
import '../../utils/scripture_reference.dart';
import 'home_v2_tokens.dart';

/// Kompaktná karta denného podcastu (hlavný prvok, ale nedominantný).
/// Prehráva reálne MP3 cez [PodcastAudioController]; progress + časy z reálnej
/// pozície.
class DailyPodcastCard extends StatelessWidget {
  final PodcastEpisode episode;
  final VoidCallback? onSpotify;

  /// Zobraziť primárne tlačidlo „Prehrať/Pozastaviť". Na lectio je `false` —
  /// prehráva sa cez play na cover obrázku.
  final bool showPrimaryButton;

  /// Kompaktnejšia (nižšia) verzia — menší thumbnail a tesnejšie medzery.
  final bool dense;

  /// Vonkajší okraj karty. Default = bočný odstup od kraja obrazovky.
  /// Pri coach-marku sa nastaví na zero a odstup sa rieši zvonka, aby
  /// zvýraznenie sadlo presne na bielu kartu.
  final EdgeInsetsGeometry margin;

  /// Režim prehrávania „celého Lectio" audia (Nastavenia → Lectio audio):
  /// `'long'` = dlhé s hudbou (default), `'short'` = krátke bez hudby.
  /// Tlačidlo prehráva kombinovaný súbor z [PodcastEpisode.fullLongAudio] /
  /// [PodcastEpisode.fullShortAudio]; samotný podcast ostáva len na Spotify.
  /// Ak kombinovaný súbor chýba, padne späť na podcast audio.
  final String audioMode;

  const DailyPodcastCard({
    super.key,
    required this.episode,
    this.onSpotify,
    this.showPrimaryButton = true,
    this.dense = false,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.audioMode = 'long',
  });

  /// Vyberie audio, ktoré sa má v appke prehrať: preferuje zvolený kombinovaný
  /// variant (dlhé/krátke), potom druhý variant a až ako poslednú možnosť
  /// podcast audio. Vracia `(url, variant)` — variant je `'long'`/`'short'`
  /// pre kombinované audio, alebo `'podcast'` pre fallback.
  ({String url, String variant}) _resolveAudio() {
    final long = episode.fullLongAudio;
    final short = episode.fullShortAudio;
    bool ok(String? u) => u != null && u.isNotEmpty;

    if (audioMode == 'short') {
      if (ok(short)) return (url: short!, variant: 'short');
      if (ok(long)) return (url: long!, variant: 'long');
    } else {
      if (ok(long)) return (url: long!, variant: 'long');
      if (ok(short)) return (url: short!, variant: 'short');
    }
    return (url: episode.audioUrl ?? '', variant: 'podcast');
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = MediaPlayerBus.instance;
    final cover =
        episode.coverImageUrl ?? PodcastService.channelCover(episode.lang);
    final resolved = _resolveAudio();
    final usingCombined = resolved.variant != 'podcast';
    // Pri kombinovanom audiu kódujeme variant do id, aby prepnutie dlhé↔krátke
    // v bus prehrávači znovu načítalo správny súbor.
    final mediaId = usingCombined
        ? 'lectio_audio_${episode.id}_${resolved.variant}'
        : 'podcast_${episode.id}';
    void togglePlay() => controller.toggle(
      id: mediaId,
      url: resolved.url,
      title: episode.title ?? tr('daily_lectio_audio'),
      artUri: cover,
      contentType: usingCombined ? 'lectio' : 'podcast',
      contentId: episode.publishDate ?? episode.id,
      language: episode.lang,
    );

    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final isCurrent = controller.isCurrent(mediaId);
          return StreamBuilder<bool>(
            stream: controller.playingStream,
            initialData: controller.isPlaying,
            builder: (context, playSnap) {
              final isPlaying = isCurrent && (playSnap.data ?? false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overline + dĺžka vpravo
                  Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        size: 16,
                        color: HomeV2.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          tr('daily_lectio_audio').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: HomeV2.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Dĺžku z epizódy ukazujeme len pre podcast — pri
                      // kombinovanom Lectio audiu je iná (reálnu vidno v progrese).
                      if (!usingCombined && episode.durationMinutes > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: HomeV2.textMuted(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${episode.durationMinutes} ${tr('minutes_short')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: dense ? AppSpacing.sm : AppSpacing.md),

                  // Thumbnail + názov/podnadpis — celý riadok (obrázok aj názov)
                  // spúšťa prehrávanie (na home tak ide play cez obrázok aj button).
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      togglePlay();
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Thumbnail(
                          size: dense ? 52 : 64,
                          cover: cover,
                          isPlaying: isPlaying,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            togglePlay();
                          },
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                episode.displayTitle.isNotEmpty
                                    ? episode.displayTitle
                                    : tr('daily_lectio_audio'),
                                style: HomeV2.serifTitle(context, size: 18),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (episode.displaySubtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  ScriptureReference.format(
                                    episode.displaySubtitle,
                                    context.locale.languageCode,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
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
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Progress bar + časy. Pri kombinovanom audiu nemáme dopredu
                  // známu dĺžku → fallback 0 (reálnu doplní stream po spustení).
                  _ProgressBar(
                    controller: controller,
                    isCurrent: isCurrent,
                    fallbackTotal: usingCombined
                        ? Duration.zero
                        : episode.duration,
                  ),
                  // Akcie: (voliteľné) Prehrať/Pozastaviť + Spotify
                  if (showPrimaryButton || onSpotify != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (showPrimaryButton)
                          Expanded(
                            child: _PrimaryButton(
                              isPlaying: isPlaying,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                togglePlay();
                              },
                            ),
                          ),
                        if (showPrimaryButton && onSpotify != null)
                          const SizedBox(width: AppSpacing.md),
                        if (onSpotify != null)
                          _SpotifyButton(onTap: onSpotify!),
                      ],
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String cover;
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const _Thumbnail({
    required this.cover,
    required this.isPlaying,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final overlay = size * 0.56;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: cover,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: size,
                height: size,
                color: HomeV2.primary.withValues(alpha: 0.12),
              ),
              errorWidget: (_, _, _) => Container(
                width: size,
                height: size,
                color: HomeV2.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.podcasts_rounded,
                  color: HomeV2.primary,
                  size: 26,
                ),
              ),
            ),
          ),
          Container(
            width: overlay,
            height: overlay,
            decoration: BoxDecoration(
              color: HomeV2.card(context).withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: HomeV2.softShadowSm(context),
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: HomeV2.primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final MediaPlayerBus controller;
  final bool isCurrent;
  final Duration fallbackTotal;

  const _ProgressBar({
    required this.controller,
    required this.isCurrent,
    required this.fallbackTotal,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      initialData: controller.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: controller.durationStream,
          initialData: controller.duration,
          builder: (context, durSnap) {
            final total =
                (isCurrent ? durSnap.data : null) ??
                (fallbackTotal > Duration.zero ? fallbackTotal : null) ??
                const Duration(seconds: 1);
            final pos = isCurrent
                ? (posSnap.data ?? Duration.zero)
                : Duration.zero;
            final maxMs = total.inMilliseconds <= 0 ? 1 : total.inMilliseconds;
            final value = pos.inMilliseconds.clamp(0, maxMs).toDouble();

            return Column(
              children: [
                SizedBox(
                  height: 22,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      activeTrackColor: HomeV2.primary,
                      inactiveTrackColor: HomeV2.primary.withValues(
                        alpha: 0.15,
                      ),
                      thumbColor: HomeV2.primary,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: value,
                      min: 0,
                      max: maxMs.toDouble(),
                      onChanged: isCurrent
                          ? (v) => controller.seek(
                              Duration(milliseconds: v.toInt()),
                            )
                          : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtPair(pos),
                        style: TextStyle(
                          fontSize: 11,
                          color: HomeV2.textMuted(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _fmtPair(total),
                        style: TextStyle(
                          fontSize: 11,
                          color: HomeV2.textMuted(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmtPair(Duration d) => DailyPodcastCard._fmt(d);
}

class _PrimaryButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PrimaryButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(isPlaying ? tr('pause') : tr('play')),
      style: ElevatedButton.styleFrom(
        backgroundColor: HomeV2.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );
  }
}

class _SpotifyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SpotifyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('listen_on_spotify'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: HomeV2.spotify,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

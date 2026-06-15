import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/media_player_bus.dart';
import '../../shared/app_spacing.dart';
import '../home_v2/home_v2_tokens.dart';

/// Karta jedného kroku Lectio (Biblia/Lectio/Meditatio/…) — nadpis, voliteľná
/// referencia, text a vpravo play/pause s kruhovým priebehom prehrávania.
class LectioStepCard extends StatelessWidget {
  /// Unikátny kľúč kroku pre prehrávač (napr. `lectio_audio`).
  final String stepKey;
  final String title;
  final String text;
  final String? reference;
  final String? audioUrl;

  /// Pre Umami audio_heartbeat — id obsahu (dátum lekcie) a jazyk.
  final String? analyticsId;
  final String? language;

  const LectioStepCard({
    super.key,
    required this.stepKey,
    required this.title,
    required this.text,
    this.reference,
    this.audioUrl,
    this.analyticsId,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixná hlavička: názov + referencia + play
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: HomeV2.iconAccent(context),
                      ),
                    ),
                    if (reference != null && reference!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reference!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (audioUrl != null && audioUrl!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                _StepPlayButton(
                  stepKey: stepKey,
                  url: audioUrl!,
                  title: title,
                  analyticsId: analyticsId,
                  language: language,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Scrollovateľný text — vyplní zvyšok slidu
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: HomeV2.textDark(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okrúhle play/pause tlačidlo s kruhovým priebehom prehrávania okolo ikony.
class _StepPlayButton extends StatelessWidget {
  final String stepKey;
  final String url;
  final String title;
  final String? analyticsId;
  final String? language;

  const _StepPlayButton({
    required this.stepKey,
    required this.url,
    required this.title,
    this.analyticsId,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    final controller = MediaPlayerBus.instance;
    final accent = HomeV2.iconAccent(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isCurrent = controller.isCurrent(stepKey);
        return StreamBuilder<bool>(
          stream: controller.playingStream,
          initialData: controller.isPlaying,
          builder: (context, playSnap) {
            final isPlaying = isCurrent && (playSnap.data ?? false);
            return StreamBuilder<Duration>(
              stream: controller.positionStream,
              initialData: controller.position,
              builder: (context, posSnap) {
                return StreamBuilder<Duration?>(
                  stream: controller.durationStream,
                  initialData: controller.duration,
                  builder: (context, durSnap) {
                    final total = isCurrent ? durSnap.data : null;
                    final pos = isCurrent
                        ? (posSnap.data ?? Duration.zero)
                        : Duration.zero;
                    final progress =
                        (total != null && total.inMilliseconds > 0)
                        ? (pos.inMilliseconds / total.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.toggle(
                          id: stepKey,
                          url: url,
                          title: title,
                          contentType: 'lectio',
                          contentId: analyticsId,
                          language: language,
                        );
                      },
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                value: isCurrent ? progress : 0.0,
                                strokeWidth: 3,
                                backgroundColor: accent.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation(accent),
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: accent,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

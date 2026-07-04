// widgets/audio/audio_progress_bar.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'audio_player_models.dart';
import '../../shared/app_spacing.dart';

/// Progress bar s plynulým seekovaním.
///
/// DÔLEŽITÉ (fix 4.7.2026): počas ťahania sa seek NEvolá pri každom pixeli
/// (`onChanged`) — to radilo do fronty desiatky network seekov a posun pôsobil
/// „zaseknuto". Ťahanie mení len lokálny stav (`_dragProgress`), reálny seek sa
/// vykoná RAZ v `onChangeEnd`. Lokálna hodnota sa drží ešte chvíľu po pustení,
/// aby palec neskočil späť, kým sa prehrávač dobuffruje na novú pozíciu.
class AudioProgressBar extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioSeekCallback? onSeek;
  final bool showDuration;
  final double height;

  const AudioProgressBar({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onSeek,
    this.showDuration = true,
    this.height = 4.0,
  });

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  /// Pozícia počas ťahania (0..1); null = neťahá sa, zobrazuj stream.
  double? _dragProgress;
  int _dragEpoch = 0;

  void _endDrag(AudioPositionData positionData, double value) {
    final newPosition = Duration(
      milliseconds: (value * positionData.duration.inMilliseconds).round(),
    );
    widget.onSeek?.call(newPosition);
    // Podrž lokálnu hodnotu, kým sa player presunie (inak palec skočí späť).
    final epoch = ++_dragEpoch;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _dragEpoch == epoch) {
        setState(() => _dragProgress = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = widget.accentColor ?? theme.colorScheme.primary;

    return StreamBuilder<AudioPositionData>(
      stream: _getPositionDataStream(),
      builder: (context, snapshot) {
        final positionData = snapshot.data ?? AudioPositionData.zero;

        return Column(
          children: [
            // Progress slider
            _buildProgressSlider(
              context,
              positionData,
              effectiveAccentColor,
              theme,
            ),

            if (widget.showDuration) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDurationLabels(context, positionData, theme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProgressSlider(
    BuildContext context,
    AudioPositionData positionData,
    Color accentColor,
    ThemeData theme,
  ) {
    final displayed = (_dragProgress ?? positionData.progress).clamp(0.0, 1.0);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.height,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: widget.height * 2,
          pressedElevation: 8,
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: widget.height * 3),
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withValues(alpha: 0.3),
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.2),
        valueIndicatorColor: accentColor,
        valueIndicatorTextStyle: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Slider(
        value: displayed,
        onChanged: widget.onSeek != null
            ? (value) => setState(() => _dragProgress = value)
            : null,
        onChangeEnd: widget.onSeek != null
            ? (value) => _endDrag(positionData, value)
            : null,
        // Zobrazuje čas pri ťahaní
        label: _formatDuration(
          Duration(
            milliseconds:
                (displayed * positionData.duration.inMilliseconds).round(),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationLabels(
    BuildContext context,
    AudioPositionData positionData,
    ThemeData theme,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDuration(positionData.position),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatDuration(positionData.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Kombinuje position a duration streams pre optimálny výkon
  Stream<AudioPositionData> _getPositionDataStream() {
    return Rx.combineLatest2<Duration, Duration?, AudioPositionData>(
      widget.audioPlayer.positionStream,
      widget.audioPlayer.durationStream,
      (position, duration) => AudioPositionData(
        position: position,
        duration: duration ?? Duration.zero,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    // Pre dlhé nahrávky zobraz aj hodiny
    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}

/// Kompaktná verzia bez duration labels
class AudioProgressBarCompact extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioSeekCallback? onSeek;
  final double height;

  const AudioProgressBarCompact({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onSeek,
    this.height = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return AudioProgressBar(
      audioPlayer: audioPlayer,
      accentColor: accentColor,
      onSeek: onSeek,
      showDuration: false,
      height: height,
    );
  }
}

/// Pokročilá verzia s dodatočnými indikátormi
class AudioProgressBarAdvanced extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioSeekCallback? onSeek;
  final bool showRemaining;
  final bool showBuffering;
  final double height;

  const AudioProgressBarAdvanced({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onSeek,
    this.showRemaining = false,
    this.showBuffering = true,
    this.height = 4.0,
  });

  @override
  State<AudioProgressBarAdvanced> createState() =>
      _AudioProgressBarAdvancedState();
}

class _AudioProgressBarAdvancedState extends State<AudioProgressBarAdvanced> {
  /// Pozícia počas ťahania (0..1); null = neťahá sa (viď komentár vyššie).
  double? _dragProgress;
  int _dragEpoch = 0;

  void _endDrag(AudioPositionData positionData, double value) {
    final newPosition = Duration(
      milliseconds: (value * positionData.duration.inMilliseconds).round(),
    );
    widget.onSeek?.call(newPosition);
    final epoch = ++_dragEpoch;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _dragEpoch == epoch) {
        setState(() => _dragProgress = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = widget.accentColor ?? theme.colorScheme.primary;

    return StreamBuilder<AudioPositionData>(
      stream: _getPositionDataStream(),
      builder: (context, snapshot) {
        final positionData = snapshot.data ?? AudioPositionData.zero;

        return Column(
          children: [
            // Buffering indicator
            if (widget.showBuffering) _buildBufferingIndicator(context, theme),

            // Progress slider
            _buildAdvancedProgressSlider(
              context,
              positionData,
              effectiveAccentColor,
              theme,
            ),

            const SizedBox(height: AppSpacing.sm),

            // Duration labels s advanced info
            _buildAdvancedDurationLabels(context, positionData, theme),
          ],
        );
      },
    );
  }

  Widget _buildBufferingIndicator(BuildContext context, ThemeData theme) {
    final theme = Theme.of(context);
    return StreamBuilder<PlayerState>(
      stream: widget.audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isBuffering =
            playerState?.processingState == ProcessingState.buffering;

        if (!isBuffering) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Načítava...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdvancedProgressSlider(
    BuildContext context,
    AudioPositionData positionData,
    Color accentColor,
    ThemeData theme,
  ) {
    final displayed = (_dragProgress ?? positionData.progress).clamp(0.0, 1.0);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.height,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: widget.height * 2.5,
          pressedElevation: 8,
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: widget.height * 4),
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withValues(alpha: 0.2),
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.1),
        valueIndicatorColor: accentColor,
        valueIndicatorTextStyle: theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      child: Slider(
        value: displayed,
        divisions: 100, // Pre smoother seeking
        onChanged: widget.onSeek != null
            ? (value) => setState(() => _dragProgress = value)
            : null,
        onChangeEnd: widget.onSeek != null
            ? (value) => _endDrag(positionData, value)
            : null,
        label: _formatDuration(
          Duration(
            milliseconds:
                (displayed * positionData.duration.inMilliseconds).round(),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedDurationLabels(
    BuildContext context,
    AudioPositionData positionData,
    ThemeData theme,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDuration(positionData.position),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.showRemaining) ...[
            Text(
              '-${_formatDuration(positionData.remaining)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          Text(
            _formatDuration(positionData.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Stream<AudioPositionData> _getPositionDataStream() {
    return Rx.combineLatest2<Duration, Duration?, AudioPositionData>(
      widget.audioPlayer.positionStream,
      widget.audioPlayer.durationStream,
      (position, duration) => AudioPositionData(
        position: position,
        duration: duration ?? Duration.zero,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}

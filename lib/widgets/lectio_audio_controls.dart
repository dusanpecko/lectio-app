import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

/// Widget pre ovládacie prvky audio playera v Lectio Divina
class LectioAudioControls extends StatelessWidget {
  const LectioAudioControls({
    super.key,
    required this.isPlaying,
    required this.currentTrackIndex,
    required this.totalTracks,
    required this.onPlay,
    required this.onPause,
    required this.onPrevious,
    required this.onNext,
    this.isSeeking = false,
    this.isProcessing = false,
  });

  final bool isPlaying;
  final int currentTrackIndex;
  final int totalTracks;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool isSeeking;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = currentTrackIndex > 0;
    final canGoNext = currentTrackIndex < totalTracks - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous track button
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 32,
          color: canGoPrevious ? AppColors.primary : Colors.grey.shade400,
          onPressed: canGoPrevious ? onPrevious : null,
          tooltip: 'a11y_skip_previous'.tr(),
        ),
        const SizedBox(width: AppSpacing.lg),

        // Play/Pause button
        _PlayPauseButton(
          isPlaying: isPlaying,
          isSeeking: isSeeking,
          isProcessing: isProcessing,
          onPlay: onPlay,
          onPause: onPause,
        ),

        const SizedBox(width: AppSpacing.lg),

        // Next track button
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 32,
          color: canGoNext ? AppColors.primary : Colors.grey.shade400,
          onPressed: canGoNext ? onNext : null,
          tooltip: 'a11y_skip_next'.tr(),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isSeeking,
    required this.isProcessing,
    required this.onPlay,
    required this.onPause,
  });

  final bool isPlaying;
  final bool isSeeking;
  final bool isProcessing;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: _buildIcon(),
        iconSize: 36,
        color: Colors.white,
        onPressed: isProcessing || isSeeking
            ? null
            : (isPlaying ? onPause : onPlay),
        tooltip: isPlaying ? 'a11y_pause'.tr() : 'a11y_play'.tr(),
      ),
    );
  }

  Widget _buildIcon() {
    if (isProcessing || isSeeking) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    return Icon(isPlaying ? Icons.pause : Icons.play_arrow);
  }
}

/// Progress bar pre audio player.
/// Fix 4.7.2026: seek sa volá RAZ pri pustení (onChangeEnd), nie pri každom
/// pixeli ťahania — inak sa radili desiatky seekov a posun pôsobil zaseknuto.
class LectioAudioProgressBar extends StatefulWidget {
  const LectioAudioProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    this.isSeeking = false,
  });

  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;
  final bool isSeeking;

  @override
  State<LectioAudioProgressBar> createState() => _LectioAudioProgressBarState();
}

class _LectioAudioProgressBarState extends State<LectioAudioProgressBar> {
  /// Sekundy počas ťahania; null = neťahá sa, zobrazuj reálnu pozíciu.
  double? _dragSeconds;
  int _dragEpoch = 0;

  Duration get currentPosition => widget.currentPosition;
  Duration get totalDuration => widget.totalDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = totalDuration.inSeconds.toDouble();
    final currentValue = _dragSeconds ?? currentPosition.inSeconds.toDouble();

    return Row(
      children: [
        Text(
          _formatDuration(currentPosition),
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: currentValue.clamp(0, maxValue > 0 ? maxValue : 1),
              max: maxValue > 0 ? maxValue : 1,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.primary.withValues(alpha: 0.2),
              onChanged: (value) {
                setState(() => _dragSeconds = value);
              },
              onChangeEnd: (value) {
                widget.onSeek(Duration(seconds: value.toInt()));
                // Podrž lokálnu hodnotu, kým sa player presunie (žiadny skok späť).
                final epoch = ++_dragEpoch;
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted && _dragEpoch == epoch) {
                    setState(() => _dragSeconds = null);
                  }
                });
              },
            ),
          ),
        ),
        Text(
          _formatDuration(totalDuration),
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Widget pre výber audio módu (bez hudby, krátka, dlhá)
class LectioAudioModeSelector extends StatelessWidget {
  const LectioAudioModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final String currentMode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meditačná hudba',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _AudioModeButton(
                  mode: 'none',
                  label: 'Bez hudby',
                  icon: Icons.music_off,
                  isSelected: currentMode == 'none',
                  onTap: () => onModeChanged('none'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _AudioModeButton(
                  mode: 'short',
                  label: 'Krátka',
                  icon: Icons.music_note,
                  isSelected: currentMode == 'short',
                  onTap: () => onModeChanged('short'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _AudioModeButton(
                  mode: 'long',
                  label: 'Dlhá',
                  icon: Icons.queue_music,
                  isSelected: currentMode == 'long',
                  onTap: () => onModeChanged('long'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioModeButton extends StatelessWidget {
  const _AudioModeButton({
    required this.mode,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String mode;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

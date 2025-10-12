// widgets/audio/audio_player_controls.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_models.dart';

class AudioPlayerControls extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioPlayerCallback? onPlay;
  final AudioPlayerCallback? onPause;
  final AudioPlayerCallback? onStop;
  final AudioSeekCallback? onSeek;
  final AudioPlayerConfig config;

  const AudioPlayerControls({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.config = const AudioPlayerConfig(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = accentColor ?? theme.colorScheme.primary;

    return StreamBuilder<PlayerState>(
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final status = playerState != null
            ? UniversalAudioStatus.fromPlayerState(playerState)
            : UniversalAudioStatus.idle;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hlavné ovládacie tlačidlá
            _buildMainControls(context, status, effectiveAccentColor, theme),

            if (config.showStopButton) ...[
              const SizedBox(height: 12),
              _buildStopButton(context, status, effectiveAccentColor, theme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMainControls(
    BuildContext context,
    UniversalAudioStatus status,
    Color accentColor,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip backward button
        if (config.showSkipButtons) ...[
          _buildSkipButton(
            context: context,
            icon: _getSkipBackwardIcon(),
            onPressed: status.canPlay || status.isPlaying
                ? () => _handleSkip(-config.skipBackwardSeconds)
                : null,
            accentColor: accentColor,
            theme: theme,
          ),
          const SizedBox(width: 20),
        ],

        // Play/Pause button
        _buildPlayPauseButton(
          context: context,
          status: status,
          accentColor: accentColor,
          theme: theme,
        ),

        // Skip forward button
        if (config.showSkipButtons) ...[
          const SizedBox(width: 20),
          _buildSkipButton(
            context: context,
            icon: _getSkipForwardIcon(),
            onPressed: status.canPlay || status.isPlaying
                ? () => _handleSkip(config.skipForwardSeconds)
                : null,
            accentColor: accentColor,
            theme: theme,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayPauseButton({
    required BuildContext context,
    required UniversalAudioStatus status,
    required Color accentColor,
    required ThemeData theme,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.1),
        border: Border.all(color: accentColor, width: 2),
      ),
      child: status.isLoading
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: CircularProgressIndicator(
                color: accentColor,
                strokeWidth: 2,
              ),
            )
          : IconButton(
              onPressed: _getPlayPauseCallback(status),
              icon: Icon(_getPlayPauseIcon(status)),
              iconSize: 28,
              color: accentColor,
            ),
    );
  }

  Widget _buildSkipButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color accentColor,
    required ThemeData theme,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed != null
            ? accentColor.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: onPressed != null
              ? accentColor.withValues(alpha: 0.3)
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 18,
        color: onPressed != null
            ? accentColor
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStopButton(
    BuildContext context,
    UniversalAudioStatus status,
    Color accentColor,
    ThemeData theme,
  ) {
    return TextButton.icon(
      onPressed: status.canStop ? onStop : null,
      icon: const Icon(Icons.stop_rounded, size: 16),
      label: const Text('Zastaviť'),
      style: TextButton.styleFrom(
        foregroundColor: status.canStop ? accentColor : Colors.grey,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  // Callback handlers
  VoidCallback? _getPlayPauseCallback(UniversalAudioStatus status) {
    if (status.isLoading) return null;

    if (status.canPause && onPause != null) {
      return onPause;
    } else if (status.canPlay && onPlay != null) {
      return onPlay;
    }

    return null;
  }

  IconData _getPlayPauseIcon(UniversalAudioStatus status) {
    switch (status) {
      case UniversalAudioStatus.playing:
        return Icons.pause_rounded;
      case UniversalAudioStatus.completed:
        return Icons.replay_rounded;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  IconData _getSkipBackwardIcon() {
    return config.skipBackwardSeconds <= 10
        ? Icons.replay_10_rounded
        : config.skipBackwardSeconds <= 15
        ? Icons.replay_rounded
        : Icons.fast_rewind_rounded;
  }

  IconData _getSkipForwardIcon() {
    return config.skipForwardSeconds <= 30
        ? Icons.forward_30_rounded
        : config.skipForwardSeconds <= 60
        ? Icons.forward_rounded
        : Icons.fast_forward_rounded;
  }

  void _handleSkip(int seconds) {
    if (onSeek == null) return;

    final currentPosition = audioPlayer.position;
    final maxDuration = audioPlayer.duration ?? Duration.zero;

    final newPosition = Duration(
      seconds: (currentPosition.inSeconds + seconds).clamp(
        0,
        maxDuration.inSeconds,
      ),
    );

    onSeek!(newPosition);
  }
}

/// Kompaktná verzia controls bez skip buttonov
class AudioPlayerControlsCompact extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioPlayerCallback? onPlay;
  final AudioPlayerCallback? onPause;
  final AudioPlayerCallback? onStop;

  const AudioPlayerControlsCompact({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onPlay,
    this.onPause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AudioPlayerControls(
      audioPlayer: audioPlayer,
      accentColor: accentColor,
      onPlay: onPlay,
      onPause: onPause,
      onStop: onStop,
      config: const AudioPlayerConfig(
        showSkipButtons: false,
        showStopButton: false,
      ),
    );
  }
}

/// Rozšírená verzia s dodatočnými ovládacími prvkami
class AudioPlayerControlsAdvanced extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioPlayerCallback? onPlay;
  final AudioPlayerCallback? onPause;
  final AudioPlayerCallback? onStop;
  final AudioSeekCallback? onSeek;
  final AudioPlayerConfig config;
  final bool showPlaybackSpeed;
  final bool showVolumeControl;

  const AudioPlayerControlsAdvanced({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.config = const AudioPlayerConfig(),
    this.showPlaybackSpeed = false,
    this.showVolumeControl = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = accentColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        // Základné controls
        AudioPlayerControls(
          audioPlayer: audioPlayer,
          accentColor: accentColor,
          onPlay: onPlay,
          onPause: onPause,
          onStop: onStop,
          onSeek: onSeek,
          config: config,
        ),

        // Rozšírené ovládanie
        if (showPlaybackSpeed || showVolumeControl) ...[
          const SizedBox(height: 16),
          _buildAdvancedControls(context, effectiveAccentColor, theme),
        ],
      ],
    );
  }

  Widget _buildAdvancedControls(
    BuildContext context,
    Color accentColor,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (showPlaybackSpeed) _buildSpeedControl(context, accentColor, theme),
        if (showVolumeControl) _buildVolumeControl(context, accentColor, theme),
      ],
    );
  }

  Widget _buildSpeedControl(
    BuildContext context,
    Color accentColor,
    ThemeData theme,
  ) {
    return StreamBuilder<double>(
      stream: audioPlayer.speedStream,
      builder: (context, snapshot) {
        final currentSpeed = snapshot.data ?? 1.0;

        return PopupMenuButton<double>(
          icon: Icon(Icons.speed_rounded, color: accentColor),
          onSelected: (speed) => audioPlayer.setSpeed(speed),
          itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
              .map(
                (speed) => PopupMenuItem<double>(
                  value: speed,
                  child: Row(
                    children: [
                      if (currentSpeed == speed)
                        Icon(Icons.check, color: accentColor, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text('${speed}x'),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildVolumeControl(
    BuildContext context,
    Color accentColor,
    ThemeData theme,
  ) {
    return StreamBuilder<double>(
      stream: audioPlayer.volumeStream,
      builder: (context, snapshot) {
        final currentVolume = snapshot.data ?? 1.0;

        return PopupMenuButton<double>(
          icon: Icon(
            currentVolume > 0.5
                ? Icons.volume_up_rounded
                : currentVolume > 0
                ? Icons.volume_down_rounded
                : Icons.volume_off_rounded,
            color: accentColor,
          ),
          itemBuilder: (context) => [
            PopupMenuItem<double>(
              enabled: false,
              child: SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Text('Hlasitosť', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor,
                        thumbColor: accentColor,
                        inactiveTrackColor: accentColor.withValues(alpha: 0.3),
                      ),
                      child: Slider(
                        value: currentVolume,
                        onChanged: (value) => audioPlayer.setVolume(value),
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Minimálne controls len s play/pause
class AudioPlayerControlsMinimal extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;
  final AudioPlayerCallback? onPlay;
  final AudioPlayerCallback? onPause;
  final double size;

  const AudioPlayerControlsMinimal({
    super.key,
    required this.audioPlayer,
    this.accentColor,
    this.onPlay,
    this.onPause,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = accentColor ?? theme.colorScheme.primary;

    return StreamBuilder<PlayerState>(
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final status = playerState != null
            ? UniversalAudioStatus.fromPlayerState(playerState)
            : UniversalAudioStatus.idle;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveAccentColor.withValues(alpha: 0.1),
            border: Border.all(color: effectiveAccentColor, width: 1.5),
          ),
          child: status.isLoading
              ? Padding(
                  padding: EdgeInsets.all(size * 0.25),
                  child: CircularProgressIndicator(
                    color: effectiveAccentColor,
                    strokeWidth: 1.5,
                  ),
                )
              : IconButton(
                  onPressed: _getPlayPauseCallback(status),
                  icon: Icon(_getPlayPauseIcon(status)),
                  iconSize: size * 0.5,
                  color: effectiveAccentColor,
                  padding: EdgeInsets.zero,
                ),
        );
      },
    );
  }

  VoidCallback? _getPlayPauseCallback(UniversalAudioStatus status) {
    if (status.isLoading) return null;

    if (status.canPlay) {
      return onPlay;
    } else if (status.canPause) {
      return onPause;
    }

    return null;
  }

  IconData _getPlayPauseIcon(UniversalAudioStatus status) {
    switch (status) {
      case UniversalAudioStatus.playing:
        return Icons.pause_rounded;
      case UniversalAudioStatus.completed:
        return Icons.replay_rounded;
      default:
        return Icons.play_arrow_rounded;
    }
  }
}

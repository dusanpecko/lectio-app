import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

/// Floating audio player widget - extrahovaný z LectioScreen.
///
/// Zobrazuje buď minimalizovaný kruh (na ľavej strane)
/// alebo plný prehrávač so slider-om, playlist-om a ovládaním.
class LectioFloatingAudioPlayer extends StatelessWidget {
  const LectioFloatingAudioPlayer({
    super.key,
    required this.tracks,
    required this.currentAudioSection,
    required this.isPlaying,
    required this.isPlayingInterlude,
    required this.isMinimized,
    required this.currentPosition,
    required this.totalDuration,
    required this.audioMode,
    required this.playlistPageController,
    required this.onPlayPause,
    required this.onSkipPrevious,
    required this.onSkipNext,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onPlayTrack,
    required this.onAudioModeChanged,
    required this.onMinimize,
    required this.onClose,
  });

  /// Dostupné audio stopy
  final List<Map<String, dynamic>> tracks;

  /// Aktuálna audio sekcia (key)
  final String? currentAudioSection;

  /// Či sa prehráva audio
  final bool isPlaying;

  /// Či sa prehráva meditačná hudba (interlude)
  final bool isPlayingInterlude;

  /// Či je prehrávač minimalizovaný (kruh)
  final bool isMinimized;

  /// Aktuálna pozícia prehrávania
  final Duration currentPosition;

  /// Celková dĺžka prehrávania
  final Duration totalDuration;

  /// Audio mode: 'none', 'short', 'long'
  final String audioMode;

  /// PageView controller pre playlist
  final PageController playlistPageController;

  // ============ Callbacks ============

  /// Play/Pause toggle - volajúci rozhodne čo urobiť
  final VoidCallback onPlayPause;

  /// Skip na predchádzajúci track (null = disabled)
  final VoidCallback? onSkipPrevious;

  /// Skip na ďalší track (null = disabled)
  final VoidCallback? onSkipNext;

  /// Seek začal (slúži na nastavenie seeking stavu)
  final VoidCallback onSeekStart;

  /// Seek sa mení (vizuálna aktualizácia pozície)
  final ValueChanged<Duration> onSeekChanged;

  /// Seek skončil (skutočný seek)
  final ValueChanged<double> onSeekEnd;

  /// Prehrať konkrétny track (url, key)
  final void Function(String url, String key) onPlayTrack;

  /// Zmena audio režimu
  final ValueChanged<String> onAudioModeChanged;

  /// Toggle minimalizácia
  final VoidCallback onMinimize;

  /// Zatvoriť a zastaviť prehrávač
  final VoidCallback onClose;

  // ============ Helpers ============

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getNowPlayingTitle() {
    if (isPlayingInterlude) {
      return 'Meditačná hudba';
    }

    final currentTrack = tracks.firstWhere(
      (t) => t['key'] == currentAudioSection,
      orElse: () => {'label': 'Audio'},
    );

    return currentTrack['label'] ?? 'Audio';
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    if (isMinimized) {
      return _buildMinimizedPlayer(context);
    }
    return _buildFullPlayer(context);
  }

  // ============================================
  // MINIMALIZOVANÝ REŽIM - Kruh na ľavej strane
  // ============================================
  Widget _buildMinimizedPlayer(BuildContext context) {
    final navBarHeight = MediaQuery.of(context).viewPadding.bottom;
    return Positioned(
      bottom: 20 + navBarHeight,
      left: 16,
      child: GestureDetector(
        onTap: onMinimize,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              if (totalDuration.inMilliseconds > 0)
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value:
                        currentPosition.inMilliseconds /
                        totalDuration.inMilliseconds,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              // Play/Pause icon
              Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              // Pulsing animation when playing
              if (isPlaying) const Positioned.fill(child: _PulsingCircle()),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // PLNÝ PREHRÁVAČ
  // ============================================
  Widget _buildFullPlayer(BuildContext context) {
    final theme = Theme.of(context);
    final navBarHeight = MediaQuery.of(context).viewPadding.bottom;
    final currentTrackIndex = tracks.indexWhere(
      (t) => t['key'] == currentAudioSection,
    );
    final currentTrack = currentTrackIndex >= 0
        ? tracks[currentTrackIndex]
        : null;

    return Positioned(
      bottom: 16 + navBarHeight,
      left: 16,
      right: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme),

            // Plný obsah prehrávača
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Audio Mode Selector
                  _buildAudioModeSelector(context, theme),
                  const SizedBox(height: AppSpacing.md),

                  // Now Playing
                  _buildNowPlaying(context, theme, currentTrack),

                  // Controls
                  _buildControls(theme, currentTrackIndex),

                  // Progress bar
                  const SizedBox(height: AppSpacing.sm),
                  _buildProgressBar(context, theme),

                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // Playlist
                  _buildPlaylist(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ Header ============
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Audio prehrávač',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minimize button
              IconButton(
                icon: const Icon(
                  Icons.remove_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Minimalizovať',
                onPressed: onMinimize,
              ),
              const SizedBox(width: AppSpacing.lg),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Zatvoriť a zastaviť',
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ Audio Mode Selector ============
  Widget _buildAudioModeSelector(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAudioModeIconButton(context, 'none', Icons.music_off, theme),
        const SizedBox(width: AppSpacing.md),
        _buildAudioModeIconButton(context, 'short', Icons.music_note, theme),
        const SizedBox(width: AppSpacing.md),
        _buildAudioModeIconButton(context, 'long', Icons.queue_music, theme),
      ],
    );
  }

  Widget _buildAudioModeIconButton(
    BuildContext context,
    String mode,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = audioMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onAudioModeChanged(mode),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? AppColors.primary
                : (AppColors.isDark(context)
                      ? AppColors.darkCard
                      : Colors.grey.shade200),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected
                ? Colors.white
                : AppColors.adaptiveCardSubtitle(context),
            size: 28,
          ),
        ),
      ),
    );
  }

  // ============ Now Playing ============
  Widget _buildNowPlaying(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic>? currentTrack,
  ) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: currentAudioSection != null
          ? Container(
              key: ValueKey(
                '${currentAudioSection}_${isPlayingInterlude ? 'interlude' : 'track'}',
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isPlayingInterlude
                        ? Icons.spa
                        : (currentTrack?['icon'] ?? Icons.music_note),
                    color: isPlayingInterlude
                        ? Colors.blue.shade300
                        : (currentTrack?['color'] ?? AppColors.primary),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Práve hrá',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.adaptiveCardSubtitle(context),
                          ),
                        ),
                        Text(
                          _getNowPlayingTitle(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ============ Controls ============
  Widget _buildControls(ThemeData theme, int currentTrackIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: onSkipPrevious != null
              ? AppColors.primary
              : Colors.grey.shade400,
          onPressed: onSkipPrevious,
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A5085).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
            color: Colors.white,
            onPressed: onPlayPause,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: onSkipNext != null ? AppColors.primary : Colors.grey.shade400,
          onPressed: onSkipNext,
        ),
      ],
    );
  }

  // ============ Progress Bar ============
  Widget _buildProgressBar(BuildContext context, ThemeData theme) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          _formatDuration(currentPosition),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.adaptiveCardSubtitle(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.3),
            ),
            child: Slider(
              value: totalDuration.inMilliseconds > 0
                  ? currentPosition.inMilliseconds.toDouble().clamp(
                      0.0,
                      totalDuration.inMilliseconds.toDouble(),
                    )
                  : 0.0,
              min: 0.0,
              max: totalDuration.inMilliseconds > 0
                  ? totalDuration.inMilliseconds.toDouble()
                  : 1.0,
              onChangeStart: currentAudioSection != null
                  ? (value) => onSeekStart()
                  : null,
              onChangeEnd: currentAudioSection != null
                  ? (value) => onSeekEnd(value)
                  : null,
              onChanged: currentAudioSection != null
                  ? (value) {
                      onSeekChanged(Duration(milliseconds: value.toInt()));
                    }
                  : null,
            ),
          ),
        ),
        Text(
          _formatDuration(totalDuration),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.adaptiveCardSubtitle(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============ Playlist ============
  Widget _buildPlaylist(BuildContext context, ThemeData theme) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Dostupné nahrávky',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.adaptiveCardTitle(context),
          ),
        ),
        const SizedBox(height: 10),

        // PageView so swipe
        SizedBox(
          height: 70,
          child: PageView.builder(
            controller: playlistPageController,
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrentTrack = track['key'] == currentAudioSection;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GestureDetector(
                  onTap: () {
                    // Ak už hrá rovnaký track, nerob nič
                    if (track['key'] == currentAudioSection && isPlaying) {
                      return;
                    }
                    onPlayTrack(track['url'], track['key']);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: isCurrentTrack
                          ? LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.primary.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isCurrentTrack
                          ? null
                          : (AppColors.isDark(context)
                                ? AppColors.darkCard
                                : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: isCurrentTrack
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 2,
                            )
                          : Border.all(
                              color: AppColors.isDark(context)
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                      boxShadow: isCurrentTrack
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Ikona
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              track['icon'],
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Názov nahrávky + playing indicator
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track['label'],
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: isCurrentTrack
                                        ? AppColors.primary
                                        : theme.colorScheme.onSurface,
                                    fontWeight: isCurrentTrack
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isCurrentTrack && isPlaying) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Práve hrá',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Download status ikona
                          if (track['localPath'] != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.xs,
                              ),
                              child: Icon(
                                Icons.offline_pin_rounded,
                                size: 18,
                                color: Colors.green.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page indicator (dots)
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tracks.length, (index) {
            final isCurrentPage = tracks[index]['key'] == currentAudioSection;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrentPage ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCurrentPage ? AppColors.primary : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Pulsujúci kruh pre minimalizovaný prehrávač počas prehrávania
class _PulsingCircle extends StatefulWidget {
  const _PulsingCircle();

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lectio_divina/controllers/lectio_audio_controller.dart';
import 'package:lectio_divina/models/lectio_audio_track.dart';
import 'package:lectio_divina/shared/app_colors.dart';

class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  // Singleton instance
  final LectioAudioController _audioController = LectioAudioController();

  // Local state for dragging (if we want dragging, but for now fixed position is fine)
  // Replicating _dragPosition for slider logic
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using ListenableBuilder to rebuild when controller changes
    return ListenableBuilder(
      listenable: _audioController,
      builder: (context, child) {
        // Ak prehrávač nie je viditeľný (napr. užívateľ ho zatvoril alebo nehrá), nezobrazuj nič
        // NOTE: Pôvodne LectioScreen používal _showAudioPlayer.
        // Teraz to čítame z controllera.
        if (!_audioController.isPlayerVisible) {
          return const SizedBox.shrink();
        }

        // ============================================
        // MINIMALIZOVANÝ REŽIM
        // ============================================
        if (_audioController.isPlayerMinimized) {
          return Positioned(
            bottom: 20 + MediaQuery.of(context).viewPadding.bottom, // Safe area
            left: 16,
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: () {
                  _audioController.setPlayerMinimized(false);
                },
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
                      if (_audioController.totalDuration.inMilliseconds > 0)
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value:
                                _audioController
                                    .currentPosition
                                    .inMilliseconds /
                                _audioController.totalDuration.inMilliseconds,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      // Play/Pause icon
                      Icon(
                        _audioController.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      // Pulsing animation when playing
                      if (_audioController.isPlaying)
                        Positioned.fill(child: const PulsingCircle()),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // ============================================
        // PLNÝ PREHRÁVAČ
        // ============================================
        // Zobraz current track alebo null
        final tracks = _audioController.playlist;
        LectioAudioTrack? currentTrack;
        final index = tracks.indexWhere(
          (t) => t.key == _audioController.currentAudioSection,
        );
        if (index >= 0) {
          currentTrack = tracks[index];
        }

        return Positioned(
          bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
          left: 16,
          right: 16,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(
                maxWidth: 400,
              ), // Max width for tablets
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(20),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('audio_player'),
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
                              onPressed: () {
                                _audioController.setPlayerMinimized(true);
                              },
                            ),
                            const SizedBox(width: 16),
                            // Close button
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.white,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await _audioController.stop();
                                _audioController.setPlayerVisible(false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Plný obsah prehrávača
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Audio Mode Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAudioModeIconButton(
                              'none',
                              Icons.music_off,
                              theme,
                            ),
                            const SizedBox(width: 12),
                            _buildAudioModeIconButton(
                              'short',
                              Icons.music_note,
                              theme,
                            ),
                            const SizedBox(width: 12),
                            _buildAudioModeIconButton(
                              'long',
                              Icons.queue_music,
                              theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Now Playing
                        if (_audioController.currentAudioSection != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _audioController.currentAudioSection ==
                                          'interlude'
                                      ? Icons.spa
                                      : (currentTrack?.icon ??
                                            Icons.music_note),
                                  color:
                                      _audioController.currentAudioSection ==
                                          'interlude'
                                      ? Colors.blue.shade300
                                      : (currentTrack?.color ??
                                            AppColors.primary),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Práve hrá',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                      Text(
                                        _audioController.currentTitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
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
                          ),

                        const SizedBox(height: 16),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded),
                              onPressed: () => _audioController.playPrevious(),
                              color: AppColors.primary,
                              iconSize: 32,
                            ),
                            _buildPlayPauseButton(),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              onPressed: () => _audioController.playNext(),
                              color: AppColors.primary,
                              iconSize: 32,
                            ),
                          ],
                        ),

                        // Slider & Time
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value:
                                (_dragPosition ??
                                        _audioController.currentPosition)
                                    .inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0.0,
                                      _audioController
                                          .totalDuration
                                          .inMilliseconds
                                          .toDouble(),
                                    ),
                            min: 0.0,
                            max: _audioController.totalDuration.inMilliseconds
                                .toDouble(),
                            activeColor: AppColors.primary,
                            inactiveColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _dragPosition = Duration(
                                  milliseconds: value.toInt(),
                                );
                              });
                            },
                            onChangeEnd: (value) {
                              _audioController.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                              setState(() {
                                _dragPosition = null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(
                                  _dragPosition ??
                                      _audioController.currentPosition,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _formatDuration(_audioController.totalDuration),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    final isPlaying = _audioController.isPlaying;
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
      child: IconButton(
        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
        onPressed: () {
          _audioController.playPause();
        },
        color: Colors.white,
        iconSize: 40,
      ),
    );
  }

  Widget _buildAudioModeIconButton(
    String mode,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _audioController.audioMode == mode;
    return InkWell(
      onTap: () => _audioController.setAudioMode(mode),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class PulsingCircle extends StatefulWidget {
  const PulsingCircle({super.key});

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle>
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

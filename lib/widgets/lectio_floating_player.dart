import 'package:flutter/material.dart';

import '../services/lectio_audio_player.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

/// Floating audio player widget for Lectio screen
class LectioFloatingPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> tracks;
  final String audioMode;
  final VoidCallback? onClose;
  final void Function(String mode)? onAudioModeChanged;

  const LectioFloatingPlayer({
    super.key,
    required this.tracks,
    required this.audioMode,
    this.onClose,
    this.onAudioModeChanged,
  });

  @override
  State<LectioFloatingPlayer> createState() => _LectioFloatingPlayerState();
}

class _LectioFloatingPlayerState extends State<LectioFloatingPlayer> {
  final LectioAudioPlayer _audioPlayer = LectioAudioPlayer();
  bool _isMinimized = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _audioPlayer.initialize();
    _audioPlayer.setPlaylist(widget.tracks, widget.audioMode);

    _audioPlayer.onTrackChanged = (key, index) {
      if (mounted && index >= 0 && _pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      setState(() {});
    };

    _audioPlayer.onPlaylistCompleted = () {
      if (mounted) {
        setState(() {});
      }
    };

    _audioPlayer.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(LectioFloatingPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tracks != oldWidget.tracks ||
        widget.audioMode != oldWidget.audioMode) {
      _audioPlayer.setPlaylist(widget.tracks, widget.audioMode);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getNowPlayingTitle() {
    if (_audioPlayer.isPlayingInterlude) {
      return 'Meditačná hudba';
    }
    final index = _audioPlayer.currentTrackIndex;
    if (index >= 0 && index < widget.tracks.length) {
      return widget.tracks[index]['label'] ?? 'Audio';
    }
    return 'Lectio Divina';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isMinimized) {
      return _buildMinimizedPlayer(theme);
    }

    return _buildFullPlayer(theme);
  }

  Widget _buildMinimizedPlayer(ThemeData theme) {
    final duration = _audioPlayer.duration ?? Duration.zero;
    final position = _audioPlayer.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Positioned(
      bottom: 20,
      left: 16,
      child: GestureDetector(
        onTap: () => setState(() => _isMinimized = false),
        child: Container(
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
              SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              // Play/Pause icon
              Icon(
                _audioPlayer.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullPlayer(ThemeData theme) {
    final theme = Theme.of(context);
    final duration = _audioPlayer.duration ?? Duration.zero;
    final position = _audioPlayer.position;
    final currentKey = _audioPlayer.currentTrackKey;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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
                      IconButton(
                        icon: const Icon(
                          Icons.remove_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _isMinimized = true),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          await _audioPlayer.stop();
                          widget.onClose?.call();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Audio Mode Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton('none', Icons.music_off, theme),
                      const SizedBox(width: AppSpacing.md),
                      _buildModeButton('short', Icons.music_note, theme),
                      const SizedBox(width: AppSpacing.md),
                      _buildModeButton('long', Icons.queue_music, theme),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Now Playing
                  if (currentKey != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _audioPlayer.isPlayingInterlude
                                ? Icons.spa
                                : Icons.music_note,
                            color: _audioPlayer.isPlayingInterlude
                                ? Colors.blue.shade300
                                : AppColors.primary,
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
                                    color: Colors.grey.shade600,
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
                    ),

                  const SizedBox(height: AppSpacing.sm),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        color: AppColors.primary,
                        onPressed: () => _audioPlayer.skipPrevious(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
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
                          icon: Icon(
                            _audioPlayer.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 32,
                          ),
                          color: Colors.white,
                          onPressed: () {
                            if (_audioPlayer.isPlaying) {
                              _audioPlayer.pause();
                            } else {
                              _audioPlayer.play();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        color: AppColors.primary,
                        onPressed: () => _audioPlayer.skipNext(),
                      ),
                    ],
                  ),

                  // Progress bar
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds.toDouble(),
                                )
                              : 0,
                          min: 0,
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          onChanged: (value) {
                            _audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),

                  // Playlist
                  Text(
                    'Dostupné nahrávky',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 70,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.tracks.length,
                      itemBuilder: (context, index) {
                        final track = widget.tracks[index];
                        final isCurrentTrack = track['key'] == currentKey;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: GestureDetector(
                            onTap: () => _audioPlayer.playTrackByIndex(index),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: isCurrentTrack
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                        ],
                                      )
                                    : null,
                                color: isCurrentTrack
                                    ? null
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                                border: Border.all(
                                  color: isCurrentTrack
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : Colors.grey.shade300,
                                  width: isCurrentTrack ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                      child: Icon(
                                        track['icon'] ?? Icons.music_note,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track['label'] ?? 'Track',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  color: isCurrentTrack
                                                      ? AppColors.primary
                                                      : null,
                                                  fontWeight: isCurrentTrack
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isCurrentTrack &&
                                              _audioPlayer.isPlaying)
                                            Text(
                                              'Práve hrá',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                        ],
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

                  // Page indicator
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.tracks.length, (index) {
                      final isCurrentPage =
                          index == _audioPlayer.currentTrackIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrentPage ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrentPage
                              ? AppColors.primary
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, IconData icon, ThemeData theme) {
    final isSelected = widget.audioMode == mode;
    return GestureDetector(
      onTap: () {
        widget.onAudioModeChanged?.call(mode);
        _audioPlayer.setAudioMode(mode);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
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
          color: isSelected ? Colors.white : Colors.grey.shade600,
          size: 28,
        ),
      ),
    );
  }
}

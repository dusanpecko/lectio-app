import 'package:flutter/material.dart';

import '../services/audio_player_service.dart';
import '../shared/app_colors.dart';

class FloatingAudioPlayer extends StatelessWidget {
  final AudioPlayerService audioService;
  final List<Map<String, dynamic>> tracks;
  final VoidCallback onClose;
  final Function(String url, String key) onTrackTap;
  final VoidCallback? onNextTrack;
  final VoidCallback? onPreviousTrack;

  const FloatingAudioPlayer({
    super.key,
    required this.audioService,
    required this.tracks,
    required this.onClose,
    required this.onTrackTap,
    this.onNextTrack,
    this.onPreviousTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTrackIndex = tracks.indexWhere(
      (t) => t['key'] == audioService.currentAudioSection,
    );
    final currentTrack = currentTrackIndex >= 0
        ? tracks[currentTrackIndex]
        : null;

    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        width: 320,
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
            _buildHeader(theme),
            _buildContent(theme, currentTrack, currentTrackIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Audio prehrávač',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    Map<String, dynamic>? currentTrack,
    int currentTrackIndex,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAudioModeSelector(theme),
          const SizedBox(height: 16),
          _buildNowPlaying(theme, currentTrack),
          _buildControls(theme, currentTrackIndex),
          if (currentTrack != null) _buildProgressBar(theme),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildPlaylist(theme),
        ],
      ),
    );
  }

  Widget _buildAudioModeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAudioModeButton(
                  'none',
                  'Bez hudby',
                  Icons.music_off,
                  theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAudioModeButton(
                  'short',
                  'Krátka',
                  Icons.music_note,
                  theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAudioModeButton(
                  'long',
                  'Dlhá',
                  Icons.queue_music,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioModeButton(
    String mode,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = audioService.audioMode == mode;
    return InkWell(
      onTap: () => audioService.setAudioMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlaying(ThemeData theme, Map<String, dynamic>? currentTrack) {
    if (currentTrack == null &&
        audioService.currentAudioSection != 'interlude') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                audioService.currentAudioSection == 'interlude'
                    ? Icons.spa
                    : (currentTrack?['icon'] ?? Icons.music_note),
                color: audioService.currentAudioSection == 'interlude'
                    ? Colors.blue.shade300
                    : (currentTrack?['color'] ?? Colors.grey),
                size: 24,
              ),
              const SizedBox(width: 12),
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
                      audioService.currentAudioSection == 'interlude'
                          ? 'Meditačná hudba'
                          : (currentTrack?['label'] ?? ''),
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildControls(ThemeData theme, int currentTrackIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: currentTrackIndex > 0
              ? AppColors.primary
              : Colors.grey.shade400,
          onPressed: currentTrackIndex > 0 ? onPreviousTrack : null,
        ),
        const SizedBox(width: 8),
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
              audioService.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 32,
            ),
            color: Colors.white,
            onPressed: () {
              if (audioService.isPlaying) {
                audioService.pause();
              } else {
                audioService.resume();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: currentTrackIndex < tracks.length - 1
              ? AppColors.primary
              : Colors.grey.shade400,
          onPressed: currentTrackIndex < tracks.length - 1 ? onNextTrack : null,
        ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              audioService.formatDuration(audioService.currentPosition),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            Expanded(
              child: Slider(
                value: audioService.currentPosition.inSeconds.toDouble(),
                max: audioService.totalDuration.inSeconds.toDouble() > 0
                    ? audioService.totalDuration.inSeconds.toDouble()
                    : 1.0,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                onChanged: (value) {
                  audioService.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
            Text(
              audioService.formatDuration(audioService.totalDuration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaylist(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Dostupné nahrávky',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrentTrack =
                  track['key'] == audioService.currentAudioSection;

              return InkWell(
                onTap: () => onTrackTap(track['url'], track['key']),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isCurrentTrack
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        track['icon'],
                        color: isCurrentTrack
                            ? AppColors.primary
                            : track['color'],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          track['label'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrentTrack
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: isCurrentTrack
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentTrack && audioService.isPlaying)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

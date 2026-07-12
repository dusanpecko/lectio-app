// widgets/audio/universal_audio_player.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_models.dart';
import 'audio_progress_bar.dart';
import 'audio_player_controls.dart';
import '../../shared/app_spacing.dart';
import '../../services/audio_exclusive.dart';

class UniversalAudioPlayer extends StatefulWidget {
  final UniversalAudioItem audioItem;
  final AudioPlayer? audioPlayer; // Voliteľný external player
  final Color? accentColor; // Override pre rosary kategórie
  final AudioPlayerConfig config;
  final EdgeInsets padding;
  final double? height;
  final bool showHeader;
  final String headerTitle;
  final AudioErrorCallback? onError;
  final AudioStateCallback? onStateChanged;

  const UniversalAudioPlayer({
    super.key,
    required this.audioItem,
    this.audioPlayer,
    this.accentColor,
    this.config = const AudioPlayerConfig(),
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    this.height,
    this.showHeader = true,
    this.headerTitle = 'Audio prehrávač',
    this.onError,
    this.onStateChanged,
  });

  /// Factory pre rosary decade - s kategóriou farbou
  factory UniversalAudioPlayer.rosary({
    required String? audioUrl,
    required String title,
    required String? author,
    required String albumName,
    required String? artworkUrl,
    required String id,
    required Color categoryColor,
    AudioPlayer? audioPlayer,
    AudioPlayerConfig config = AudioPlayerConfig.rosary,
  }) {
    return UniversalAudioPlayer(
      audioItem: UniversalAudioItem.fromRosaryDecade(
        audioUrl: audioUrl,
        title: title,
        author: author,
        albumName: albumName,
        artworkUrl: artworkUrl,
        id: id,
      ),
      audioPlayer: audioPlayer,
      accentColor: categoryColor,
      config: config,
      headerTitle: 'Audio ruženec',
    );
  }

  /// Factory pre lectio - používa theme farby
  factory UniversalAudioPlayer.lectio({
    required String? audioUrl,
    required String title,
    required String? speaker,
    required String? artworkUrl,
    required String id,
    AudioPlayer? audioPlayer,
    AudioPlayerConfig config = AudioPlayerConfig.lectio,
  }) {
    return UniversalAudioPlayer(
      audioItem: UniversalAudioItem.fromLectio(
        audioUrl: audioUrl,
        title: title,
        speaker: speaker,
        artworkUrl: artworkUrl,
        id: id,
      ),
      audioPlayer: audioPlayer,
      config: config,
      headerTitle: 'Audio lectio',
    );
  }

  @override
  State<UniversalAudioPlayer> createState() => _UniversalAudioPlayerState();
}

class _UniversalAudioPlayerState extends State<UniversalAudioPlayer> {
  late final AudioPlayer _audioPlayer;
  late final bool _ownsPlayer;

  @override
  void initState() {
    super.initState();

    // Použije external player alebo vytvorí vlastný
    if (widget.audioPlayer != null) {
      _audioPlayer = widget.audioPlayer!;
      _ownsPlayer = false;
    } else {
      _audioPlayer = AudioPlayer();
      _ownsPlayer = true;
    }

    // Nastavenie state change listener
    if (widget.onStateChanged != null) {
      _audioPlayer.playerStateStream.listen((state) {
        widget.onStateChanged!(state);
      });
    }
  }

  @override
  void dispose() {
    // Dispose len ak vlastníme player
    if (_ownsPlayer) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor =
        widget.accentColor ?? theme.colorScheme.primary;

    if (!widget.audioItem.hasValidAudio) {
      return _buildNoAudioWidget(theme);
    }

    return Container(
      height: widget.height,
      margin: widget.padding,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: theme.cardTheme.shape != null
            ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: effectiveAccentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow:
            theme.cardTheme.elevation != null && theme.cardTheme.elevation! > 0
            ? [
                BoxShadow(
                  color:
                      theme.cardTheme.shadowColor?.withValues(alpha: 0.1) ??
                      theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header s informáciami
            if (widget.showHeader) ...[
              _buildHeader(theme, effectiveAccentColor),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Progress bar
            if (widget.config.showProgressBar) ...[
              AudioProgressBar(
                audioPlayer: _audioPlayer,
                accentColor: effectiveAccentColor,
                onSeek: _handleSeek,
                showDuration: widget.config.showDuration,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Ovládacie tlačidlá
            AudioPlayerControls(
              audioPlayer: _audioPlayer,
              accentColor: effectiveAccentColor,
              onPlay: _handlePlay,
              onPause: _handlePause,
              onStop: widget.config.showStopButton ? _handleStop : null,
              onSeek: _handleSeek,
              config: widget.config,
            ),

            // Informácie o tracku
            if (widget.config.showTitle || widget.config.showAuthor) ...[
              const SizedBox(height: AppSpacing.md),
              _buildTrackInfo(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color accentColor) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.headphones_rounded, color: accentColor, size: 24),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            widget.headerTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ),
        _buildStatusIndicator(theme, accentColor),
      ],
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, Color accentColor) {
    final theme = Theme.of(context);
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final status = playerState != null
            ? UniversalAudioStatus.fromPlayerState(playerState)
            : UniversalAudioStatus.idle;

        final statusColor = _getStatusColor(status, accentColor);

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            status.displayText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackInfo(ThemeData theme) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (widget.config.showTitle) ...[
          Text(
            widget.audioItem.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (widget.config.showAuthor && widget.audioItem.author != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.audioItem.author!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildNoAudioWidget(ThemeData theme) {
    final theme = Theme.of(context);
    return Container(
      margin: widget.padding,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: theme.cardTheme.shape != null
            ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Icon(
                  Icons.volume_off_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  widget.headerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Nedostupné',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'Audio nie je dostupné',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Audio handlers
  Future<void> _handlePlay() async {
    try {
      final audioUrl = widget.audioItem.audioUrl;
      if (audioUrl == null || audioUrl.isEmpty) {
        _handleError('Chýba URL pre audio súbor');
        return;
      }

      // Výhradný slot natívneho playera (just_audio_background = 1 naraz) —
      // MUSÍ byť pred setAudioSource (to je aktivačný bod platformy).
      await AudioExclusive.acquire(_audioPlayer);

      // Nastavenie audio source ak nie je nastavené alebo sa zmenil
      if (_audioPlayer.audioSource == null ||
          _audioPlayer.audioSource.toString() != audioUrl) {
        // LockCaching: stream + disková cache → seek a opakované prehratie
        // sú okamžité (fix 7.7.2026).
        // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
        final audioSource = LockCachingAudioSource(
          Uri.parse(audioUrl),
          tag: widget.audioItem.toMediaItem(),
        );

        await _audioPlayer.setAudioSource(audioSource);
      }

      await _audioPlayer.play();
    } catch (e) {
      _handleError('Chyba pri prehrávaní: $e');
    }
  }

  Future<void> _handlePause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _handleError('Chyba pri pozastavení: $e');
    }
  }

  Future<void> _handleStop() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
    } catch (e) {
      _handleError('Chyba pri zastavení: $e');
    }
  }

  Future<void> _handleSeek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _handleError('Chyba pri posúvaní: $e');
    }
  }

  void _handleError(String error) {
    if (widget.onError != null) {
      widget.onError!(error);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(UniversalAudioStatus status, Color accentColor) {
    switch (status) {
      case UniversalAudioStatus.playing:
        return Colors.green;
      case UniversalAudioStatus.loading:
        return Colors.orange;
      case UniversalAudioStatus.error:
        return Colors.red;
      case UniversalAudioStatus.completed:
        return Colors.blue;
      default:
        return accentColor;
    }
  }
}

/// Kompaktná verzia audio playera
class UniversalAudioPlayerCompact extends StatelessWidget {
  final UniversalAudioItem audioItem;
  final AudioPlayer? audioPlayer;
  final Color? accentColor;

  const UniversalAudioPlayerCompact({
    super.key,
    required this.audioItem,
    this.audioPlayer,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return UniversalAudioPlayer(
      audioItem: audioItem,
      audioPlayer: audioPlayer,
      accentColor: accentColor,
      config: AudioPlayerConfig.minimal,
      showHeader: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

/// Rozšírená verzia s pokročilými funkciami
class UniversalAudioPlayerAdvanced extends StatelessWidget {
  final UniversalAudioItem audioItem;
  final AudioPlayer? audioPlayer;
  final Color? accentColor;
  final AudioPlayerConfig config;

  const UniversalAudioPlayerAdvanced({
    super.key,
    required this.audioItem,
    this.audioPlayer,
    this.accentColor,
    this.config = const AudioPlayerConfig(),
  });

  @override
  Widget build(BuildContext context) {
    return UniversalAudioPlayer(
      audioItem: audioItem,
      audioPlayer: audioPlayer,
      accentColor: accentColor,
      config: config,
      showHeader: true,
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/audio_download_state.dart';
import '../services/audio_download_service.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

/// Ikona stavu stiahnutia pre jednotlivý audio track
///
/// Zobrazuje:
/// - Šípka dole: nie je stiahnuté
/// - Kruhový progress: sťahuje sa
/// - Fajka: stiahnuté
/// - Červený krížik: chyba
class DownloadStatusIcon extends StatelessWidget {
  final AudioDownloadState state;
  final VoidCallback? onTap;
  final double size;

  const DownloadStatusIcon({
    super.key,
    required this.state,
    this.onTap,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: size, height: size, child: _buildIcon(context)),
    );
  }

  Widget _buildIcon(BuildContext context) {
    switch (state.status) {
      case AudioDownloadStatus.notDownloaded:
        return Icon(
          Icons.download_rounded,
          size: size,
          color: Colors.grey[500],
        );

      case AudioDownloadStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size - 4,
              height: size - 4,
              child: CircularProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            Icon(
              Icons.pause_rounded,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ],
        );

      case AudioDownloadStatus.downloaded:
        return Icon(
          Icons.download_done_rounded,
          size: size,
          color: Colors.green,
        );

      case AudioDownloadStatus.error:
        return Icon(Icons.error_outline_rounded, size: size, color: Colors.red);
    }
  }
}

/// Banner pre indikáciu offline audio dostupnosti
///
/// Zobrazuje sa v Lectio screene keď sú audio stopy dostupné offline
class OfflineAudioBanner extends StatelessWidget {
  final int downloadedTracks;
  final int totalTracks;
  final VoidCallback? onManageTap;

  const OfflineAudioBanner({
    super.key,
    required this.downloadedTracks,
    required this.totalTracks,
    this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (downloadedTracks == 0) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isComplete = downloadedTracks >= totalTracks;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isComplete
            ? (isDarkMode ? Colors.green.shade900 : Colors.green.shade50)
            : (isDarkMode
                  ? Colors.orange.shade900.withValues(alpha: 0.3)
                  : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isComplete
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.offline_pin_rounded : Icons.download_rounded,
            size: 18,
            color: isComplete ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isComplete
                  ? tr('offline.audio_available_offline')
                  : tr(
                      'offline.audio_partial_download',
                      args: ['$downloadedTracks', '$totalTracks'],
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isComplete
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onManageTap != null)
            GestureDetector(
              onTap: onManageTap,
              child: Icon(
                Icons.settings_rounded,
                size: 16,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }
}

/// Progres bar pre sťahovanie audio
class AudioDownloadProgress extends StatelessWidget {
  final double progress;
  final int currentTrack;
  final int totalTracks;
  final VoidCallback? onCancel;

  const AudioDownloadProgress({
    super.key,
    required this.progress,
    required this.currentTrack,
    required this.totalTracks,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr(
                    'offline.downloading_audio',
                    args: ['$currentTrack', '$totalTracks'],
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zobrazí jednoduchý indikátor úspechu (zelená fajka v kruhu)
void _showSuccessIndicator(BuildContext context) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  // Automaticky odstrán po 1.5 sekundách
  Future.delayed(const Duration(milliseconds: 1500), () {
    overlayEntry.remove();
  });
}

/// Dialóg pre správu offline audio úložiska
class AudioStorageDialog extends StatelessWidget {
  final AudioDownloadService downloadService;

  const AudioStorageDialog({super.key, required this.downloadService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.storage_rounded, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Text(tr('offline.storage_title')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            Icons.audio_file_rounded,
            tr('offline.downloaded_files'),
            '${downloadService.downloadedFilesCount}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow(
            context,
            Icons.sd_storage_rounded,
            tr('offline.storage_used'),
            downloadService.formattedStorageSize,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('offline.storage_info'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        TextButton(
          onPressed: () async {
            await downloadService.cleanupOldDownloads();
            if (context.mounted) {
              Navigator.pop(context);
              _showSuccessIndicator(context);
            }
          },
          child: Text(tr('offline.cleanup_old')),
        ),
        ElevatedButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(tr('offline.confirm_delete_all')),
                content: Text(tr('offline.confirm_delete_all_desc')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(tr('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('offline.delete_all')),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await downloadService.clearAllDownloads();
              if (context.mounted) {
                Navigator.pop(context);
                _showSuccessIndicator(context);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(tr('offline.delete_all')),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

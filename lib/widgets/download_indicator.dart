import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/audio_download_state.dart';
import '../services/audio_download_service.dart';
import '../shared/app_colors.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isComplete
            ? (isDarkMode ? Colors.green.shade900 : Colors.green.shade50)
            : (isDarkMode
                  ? Colors.orange.shade900.withValues(alpha: 0.3)
                  : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 8),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            Icons.sd_storage_rounded,
            tr('offline.storage_used'),
            downloadService.formattedStorageSize,
          ),
          const SizedBox(height: 16),
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
          child: Text(tr('common.cancel')),
        ),
        TextButton(
          onPressed: () async {
            final deleted = await downloadService.cleanupOldDownloads();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tr('offline.cleanup_result', args: ['$deleted']),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
                    child: Text(tr('common.cancel')),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('offline.all_audio_deleted')),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
        const SizedBox(width: 8),
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

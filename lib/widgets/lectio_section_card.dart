import 'package:flutter/material.dart';

import '../shared/app_colors.dart';

/// Widget pre zobrazenie jednej sekcie Lectio Divina
/// (Lectio, Meditatio, Oratio, Contemplatio, Actio)
class LectioSectionCard extends StatelessWidget {
  const LectioSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.text,
    this.reference,
  });

  final String? title;
  final String subtitle;
  final String text;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTitle = title;
    if (text.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (localTitle != null && localTitle.isNotEmpty)
                Text(
                  localTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5, // Lepšie riadkovanie pre čitateľnosť
                  ),
                ),
              ],
              if (reference != null && reference!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reference!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Sheet „Ranná pripomienka evanjelia“ (11.2.4). Vráti vybraný čas, keď
/// používateľ ťukne „Zapnúť pripomienku“, inak null.
Future<TimeOfDay?> showNotificationPromptSheet(BuildContext context) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationPromptSheet(),
  );
}

class _NotificationPromptSheet extends StatefulWidget {
  const _NotificationPromptSheet();

  @override
  State<_NotificationPromptSheet> createState() => _NotificationPromptSheetState();
}

class _NotificationPromptSheetState extends State<_NotificationPromptSheet> {
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'notifications.permission.prompt_time'.tr(),
    );
    if (picked != null) {
      // Zaokrúhlenie na 15 min — server posiela v 15-min oknách.
      final m = (picked.minute / 15).round() * 15;
      setState(() => _time = TimeOfDay(hour: (picked.hour + (m == 60 ? 1 : 0)) % 24, minute: m % 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radius),
          boxShadow: HomeV2.softShadowSm(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                  ),
                  child: Icon(Icons.wb_twilight_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'notifications.permission.prompt_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'notifications.permission.prompt_body'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('notifications.permission.prompt_time'.tr(), style: theme.textTheme.bodyMedium)),
                    Text('$hh:$mm', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_time),
              icon: const Icon(Icons.notifications_active_rounded),
              label: Text('notifications.permission.prompt_enable'.tr()),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('notifications.permission.prompt_later'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

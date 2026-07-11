import 'package:flutter/material.dart';

import '../shared/app_spacing.dart';

/// Znovupoužiteľná karta pre nastavenia
/// Poskytuje konzistentnú štruktúru pre všetky karty v nastaveniach
class SettingsCard extends StatelessWidget {
  /// Ikona zobrazená v záhlaví karty
  final IconData icon;

  /// Titulok karty
  final String title;

  /// Obsah karty
  final Widget child;

  /// Voliteľný trailing widget v záhlaví
  final Widget? trailing;

  /// Či zobraziť divider medzi záhlavím a obsahom
  final bool showDivider;

  /// Voliteľný padding pre obsah
  final EdgeInsets? contentPadding;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.showDivider = false,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (showDivider) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
            ],
            const SizedBox(height: AppSpacing.md),
            contentPadding != null
                ? Padding(padding: contentPadding!, child: child)
                : child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Karta s prepínačom (switch) pre boolean nastavenia
class SettingsSwitchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const SettingsSwitchCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      elevation: AppElevation.high,
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// Položka pre radio výber v nastaveniach
class SettingsRadioOption<T> extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T?>? onChanged;

  const SettingsRadioOption({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged ?? (_) {},
      child: RadioListTile<T>(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(title),
          ],
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        enabled: onChanged != null,
      ),
    );
  }
}

/// Sekcia nastavení s nadpisom
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Text(
            title,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

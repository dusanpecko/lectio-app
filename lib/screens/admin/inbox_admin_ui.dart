import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';

/// Zdieľané v2 UI prvky pre admin Inbox obrazovky (hero, karty, inputy).

/// Okrúhle tlačidlo (napr. späť) v štýle HomeV2.
class InboxCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const InboxCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

/// Gradientová hero hlavička so serif nadpisom (vzor v2 obrazoviek).
class InboxHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  const InboxHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary
                .withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InboxCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: HomeV2.serifTitle(context, size: 30, height: 1.1)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekčná karta v2 s hlavičkou (ikona v tónovanom kruhu + názov) a obsahom.
class InboxSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const InboxSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HomeV2.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: HomeV2.iconAccent(context), size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textDark(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// Jednotná v2 dekorácia inputov (jemné vyplnenie, zaoblené, bez tvrdého borderu).
InputDecoration inboxInput(
  BuildContext context, {
  String? label,
  String? hint,
  bool dense = false,
}) {
  final fill = HomeV2.isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF5F2FF);
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: fill,
    isDense: dense,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: dense ? 10 : 14,
    ),
    labelStyle: TextStyle(color: HomeV2.textMuted(context)),
    border: border(Colors.transparent, 0),
    enabledBorder: border(Colors.transparent, 0),
    focusedBorder: border(HomeV2.primary, 1.5),
  );
}

/// Malý štítok nad skupinou volieb.
class InboxFieldLabel extends StatelessWidget {
  final String text;
  const InboxFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeV2.textMuted(context),
          ),
        ),
      );
}

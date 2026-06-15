import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_colors.dart';
import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Položka glass bottom navigácie.
class GlassNavItem {
  final IconData icon;
  final String labelKey;
  const GlassNavItem({required this.icon, required this.labelKey});
}

/// Plávajúci „glassmorphism" bottom navigation bar (blur + pološíbiele pozadie).
/// Položky: Domov · Lectio · Modlitby · Na úvod · Viac.
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<GlassNavItem> items = [
    GlassNavItem(icon: Icons.menu_book_rounded, labelKey: 'nav_lectio'),
    GlassNavItem(icon: Icons.edit_note_rounded, labelKey: 'notes_title'),
    GlassNavItem(
        icon: Icons.volunteer_activism_rounded, labelKey: 'nav_prayers'),
    GlassNavItem(icon: Icons.article_rounded, labelKey: 'nav_intro'),
    GlassNavItem(icon: Icons.grid_view_rounded, labelKey: 'nav_more'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: bottomInset > 0 ? bottomInset : AppSpacing.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: HomeV2.card(context).withValues(alpha: isDark ? 0.55 : 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.45),
              ),
              boxShadow: HomeV2.softShadow(context),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                return _NavButton(
                  item: items[index],
                  isActive: index == currentIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(index);
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = HomeV2.primary;
    final inactiveColor = HomeV2.textMuted(context);

    return Semantics(
      button: true,
      selected: isActive,
      label: tr(item.labelKey),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  size: 24,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tr(item.labelKey),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

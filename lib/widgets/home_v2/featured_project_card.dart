import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Featured karta projektu (Slovo bez hraníc) — rovnaký štýl ako
/// FeaturedExerciseCard, ale lokálny obrázok a zlatý overline (podpora).
/// Tap → prezentačná obrazovka projektu.
class FeaturedProjectCard extends StatelessWidget {
  final String imageAsset;
  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Výška karty — väčšia na tablete (responzívne z carouselu).
  final double height;

  const FeaturedProjectCard({
    super.key,
    required this.imageAsset,
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackBg(),
              ),

              // Gradient pre čitateľnosť textu
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black26, Colors.black87],
                    stops: [0.35, 0.65, 1.0],
                  ),
                ),
              ),

              // Obsah dole
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: HomeV2.goldLight),
                        const SizedBox(width: 6),
                        Text(
                          badge.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: HomeV2.goldLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: HomeV2.serifTitle(context, size: 20)
                          .copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBg() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HomeV2.primary.withValues(alpha: 0.85), HomeV2.primary],
          ),
        ),
      );
}

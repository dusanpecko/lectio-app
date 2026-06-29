import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/spiritual_exercise.dart';
import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Featured karta duchovného cvičenia — obrázok na pozadí, overline, názov,
/// dátum + miesto. Tap → detail.
class FeaturedExerciseCard extends StatelessWidget {
  final SpiritualExercise exercise;
  final VoidCallback onTap;

  /// Výška karty — väčšia na tablete (responzívne z carouselu).
  final double height;

  const FeaturedExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final df = DateFormat('d. MMM', locale);
    final dateRange =
        '${df.format(exercise.startDate)} – ${df.format(exercise.endDate)}';
    final image = exercise.homeImageUrl ?? exercise.imageUrl;

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
              if (image != null)
                CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: HomeV2.primary.withValues(alpha: 0.15)),
                  errorWidget: (_, _, _) => _fallbackBg(),
                )
              else
                _fallbackBg(),

              // Gradient pre čitateľnosť textu
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      Colors.black87,
                    ],
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
                        const Icon(Icons.spa_rounded,
                            size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          tr('spiritual_exercises').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exercise.title,
                      style: HomeV2.serifTitle(context, size: 20)
                          .copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          dateRange,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            exercise.locationDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

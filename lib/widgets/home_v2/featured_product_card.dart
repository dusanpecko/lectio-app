import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/shop_product.dart';
import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Featured karta produktu z e-shopu — rovnaký vizuál ako FeaturedProjectCard,
/// ale fotka produktu ide zo siete a v podtitulku je cena. Ktoré produkty sa
/// sem dostanú, určuje admin (hviezda „featured" + poradie v admin e-shope);
/// zobrazuje sa len v SK mutácii appky, kým je e-shop len slovenský.
class FeaturedProductCard extends StatelessWidget {
  final ShopProduct product;
  final String locale;
  final VoidCallback onTap;
  final double height;

  const FeaturedProductCard({
    super.key,
    required this.product,
    required this.locale,
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
              if (product.images.isEmpty)
                _fallbackBg()
              else
                CachedNetworkImage(
                  imageUrl: product.images.first,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _fallbackBg(),
                  errorWidget: (_, _, _) => _fallbackBg(),
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
                        const Icon(Icons.shopping_bag_rounded,
                            size: 15, color: HomeV2.goldLight),
                        const SizedBox(width: 6),
                        Text(
                          'E-SHOP',
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
                      product.nameFor(locale),
                      style: HomeV2.serifTitle(context, size: 20)
                          .copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '€${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
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

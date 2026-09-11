import 'package:flutter/material.dart';

import '../../services/cart_service.dart';
import '../home_v2/home_v2_tokens.dart';

/// Zlatý odznak počtu položiek košíka nad ľubovoľným tlačidlom (live cez
/// [CartService]).
///
/// Zdieľaný medzi zoznamom obchodu a detailom produktu — predtým bol odznak
/// len v `shop_screen`, takže po „Do košíka" na detaile sa ku košíku nedalo
/// dostať bez návratu do zoznamu.
class CartBadge extends StatelessWidget {
  final Widget child;
  const CartBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: HomeV2.gold,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

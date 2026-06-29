/// Výpočet poštovného a balného — zrkadlí backend `src/lib/shipping.ts`
/// (`computeShipping` / `pickShippingDiscountPercent`), aby zobrazené poštovné
/// v appke == účtované pri platbe.
library;

class ShippingTier {
  final int minItems;
  final int percent;
  const ShippingTier(this.minItems, this.percent);
}

/// Predvolené prahy (ak ich backend nevráti) — zhodné s DEFAULT_SHIPPING_DISCOUNT_TIERS.
const List<ShippingTier> kDefaultShippingTiers = [
  ShippingTier(3, 50),
  ShippingTier(2, 25),
];

/// Najvyššia aplikovateľná % zľava pre daný počet kusov.
int pickShippingDiscountPercent(int totalQty, List<ShippingTier> tiers) {
  final applicable = tiers.where((t) => totalQty >= t.minItems).toList()
    ..sort((a, b) => b.percent.compareTo(a.percent));
  return applicable.isEmpty ? 0 : applicable.first.percent;
}

class ShippingResult {
  final double base; // poštovné pred zľavou
  final int discountPercent; // uplatnená zľava (%)
  final double cost; // poštovné po zľave (účtované)
  final int totalQty;
  const ShippingResult({
    required this.base,
    required this.discountPercent,
    required this.cost,
    required this.totalQty,
  });

  bool get hasDiscount => discountPercent > 0 && cost < base;
}

/// Položka pre výpočet — poštovné za kus × množstvo.
class ShippingItem {
  final double shippingCost;
  final int qty;
  const ShippingItem(this.shippingCost, this.qty);
}

ShippingResult computeShipping(
  Iterable<ShippingItem> items,
  List<ShippingTier> tiers,
) {
  double base = 0;
  int totalQty = 0;
  for (final it in items) {
    base += it.shippingCost * it.qty;
    totalQty += it.qty;
  }
  final discountPercent = pickShippingDiscountPercent(totalQty, tiers);
  final cost = (base * (1 - discountPercent / 100) * 100).round() / 100;
  return ShippingResult(
    base: base,
    discountPercent: discountPercent,
    cost: cost,
    totalQty: totalQty,
  );
}

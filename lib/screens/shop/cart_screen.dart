import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/cart_service.dart';
import '../../services/shipping_calc.dart';
import '../../services/shop_service.dart';
import '../../services/supporter_discount_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<ShippingTier> _tiers = kDefaultShippingTiers;
  SupporterDiscountInfo _discount = SupporterDiscountInfo.none;

  @override
  void initState() {
    super.initState();
    ShopService.instance.fetchShippingTiers().then((t) {
      if (mounted) setState(() => _tiers = t);
    });
    SupporterDiscountService.instance.fetch().then((d) {
      if (mounted) setState(() => _discount = d);
    });
  }

  /// Podporovateľská zľava pre položku (jednotková cena × % na 1 ks), 0 ak sa
  /// neuplatňuje. Server prepočíta autoritatívne — toto je len pre zobrazenie.
  double _supporterDiscountFor(CartItem item) {
    if (!item.useDiscount) return 0;
    if (!_discount.canUseFor(
      item.product.id,
      discountable: item.product.discountable,
    )) {
      return 0;
    }
    return (item.product.price * _discount.percent / 100 * 100)
            .roundToDouble() /
        100;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context)
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) {
            final cart = CartService.instance;
            return Column(
              children: [
                _buildHero(context),
                Expanded(
                  child: cart.isEmpty
                      ? _empty(context)
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xl,
                          ),
                          children: [
                            for (final item in cart.items)
                              _CartRow(
                                key: ValueKey(item.product.id),
                                name: item.product.nameFor(locale),
                                image: item.product.image,
                                price: item.product.price,
                                qty: item.qty,
                                max: item.product.stock,
                                onQty: (q) => cart.setQty(item.product.id, q),
                                onRemove: () => cart.remove(item.product.id),
                                discountRedeemed:
                                    _discount.eligible &&
                                    _discount.redeemedProductIds.contains(
                                      item.product.id,
                                    ),
                                discountEligible: _discount.canUseFor(
                                  item.product.id,
                                  discountable: item.product.discountable,
                                ),
                                discountPercent: _discount.percent,
                                useDiscount: item.useDiscount,
                                onToggleDiscount: (v) =>
                                    cart.setUseDiscount(item.product.id, v),
                              ),
                          ],
                        ),
                ),
                if (!cart.isEmpty) _buildSummary(context, cart, bottomPad),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(
              alpha: HomeV2.isDark(context) ? 0.32 : 0.14,
            ),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'shop.cart_title'.tr(),
            style: HomeV2.serifTitle(context, size: 28, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          size: 52,
          color: HomeV2.iconAccent(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'shop.cart_empty'.tr(),
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 15),
        ),
      ],
    ),
  );

  Widget _sumRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            color: emphasize
                ? HomeV2.textDark(context)
                : HomeV2.textMuted(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 20 : 15,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: HomeV2.textDark(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    CartService cart,
    double bottomPad,
  ) {
    final ship = cart.shipping(_tiers);
    double supporterDiscount = 0;
    for (final item in cart.items) {
      supporterDiscount += _supporterDiscountFor(item);
    }
    supporterDiscount = (supporterDiscount * 100).roundToDouble() / 100;
    final total = cart.subtotal - supporterDiscount + ship.cost;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        bottomPad + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sumRow(
            context,
            'shop.goods_total'.tr(),
            '€${cart.subtotal.toStringAsFixed(2)}',
          ),
          if (supporterDiscount > 0) ...[
            const SizedBox(height: 8),
            _sumRow(
              context,
              'shop.supporter_discount'.tr(),
              '−€${supporterDiscount.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: 8),
          _sumRow(
            context,
            ship.hasDiscount
                ? '${'shop.shipping_handling'.tr()}  (−${ship.discountPercent}%)'
                : 'shop.shipping_handling'.tr(),
            '€${ship.cost.toStringAsFixed(2)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(
              height: 1,
              color: HomeV2.textMuted(context).withValues(alpha: 0.2),
            ),
          ),
          _sumRow(
            context,
            'shop.total'.tr(),
            '€${total.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeV2.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                ),
              ),
              child: Text(
                'shop.continue_to_checkout'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final String name;
  final String? image;
  final double price;
  final int qty;
  final int max;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;
  final bool discountEligible;
  final bool discountRedeemed;
  final double discountPercent;
  final bool useDiscount;
  final ValueChanged<bool>? onToggleDiscount;
  const _CartRow({
    super.key,
    required this.name,
    required this.image,
    required this.price,
    required this.qty,
    required this.max,
    required this.onQty,
    required this.onRemove,
    this.discountEligible = false,
    this.discountRedeemed = false,
    this.discountPercent = 0,
    this.useDiscount = false,
    this.onToggleDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image != null
                ? CachedNetworkImage(
                    imageUrl: image!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    errorWidget: (_, _, _) => _imgFallback(context),
                  )
                : _imgFallback(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '€${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HomeV2.primary,
                  ),
                ),
                if (discountRedeemed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'shop.discount_used'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                  )
                else if (discountEligible)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: () => onToggleDiscount?.call(!useDiscount),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            useDiscount
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: HomeV2.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'shop.use_supporter_discount'.tr(
                                args: [discountPercent.toStringAsFixed(0)],
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HomeV2.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              InkWell(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: HomeV2.textMuted(context),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _stepBtn(context, Icons.remove_rounded, () => onQty(qty - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$qty',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ),
                  _stepBtn(
                    context,
                    Icons.add_rounded,
                    qty < max ? () => onQty(qty + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext context, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap == null
              ? HomeV2.textMuted(context).withValues(alpha: 0.08)
              : HomeV2.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? HomeV2.textMuted(context) : HomeV2.primary,
        ),
      ),
    );
  }

  Widget _imgFallback(BuildContext context) => Container(
    width: 56,
    height: 56,
    color: HomeV2.primary.withValues(alpha: 0.08),
    child: Icon(
      Icons.shopping_bag_rounded,
      color: HomeV2.iconAccent(context),
      size: 24,
    ),
  );
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/shop_product.dart';
import '../../services/cart_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ShopProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  int _imgPage = 0;
  final PageController _imgController = PageController();

  ShopProduct get p => widget.product;

  @override
  void dispose() {
    _imgController.dispose();
    super.dispose();
  }

  void _addToCart({bool thenCheckout = false}) {
    HapticFeedback.lightImpact();
    CartService.instance.add(p, qty: _qty);
    if (thenCheckout) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('shop.added_to_cart'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: p.images.isEmpty
                            ? _imgFallback()
                            : PageView.builder(
                                controller: _imgController,
                                itemCount: p.images.length,
                                onPageChanged: (i) =>
                                    setState(() => _imgPage = i),
                                itemBuilder: (_, i) => CachedNetworkImage(
                                  imageUrl: p.images[i],
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => ColoredBox(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                  ),
                                  errorWidget: (_, _, _) => _imgFallback(),
                                ),
                              ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + AppSpacing.sm,
                        left: AppSpacing.lg,
                        child: _CircleButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      // Indikátor strán (len pri viacerých fotkách)
                      if (p.images.length > 1)
                        Positioned(
                          bottom: AppSpacing.md,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(p.images.length, (i) {
                                  final active = i == _imgPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: active ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nameFor(locale),
                          style: HomeV2.serifTitle(
                            context,
                            size: 24,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '€${p.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: HomeV2.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (p.subjectToVat
                                  ? 'shop.price_with_vat'
                                  : 'shop.vat_not_applied')
                              .tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 14,
                                color: HomeV2.textMuted(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${'shop.shipping_handling'.tr()}: €${p.shippingCost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HomeV2.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: p.inStock
                              ? Text(
                                  'shop.in_stock_count'.tr(
                                    args: ['${p.stock}'],
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                )
                              : Text(
                                  'shop.out_of_stock'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC0392B),
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (p.descFor(locale).isNotEmpty)
                          MarkdownBody(
                            data: p.descFor(locale),
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: HomeV2.textDark(context),
                                  ),
                                  listBullet: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: HomeV2.textDark(context),
                                  ),
                                  a: TextStyle(
                                    color: HomeV2.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                            onTapLink: (text, href, title) {
                              if (href != null && href.isNotEmpty) {
                                launchUrl(
                                  Uri.parse(href),
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                        if (p.inStock) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Text(
                                'shop.qty'.tr(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: HomeV2.textDark(context),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              _QtyStepper(
                                qty: _qty,
                                max: p.stock,
                                onChanged: (q) => setState(() => _qty = q),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (p.inStock)
              Container(
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
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _addToCart(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HomeV2.primary,
                          side: BorderSide(color: HomeV2.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              HomeV2.radiusSm,
                            ),
                          ),
                        ),
                        child: Text(
                          'shop.add_to_cart'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _addToCart(thenCheckout: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HomeV2.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              HomeV2.radiusSm,
                            ),
                          ),
                        ),
                        child: Text(
                          'shop.buy_now'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: HomeV2.primary.withValues(alpha: 0.08),
    child: Icon(
      Icons.shopping_bag_rounded,
      color: HomeV2.iconAccent(context),
      size: 64,
    ),
  );
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;
  const _QtyStepper({
    required this.qty,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: HomeV2.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: qty > 1 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_rounded),
            color: HomeV2.primary,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$qty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeV2.textDark(context),
            ),
          ),
          IconButton(
            onPressed: qty < max ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add_rounded),
            color: HomeV2.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/shop_category.dart';
import '../../models/shop_product.dart';
import '../../services/cart_service.dart';
import '../../services/shop_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

enum _Status { loading, ready, error }

class _ShopScreenState extends State<ShopScreen> {
  _Status _status = _Status.loading;
  List<ShopProduct> _products = [];
  List<ShopCategory> _categories = [];
  String? _selectedCategory;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    ShopService.instance.fetchCategories().then((c) {
      if (mounted) setState(() => _categories = c);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final items = await ShopService.instance.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = items;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
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
            _buildHero(),
            if (_status == _Status.ready && _products.isNotEmpty)
              _buildFilters(locale),
            Expanded(child: _buildBody(locale)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'shop.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              ),
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(label: 'shop.all'.tr(), value: null),
                  for (final c in _categories)
                    _categoryChip(label: c.titleFor(locale), value: c.code),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip({required String label, required String? value}) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = value),
        selectedColor: HomeV2.primary,
        backgroundColor: HomeV2.card(context),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : HomeV2.textDark(context),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildHero() {
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
          Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              _cartButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'shop.title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'shop.subtitle'.tr(),
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

  Widget _cartButton() {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleButton(icon: Icons.shopping_bag_rounded, onTap: _openCart),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
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
          ],
        );
      },
    );
  }

  Widget _buildBody(String locale) {
    if (_status == _Status.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_status == _Status.error) {
      return _msg(Icons.cloud_off_rounded, 'shop.error'.tr(), retry: true);
    }
    if (_products.isEmpty) {
      return _msg(Icons.shopping_bag_outlined, 'shop.empty'.tr());
    }

    final q = _query.trim().toLowerCase();
    final filtered = _products.where((p) {
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }
      if (q.isNotEmpty && !p.nameFor(locale).toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return _msg(Icons.search_off_rounded, 'shop.no_results'.tr());
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: HomeV2.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.62,
        ),
        itemCount: filtered.length,
        itemBuilder: (_, i) =>
            _ProductCard(product: filtered[i], locale: locale),
      ),
    );
  }

  Widget _msg(IconData icon, String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            if (retry) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
                label: Text(
                  'retry'.tr(),
                  style: TextStyle(
                    color: HomeV2.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final String locale;
  const _ProductCard({required this.product, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: product.image != null
                    ? CachedNetworkImage(
                        imageUrl: product.image!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => ColoredBox(
                          color: Colors.grey.withValues(alpha: 0.15),
                        ),
                        errorWidget: (_, _, _) => _imgFallback(context),
                      )
                    : _imgFallback(context),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameFor(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HomeV2.primary,
                      ),
                    ),
                    Text(
                      (product.subjectToVat
                              ? 'shop.price_with_vat'
                              : 'shop.vat_not_applied')
                          .tr(),
                      style: TextStyle(
                        fontSize: 10,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                    if (!product.inStock)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'shop.out_of_stock'.tr(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC0392B),
                          ),
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

  Widget _imgFallback(BuildContext context) => Container(
    color: HomeV2.primary.withValues(alpha: 0.08),
    child: Icon(
      Icons.shopping_bag_rounded,
      color: HomeV2.iconAccent(context),
      size: 40,
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

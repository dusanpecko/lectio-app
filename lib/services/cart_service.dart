import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_product.dart';
import 'shipping_calc.dart';

class CartItem {
  final ShopProduct product;
  int qty;

  /// Či má používateľ na túto položku uplatniť podporovateľskú zľavu.
  /// Server pri checkoute aj tak overí nárok (tier, discountable, raz na produkt).
  bool useDiscount;

  CartItem(this.product, this.qty, {this.useDiscount = false});
}

// Zrkadlia serverové limity v /api/checkout/products (inak checkout spadne až
// na serveri s generickou chybou).
const int kMaxQtyPerItem = 100;
const int kMaxItemsPerOrder = 50;

/// Košík e-shopu — singleton [ChangeNotifier]. Obrazovky počúvajú cez
/// `ListenableBuilder(listenable: CartService.instance, ...)`.
class CartService extends ChangeNotifier {
  CartService._() {
    _load(); // obnov košík z disku (prežije reštart appky)
  }
  static final CartService instance = CartService._();

  static const _kCartKey = 'shop_cart_v1';

  final Map<String, CartItem> _items = {}; // productId → položka

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List?) ?? const [];
      for (final e in list) {
        final m = (e as Map).cast<String, dynamic>();
        final p = ShopProduct.fromJson(
          (m['product'] as Map).cast<String, dynamic>(),
        );
        final q = (m['qty'] as num?)?.toInt() ?? 1;
        final useD = m['useDiscount'] == true;
        if (p.id.isNotEmpty && q > 0) {
          _items[p.id] = CartItem(p, q, useDiscount: useD);
        }
      }
      if (_items.isNotEmpty) notifyListeners();
    } catch (_) {
      // poškodený / starý formát → ignoruj
    }
  }

  void _save() {
    // fire-and-forget; zlyhanie zápisu nech nezhodí UI
    SharedPreferences.getInstance()
        .then((prefs) {
          final list = _items.values
              .map(
                (i) => {
                  'product': i.product.toJson(),
                  'qty': i.qty,
                  'useDiscount': i.useDiscount,
                },
              )
              .toList();
          prefs.setString(_kCartKey, jsonEncode(list));
        })
        .catchError((_) {});
  }

  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;

  /// Počet kusov spolu (pre badge).
  int get count => _items.values.fold(0, (s, i) => s + i.qty);

  /// Medzisúčet (bez poštovného).
  double get subtotal =>
      _items.values.fold(0.0, (s, i) => s + i.product.price * i.qty);

  /// Poštovné a balné pre aktuálny košík podľa zľavových prahov.
  ShippingResult shipping(List<ShippingTier> tiers) => computeShipping(
    _items.values.map((i) => ShippingItem(i.product.shippingCost, i.qty)),
    tiers,
  );

  int qtyOf(String productId) => _items[productId]?.qty ?? 0;

  /// Najvyššie povolené množstvo pre produkt — sklad, najviac však kMaxQtyPerItem.
  int _maxQtyFor(ShopProduct p) =>
      (p.stock > 0 && p.stock < kMaxQtyPerItem) ? p.stock : kMaxQtyPerItem;

  void add(ShopProduct product, {int qty = 1}) {
    final existing = _items[product.id];
    // Limit počtu rôznych položiek v objednávke.
    if (existing == null && _items.length >= kMaxItemsPerOrder) return;
    final next = (existing?.qty ?? 0) + qty;
    _items[product.id] = CartItem(product, next.clamp(1, _maxQtyFor(product)));
    notifyListeners();
    _save();
  }

  void setQty(String productId, int qty) {
    final item = _items[productId];
    if (item == null) return;
    if (qty <= 0) {
      _items.remove(productId);
    } else {
      item.qty = qty.clamp(1, _maxQtyFor(item.product));
    }
    notifyListeners();
    _save();
  }

  void setUseDiscount(String productId, bool value) {
    final item = _items[productId];
    if (item == null || item.useDiscount == value) return;
    item.useDiscount = value;
    notifyListeners();
    _save();
  }

  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
    _save();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
  }

  /// Položky pre checkout API: `[{productId, quantity, useDiscount}]`.
  List<Map<String, dynamic>> toCheckoutItems() => _items.values
      .map(
        (i) => {
          'productId': i.product.id,
          'quantity': i.qty,
          'useDiscount': i.useDiscount,
        },
      )
      .toList();
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop_category.dart';
import '../models/shop_order.dart';
import '../models/shop_product.dart';
import '../utils/app_logger.dart';
import 'shipping_calc.dart';

/// E-shop — načítanie produktov + vytvorenie Mollie checkoutu cez backend.
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  static const _baseUrl = 'https://www.lectio.one';

  Future<List<ShopProduct>> fetchProducts() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/shop/products'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ShopProduct.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      appLogger.e('❌ ShopService.fetchProducts: $e');
      rethrow;
    }
  }

  /// Vytvorí objednávku + Mollie platbu. Vráti odpoveď servera:
  /// `{ url }` (normálne) alebo `{ test: true, orderId, invoiceNumber }`
  /// (dočasný admin test režim — preskočí platbu). Hodí výnimku pri chybe.
  /// Verejná konfigurácia checkoutu (dostupnosť dobierky + príplatok).
  Future<({bool codEnabled, double codFee})> fetchCheckoutConfig() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/shop/checkout-config'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        codEnabled: data['codEnabled'] == true,
        codFee: (data['codFee'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return (codEnabled: false, codFee: 0.0);
    }
  }

  Future<Map<String, dynamic>> createCheckout({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    String paymentMethod = 'card',
    Map<String, dynamic>? companyBilling,
    bool test = false,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final res = await http.post(
      Uri.parse('$_baseUrl/api/checkout/products'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'items': items,
        'shippingAddress': shippingAddress,
        'platform': 'mobile',
        'paymentMethod': paymentMethod,
        'companyBilling': ?companyBilling,
        if (test) 'test': true,
      }),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // Úspech: Mollie (url), dobierka (cod — bez presmerovania) alebo test.
    if (res.statusCode == 200 &&
        (data['url'] != null || data['cod'] == true || data['test'] == true)) {
      return data;
    }
    throw Exception(
        (data['error'] ?? data['message'] ?? 'Checkout zlyhal').toString());
  }

  /// Aktívne kategórie produktov (na filter v shope). Pri chybe vráti prázdne.
  Future<List<ShopCategory>> fetchCategories() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/shop/categories'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['categories'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ShopCategory.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      appLogger.e('❌ ShopService.fetchCategories: $e');
      return [];
    }
  }

  List<ShippingTier>? _cachedTiers;

  /// Zľavové prahy poštovného z backendu (`/api/shop/shipping-discount`).
  /// Cachuje sa na jeden beh appky; pri chybe vráti predvolené prahy
  /// (zhodné s fallbackom na backende → zobrazené poštovné == účtované).
  Future<List<ShippingTier>> fetchShippingTiers() async {
    if (_cachedTiers != null) return _cachedTiers!;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/shop/shipping-discount'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return kDefaultShippingTiers;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['tiers'] as List?) ?? const [];
      final tiers = list
          .whereType<Map>()
          .map((m) => ShippingTier(
                (m['min_items'] as num?)?.toInt() ?? 0,
                (m['percent'] as num?)?.toInt() ?? 0,
              ))
          .where((t) => t.minItems > 0)
          .toList();
      _cachedTiers = tiers.isEmpty ? kDefaultShippingTiers : tiers;
      return _cachedTiers!;
    } catch (e) {
      appLogger.e('❌ ShopService.fetchShippingTiers: $e');
      return kDefaultShippingTiers;
    }
  }

  /// Vráti stav objednávky (alebo null pri chybe) — na overenie reálneho
  /// výsledku platby po návrate z Mollie (jeden redirectUrl pre úspech aj zrušenie).
  Future<String?> fetchOrderStatus(String orderId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/shop/order-status?orderId=$orderId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] as String?;
    } catch (e) {
      appLogger.e('❌ ShopService.fetchOrderStatus: $e');
      return null;
    }
  }

  /// Objednávky prihláseného používateľa („Moje objednávky").
  Future<List<ShopOrder>> fetchMyOrders() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return [];
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shop/my-orders'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Načítanie objednávok zlyhalo (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['orders'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ShopOrder.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

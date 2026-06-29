import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Stav podporovateľskej zľavy pre prihláseného používateľa.
class SupporterDiscountInfo {
  /// Má používateľ nárok (program zapnutý + aktívne predplatné).
  final bool eligible;

  /// Unikátny kód (zobrazený v profile).
  final String? code;

  /// Percentuálna zľava podľa tieru.
  final double percent;

  /// Produkty, na ktoré už zľavu uplatnil (1/1).
  final Set<String> redeemedProductIds;

  const SupporterDiscountInfo({
    required this.eligible,
    this.code,
    this.percent = 0,
    this.redeemedProductIds = const {},
  });

  static const none = SupporterDiscountInfo(eligible: false);

  bool canUseFor(String productId, {required bool discountable}) =>
      eligible &&
      percent > 0 &&
      discountable &&
      !redeemedProductIds.contains(productId);
}

/// Načíta stav podporovateľskej zľavy z backendu (`/api/shop/discount`).
class SupporterDiscountService {
  SupporterDiscountService._();
  static final SupporterDiscountService instance = SupporterDiscountService._();

  static const _baseUrl = 'https://www.lectio.one';

  Future<SupporterDiscountInfo> fetch() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return SupporterDiscountInfo.none;
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/shop/discount'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return SupporterDiscountInfo.none;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['enabled'] != true || j['eligible'] != true) {
        return SupporterDiscountInfo.none;
      }
      return SupporterDiscountInfo(
        eligible: true,
        code: j['code'] as String?,
        percent: (j['percent'] as num?)?.toDouble() ?? 0,
        redeemedProductIds: ((j['redeemedProductIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
    } catch (e) {
      appLogger.d('SupporterDiscount: fetch skipped: $e');
      return SupporterDiscountInfo.none;
    }
  }
}

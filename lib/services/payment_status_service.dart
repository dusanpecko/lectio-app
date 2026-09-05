import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

/// Ako dopadla platba podľa Mollie — nie podľa toho, že sa používateľ vrátil.
enum PaymentOutcome {
  /// Zaplatené (Mollie `paid` / `authorized`).
  paid,

  /// Zrušené, zlyhané alebo expirované — používateľ to môže skúsiť znova.
  cancelled,

  /// Ešte nie je rozhodnuté (`open`, `pending`) alebo sme sa stav nedozvedeli.
  pending,
}

/// Overuje skutočný stav Mollie platby na backende.
///
/// Mollie má jeden redirectUrl pre úspech aj zrušenie, takže samotný návrat do
/// aplikácie nič nedokazuje. Bez tohto overenia appka hlásila „ďakujeme" aj po
/// zrušenej platbe.
class PaymentStatusService {
  PaymentStatusService._();

  static final PaymentStatusService instance = PaymentStatusService._();

  static String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  /// Jedno opýtanie sa na stav.
  Future<PaymentOutcome> fetchOutcome(String paymentId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/mollie/payment-status?paymentId=$paymentId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        appLogger.w('Payment status HTTP ${response.statusCode}');
        return PaymentOutcome.pending;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['isPaid'] == true) return PaymentOutcome.paid;

      switch ((data['status'] as String?)?.toLowerCase()) {
        case 'canceled':
        case 'cancelled':
        case 'expired':
        case 'failed':
          return PaymentOutcome.cancelled;
        default:
          return PaymentOutcome.pending;
      }
    } catch (e) {
      appLogger.w('Payment status check failed', error: e);
      return PaymentOutcome.pending;
    }
  }

  /// Krátky poll — webhook aj samotné zúčtovanie môžu doraziť pár sekúnd po
  /// redirecte, takže jediné opýtanie by zbytočne často skončilo na `pending`.
  Future<PaymentOutcome> waitForOutcome(
    String paymentId, {
    int attempts = 6,
    Duration interval = const Duration(milliseconds: 1500),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final outcome = await fetchOutcome(paymentId);
      if (outcome != PaymentOutcome.pending) return outcome;
      if (i < attempts - 1) await Future.delayed(interval);
    }
    return PaymentOutcome.pending;
  }
}

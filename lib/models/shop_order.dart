class ShopOrderItem {
  final int qty;
  final double price;
  final Map<String, dynamic> name;
  const ShopOrderItem({required this.qty, required this.price, required this.name});

  factory ShopOrderItem.fromJson(Map<String, dynamic> j) => ShopOrderItem(
        qty: (j['quantity'] as num?)?.toInt() ?? 1,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        name: (j['name'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  String nameFor(String locale) {
    final v = name[locale] ??
        name['sk'] ??
        name['en'] ??
        (name.values.isNotEmpty ? name.values.first : '');
    return (v ?? '').toString();
  }
}

class ShopOrder {
  final String id;
  final String status;
  final double total;
  final String currency;
  final String? invoiceNumber;
  final String? invoiceToken;
  final String? trackingNumber;
  final String? createdAt;
  final List<ShopOrderItem> items;

  const ShopOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.currency,
    required this.invoiceNumber,
    required this.invoiceToken,
    required this.trackingNumber,
    required this.createdAt,
    required this.items,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> j) {
    final its = (j['items'] as List?) ?? const [];
    return ShopOrder(
      id: j['id']?.toString() ?? '',
      status: j['status']?.toString() ?? 'pending',
      total: (j['total'] as num?)?.toDouble() ?? 0,
      currency: j['currency']?.toString() ?? 'EUR',
      invoiceNumber: j['invoice_number']?.toString(),
      invoiceToken: j['invoice_token']?.toString(),
      trackingNumber: j['tracking_number']?.toString(),
      createdAt: j['created_at']?.toString(),
      items: its
          .whereType<Map>()
          .map((e) => ShopOrderItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

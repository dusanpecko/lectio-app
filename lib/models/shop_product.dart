/// Produkt e-shopu. `name`/`description` sú multijazyčné mapy.
class ShopProduct {
  final String id;
  final Map<String, dynamic> name;
  final Map<String, dynamic> description;
  final String slug;
  final double price;
  final List<String> images;
  final int stock;
  final String? category;
  final bool subjectToVat;

  /// Či je produkt zaradený do podporovateľskej zľavy (default áno).
  final bool discountable;

  /// Poštovné a balné za 1 ks tohto produktu (€). Pri viacerých kusoch sa
  /// sčítava a uplatní sa % zľava podľa počtu kusov (viď ShippingCalc).
  final double shippingCost;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.slug,
    required this.price,
    required this.images,
    required this.stock,
    this.category,
    this.subjectToVat = false,
    this.discountable = true,
    this.shippingCost = 0,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j) {
    final imgs = (j['images'] as List?) ?? const [];
    return ShopProduct(
      id: j['id']?.toString() ?? '',
      name: (j['name'] as Map?)?.cast<String, dynamic>() ?? {},
      description: (j['description'] as Map?)?.cast<String, dynamic>() ?? {},
      slug: j['slug']?.toString() ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      images: imgs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      category: j['category']?.toString(),
      subjectToVat: j['subject_to_vat'] == true,
      discountable: j['discountable'] != false,
      shippingCost: (j['shipping_cost'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get inStock => stock > 0;
  String? get image => images.isNotEmpty ? images.first : null;

  String nameFor(String locale) => _pick(name, locale);
  String descFor(String locale) => _pick(description, locale);

  /// Pre perzistenciu košíka (zhodné kľúče s [fromJson]).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'slug': slug,
    'price': price,
    'images': images,
    'stock': stock,
    'category': category,
    'subject_to_vat': subjectToVat,
    'discountable': discountable,
    'shipping_cost': shippingCost,
  };
}

String _pick(Map<String, dynamic> m, String locale) {
  final v =
      m[locale] ??
      m['sk'] ??
      m['en'] ??
      (m.values.isNotEmpty ? m.values.first : '');
  return (v ?? '').toString();
}

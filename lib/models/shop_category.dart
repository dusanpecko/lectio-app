/// Kategória produktov e-shopu (multijazyčné názvy). Z `/api/shop/categories`.
class ShopCategory {
  final String code;
  final Map<String, String> titles; // lang → názov

  const ShopCategory(this.code, this.titles);

  factory ShopCategory.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k]?.toString() ?? '';
    return ShopCategory(j['code']?.toString() ?? '', {
      'sk': s('title_sk'),
      'en': s('title_en'),
      'cz': s('title_cz'),
      'es': s('title_es'),
      'fr': s('title_fr'),
      'pt-br': s('title_ptbr'),
    });
  }

  String titleFor(String locale) {
    final v = titles[locale];
    if (v != null && v.isNotEmpty) return v;
    final sk = titles['sk'];
    return (sk != null && sk.isNotEmpty) ? sk : code;
  }
}

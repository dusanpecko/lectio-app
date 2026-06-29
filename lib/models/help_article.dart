/// Návod v sekcii „Pomoc" (spravovaný v backoffice, zobrazený v appke).
/// `title`/`body` sú multijazyčné mapy: { 'sk': '…', 'en': '…', … }.
class HelpArticle {
  final String id;
  final String slug;
  final Map<String, dynamic> title;
  final Map<String, dynamic> body;
  final String? imageUrl;
  final int sortOrder;

  /// Cieľová platforma: `'both'` (default), `'ios'` alebo `'android'`.
  /// Návody pre widgety/notifikácie sú per-OS — viď [isVisibleOn].
  final String platform;

  const HelpArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.sortOrder,
    this.platform = 'both',
  });

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    final img = json['image_url']?.toString();
    final p = json['platform']?.toString();
    return HelpArticle(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: (json['title'] as Map?)?.cast<String, dynamic>() ?? {},
      body: (json['body'] as Map?)?.cast<String, dynamic>() ?? {},
      imageUrl: (img != null && img.isNotEmpty) ? img : null,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      platform: (p == 'ios' || p == 'android') ? p! : 'both',
    );
  }

  /// Či sa návod má zobraziť pre dané OS (`'ios'` / `'android'`).
  /// `'both'` sa zobrazí vždy.
  bool isVisibleOn(String os) => platform == 'both' || platform == os;

  /// Lokalizovaná hodnota s fallbackom: jazyk → sk → en → prvá dostupná.
  String _pick(Map<String, dynamic> m, String locale) {
    final v = m[locale] ??
        m['sk'] ??
        m['en'] ??
        (m.values.isNotEmpty ? m.values.first : '');
    return (v ?? '').toString();
  }

  String titleFor(String locale) => _pick(title, locale);
  String bodyFor(String locale) => _pick(body, locale);
}

/// Odmena (poďakovací darček) za dar na kampaň. Spravovaná v backoffice,
/// zobrazená v appke. `title`/`description` sú multijazyčné mapy.
class CampaignReward {
  final String id;
  final String campaign; // 'potulky' | 'kurz_lectio'
  final Map<String, dynamic> title;
  final Map<String, dynamic> description;
  final String? imageUrl;
  final double amount; // výška daru za odmenu (EUR)
  final int sortOrder;

  /// Max počet kusov (null = bez limitu) a koľko je už nárokovaných.
  final int? limitQty;
  final int claimedCount;

  const CampaignReward({
    required this.id,
    required this.campaign,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.amount,
    required this.sortOrder,
    this.limitQty,
    this.claimedCount = 0,
  });

  factory CampaignReward.fromJson(Map<String, dynamic> json) {
    final img = json['image_url']?.toString();
    return CampaignReward(
      id: json['id']?.toString() ?? '',
      campaign: json['campaign']?.toString() ?? '',
      title: (json['title'] as Map?)?.cast<String, dynamic>() ?? {},
      description: (json['description'] as Map?)?.cast<String, dynamic>() ?? {},
      imageUrl: (img != null && img.isNotEmpty) ? img : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      limitQty: (json['limit_qty'] as num?)?.toInt(),
      claimedCount: (json['claimed_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Či je odmena rozobraná (dosiahnutý limit kusov).
  bool get soldOut => limitQty != null && claimedCount >= limitQty!;

  /// Koľko kusov ešte zostáva (null = bez limitu).
  int? get remaining => limitQty == null ? null : (limitQty! - claimedCount).clamp(0, limitQty!);

  /// Lokalizovaná hodnota s fallbackom: jazyk → sk → en → prvá dostupná.
  String _pick(Map<String, dynamic> m, String locale) {
    final v = m[locale] ??
        m['sk'] ??
        m['en'] ??
        (m.values.isNotEmpty ? m.values.first : '');
    return (v ?? '').toString();
  }

  String titleFor(String locale) => _pick(title, locale);
  String descriptionFor(String locale) => _pick(description, locale);

  /// „€25" (bez desatinných ak je celé číslo).
  String get amountLabel =>
      amount == amount.roundToDouble() ? '€${amount.toInt()}' : '€${amount.toStringAsFixed(2)}';
}

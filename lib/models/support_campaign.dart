/// Kampaň „Podporte" — príbeh + míľniky + cieľ, spravované v backoffice,
/// zobrazené na obrazovke Podporte. Číta sa cez verejné API
/// /api/support/campaign (suma sa počíta server-side z donations + banky).
class SupportMilestone {
  final double amount;
  final String icon;
  final Map<String, dynamic> title;

  const SupportMilestone({
    required this.amount,
    required this.icon,
    required this.title,
  });

  factory SupportMilestone.fromJson(Map<String, dynamic> j) => SupportMilestone(
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        icon: j['icon']?.toString() ?? 'favorite',
        title: (j['title'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  String titleFor(String locale) => _pick(title, locale);
}

class SupportCampaign {
  final bool active;
  final double goalAmount;
  final double currentAmount;
  final int supporters;
  final Map<String, dynamic> story;
  final List<SupportMilestone> milestones;

  /// Ilustračné obrázky príbehu: kód → URL. V príbehu sa referencujú
  /// tokenom `[[kod]]` (napr. `[[img1]]`).
  final Map<String, String> images;
  final bool showAmount;
  final bool showSupporters;

  const SupportCampaign({
    required this.active,
    required this.goalAmount,
    required this.currentAmount,
    required this.supporters,
    required this.story,
    required this.milestones,
    required this.images,
    required this.showAmount,
    required this.showSupporters,
  });

  factory SupportCampaign.fromJson(Map<String, dynamic> j) {
    final ms = (j['milestones'] as List?) ?? const [];
    final imgs = (j['images'] as List?) ?? const [];
    final imageMap = <String, String>{};
    for (final e in imgs.whereType<Map>()) {
      final code = e['code']?.toString() ?? '';
      final url = e['url']?.toString() ?? '';
      if (code.isNotEmpty && url.isNotEmpty) imageMap[code] = url;
    }
    return SupportCampaign(
      active: j['active'] == true,
      goalAmount: (j['goalAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (j['currentAmount'] as num?)?.toDouble() ?? 0,
      supporters: (j['supporters'] as num?)?.toInt() ?? 0,
      story: (j['story'] as Map?)?.cast<String, dynamic>() ?? {},
      milestones: ms
          .whereType<Map>()
          .map((e) => SupportMilestone.fromJson(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.amount.compareTo(b.amount)),
      images: imageMap,
      showAmount: j['showAmount'] != false,
      showSupporters: j['showSupporters'] != false,
    );
  }

  String storyFor(String locale) => _pick(story, locale);

  bool get hasGoal => goalAmount > 0;

  /// Postup 0..1 voči cieľu.
  double get progress =>
      hasGoal ? (currentAmount / goalAmount).clamp(0.0, 1.0) : 0.0;
}

/// Lokalizovaná hodnota s fallbackom: jazyk → sk → en → prvá dostupná.
String _pick(Map<String, dynamic> m, String locale) {
  final v = m[locale] ??
      m['sk'] ??
      m['en'] ??
      (m.values.isNotEmpty ? m.values.first : '');
  return (v ?? '').toString();
}

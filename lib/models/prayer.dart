/// Základná modlitba (spravovaná v backoffice, zobrazená v appke).
/// `shortcode` je per-jazyk unikátny zdrojový identifikátor (napr. `pray_father_sk`).
class Prayer {
  final String id;
  final String shortcode;
  final String lang;
  final String category;
  final String title;
  final String content;
  final int displayOrder;

  /// Voliteľná TTS nahrávka (vygenerovaná v backoffice). `null` = bez audia.
  final String? audioUrl;

  const Prayer({
    required this.id,
    required this.shortcode,
    required this.lang,
    required this.category,
    required this.title,
    required this.content,
    required this.displayOrder,
    this.audioUrl,
  });

  factory Prayer.fromJson(Map<String, dynamic> json) {
    final audio = json['audio_url']?.toString();
    return Prayer(
      id: json['id']?.toString() ?? '',
      shortcode: json['shortcode']?.toString() ?? '',
      lang: (json['lang']?.toString() ?? 'sk').toLowerCase(),
      category: json['category']?.toString() ?? 'other',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      audioUrl: (audio != null && audio.isNotEmpty) ? audio : null,
    );
  }

  bool get hasAudio => audioUrl != null;

  /// Jazyková značka pre UI (sk → SK, pt-br → PT-BR…).
  String get langBadge => lang == 'pt-br' ? 'PT-BR' : lang.toUpperCase();

  /// Základný kód modlitby bez jazykovej prípony (`pray_father_sk` → `pray_father`).
  /// Slúži na zoskupenie tej istej modlitby naprieč jazykmi.
  String get baseCode {
    final suffix = '_$lang';
    return shortcode.endsWith(suffix)
        ? shortcode.substring(0, shortcode.length - suffix.length)
        : shortcode;
  }
}

/// Dynamická kategória modlitieb (spravovaná v backoffice).
class PrayerCategory {
  final String code;
  final String titleSk;
  final String? titleEn;
  final String? titleEs;
  final int sortOrder;

  const PrayerCategory({
    required this.code,
    required this.titleSk,
    this.titleEn,
    this.titleEs,
    required this.sortOrder,
  });

  factory PrayerCategory.fromJson(Map<String, dynamic> json) {
    return PrayerCategory(
      code: json['code']?.toString() ?? '',
      titleSk: json['title_sk']?.toString() ?? '',
      titleEn: json['title_en']?.toString(),
      titleEs: json['title_es']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
    );
  }

  /// Lokalizovaný názov podľa jazyka appky (fallback na SK).
  String titleFor(String locale) {
    switch (locale) {
      case 'en':
        return (titleEn != null && titleEn!.isNotEmpty) ? titleEn! : titleSk;
      case 'es':
        return (titleEs != null && titleEs!.isNotEmpty) ? titleEs! : titleSk;
      default:
        return titleSk;
    }
  }
}


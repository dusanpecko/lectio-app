/// Deviatnik (spravovaný v backoffice, zobrazený v appke).
/// `shortcode` je per-jazyk unikátny (napr. `novena_holy_spirit_sk`);
/// `baseCode` (bez jazykovej prípony) zoskupuje jazykové verzie a je kľúčom
/// lokálneho progresu. Štruktúra dňa: spoločný ÚVOD + denný text + spoločný ZÁVER.
class Novena {
  final String id;
  final String shortcode;
  final String lang;
  final String category;
  final String title;
  final String? description;
  final String? imageUrl;

  final String? introTitle;
  final String? introContent; // HTML
  final String? introAudioUrl;

  final String? conclusionTitle;
  final String? conclusionContent; // HTML
  final String? conclusionAudioUrl;

  final int displayOrder;
  final List<NovenaDay> days;

  const Novena({
    required this.id,
    required this.shortcode,
    required this.lang,
    required this.category,
    required this.title,
    this.description,
    this.imageUrl,
    this.introTitle,
    this.introContent,
    this.introAudioUrl,
    this.conclusionTitle,
    this.conclusionContent,
    this.conclusionAudioUrl,
    required this.displayOrder,
    required this.days,
  });

  factory Novena.fromJson(Map<String, dynamic> json) {
    String? opt(dynamic v) {
      final s = v?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    final days =
        ((json['novena_days'] as List?) ?? [])
            .map((e) => NovenaDay.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    return Novena(
      id: json['id']?.toString() ?? '',
      shortcode: json['shortcode']?.toString() ?? '',
      lang: (json['lang']?.toString() ?? 'sk').toLowerCase(),
      category: json['category']?.toString() ?? 'other',
      title: json['title']?.toString() ?? '',
      description: opt(json['description']),
      imageUrl: opt(json['image_url']),
      introTitle: opt(json['intro_title']),
      introContent: opt(json['intro_content']),
      introAudioUrl: opt(json['intro_audio_url']),
      conclusionTitle: opt(json['conclusion_title']),
      conclusionContent: opt(json['conclusion_content']),
      conclusionAudioUrl: opt(json['conclusion_audio_url']),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      days: days,
    );
  }

  int get totalDays => days.length;

  bool get hasIntro => introContent != null;
  bool get hasConclusion => conclusionContent != null;

  /// Jazyková značka pre UI (sk → SK, pt-br → PT-BR…).
  String get langBadge => lang == 'pt-br' ? 'PT-BR' : lang.toUpperCase();

  /// Základný kód bez jazykovej prípony — zoskupenie jazykových verzií
  /// a kľúč lokálneho progresu (`novena_holy_spirit_sk` → `novena_holy_spirit`).
  String get baseCode {
    final suffix = '_$lang';
    return shortcode.endsWith(suffix)
        ? shortcode.substring(0, shortcode.length - suffix.length)
        : shortcode;
  }
}

/// Jeden deň deviatnika.
class NovenaDay {
  final String id;
  final int dayNumber;
  final String? title;
  final String content; // HTML
  final String? audioUrl;

  const NovenaDay({
    required this.id,
    required this.dayNumber,
    this.title,
    required this.content,
    this.audioUrl,
  });

  factory NovenaDay.fromJson(Map<String, dynamic> json) {
    final audio = json['audio_url']?.toString();
    final title = json['title']?.toString();
    return NovenaDay(
      id: json['id']?.toString() ?? '',
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      title: (title != null && title.isNotEmpty) ? title : null,
      content: json['content']?.toString() ?? '',
      audioUrl: (audio != null && audio.isNotEmpty) ? audio : null,
    );
  }
}

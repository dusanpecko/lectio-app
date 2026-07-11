/// Spovedné zrkadlo (verejný obsah z backoffice — otázky, modlitby,
/// sprievodca). Odpovede používateľa sem NEPATRIA — tie žijú výhradne
/// šifrované v zariadení (ConfessionVaultService).
class ConfessionMirror {
  final String id;
  final String shortcode;
  final String lang;
  final String title;
  final String? description;
  final String? imageUrl;

  final String? introText; // HTML
  final String? introPrayer; // HTML
  final String? closingPrayer; // HTML

  final String? guideConfessionFlow; // HTML: priebeh sv. spovede
  final String? guideInvocation; // HTML: úvodné zvolanie
  final String? guideContrition; // HTML: ľútosť

  final int displayOrder;
  final List<ConfessionSection> sections;

  const ConfessionMirror({
    required this.id,
    required this.shortcode,
    required this.lang,
    required this.title,
    this.description,
    this.imageUrl,
    this.introText,
    this.introPrayer,
    this.closingPrayer,
    this.guideConfessionFlow,
    this.guideInvocation,
    this.guideContrition,
    required this.displayOrder,
    required this.sections,
  });

  factory ConfessionMirror.fromJson(Map<String, dynamic> json) {
    String? opt(dynamic v) {
      final s = v?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    final sections =
        ((json['confession_sections'] as List?) ?? [])
            .map((e) => ConfessionSection.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ConfessionMirror(
      id: json['id']?.toString() ?? '',
      shortcode: json['shortcode']?.toString() ?? '',
      lang: (json['lang']?.toString() ?? 'sk').toLowerCase(),
      title: json['title']?.toString() ?? '',
      description: opt(json['description']),
      imageUrl: opt(json['image_url']),
      introText: opt(json['intro_text']),
      introPrayer: opt(json['intro_prayer']),
      closingPrayer: opt(json['closing_prayer']),
      guideConfessionFlow: opt(json['guide_confession_flow']),
      guideInvocation: opt(json['guide_invocation']),
      guideContrition: opt(json['guide_contrition']),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      sections: sections,
    );
  }

  String get langBadge => lang == 'pt-br' ? 'PT-BR' : lang.toUpperCase();

  /// Base kód bez jazykovej prípony — zoskupenie jazykových verzií a kľúč
  /// lokálnych (šifrovaných) odpovedí.
  String get baseCode {
    final suffix = '_$lang';
    return shortcode.endsWith(suffix)
        ? shortcode.substring(0, shortcode.length - suffix.length)
        : shortcode;
  }

  bool get hasGuide =>
      guideConfessionFlow != null ||
      guideInvocation != null ||
      guideContrition != null;
}

class ConfessionSection {
  final String id;
  final int sortOrder;
  final String title;
  final List<ConfessionQuestion> questions;

  const ConfessionSection({
    required this.id,
    required this.sortOrder,
    required this.title,
    required this.questions,
  });

  factory ConfessionSection.fromJson(Map<String, dynamic> json) {
    final questions =
        ((json['confession_questions'] as List?) ?? [])
            .map((e) => ConfessionQuestion.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ConfessionSection(
      id: json['id']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      questions: questions,
    );
  }
}

class ConfessionQuestion {
  final String id;
  final int sortOrder;
  final String text;

  const ConfessionQuestion({
    required this.id,
    required this.sortOrder,
    required this.text,
  });

  factory ConfessionQuestion.fromJson(Map<String, dynamic> json) {
    return ConfessionQuestion(
      id: json['id']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
    );
  }
}

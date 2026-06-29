/// Dokument (PDF s TTS audiom) — sekcia „Dokumenty" pre pastoral_council/admin.
class PdfDocument {
  final String id;
  final String slug;
  final String title;
  final String lang;
  final int totalChapters;
  final String? description;
  final String? coverImageUrl;
  final DateTime? createdAt;

  const PdfDocument({
    required this.id,
    required this.slug,
    required this.title,
    required this.lang,
    required this.totalChapters,
    this.description,
    this.coverImageUrl,
    this.createdAt,
  });

  factory PdfDocument.fromJson(Map<String, dynamic> json) {
    return PdfDocument(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lang: (json['lang']?.toString() ?? 'sk').toLowerCase(),
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Jazyková značka pre UI (sk → SK, pt → PT-BR…).
  String get langBadge {
    switch (lang) {
      case 'pt':
      case 'pt-br':
        return 'PT-BR';
      default:
        return lang.toUpperCase();
    }
  }
}

/// Kapitola dokumentu — text + TTS audio (vracajú sa len kapitoly s hotovým
/// audiom).
class DocChapter {
  final String id;
  final int chapterIndex;
  final String? title;
  final int charCount;
  final String? audioUrl;
  final String content;

  const DocChapter({
    required this.id,
    required this.chapterIndex,
    this.title,
    required this.charCount,
    this.audioUrl,
    required this.content,
  });

  factory DocChapter.fromJson(Map<String, dynamic> json) {
    return DocChapter(
      id: json['id']?.toString() ?? '',
      chapterIndex: (json['chapter_index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      charCount: (json['char_count'] as num?)?.toInt() ?? 0,
      audioUrl: json['audio_url']?.toString(),
      content: json['content']?.toString() ?? '',
    );
  }
}

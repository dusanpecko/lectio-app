// lib/models/adoration_model.dart

class Adoration {
  final String id;
  final String lang;
  final String title; // nazov
  final String biblicalText; // biblicky_text
  final String introduction; // uvod
  final int order; // poradie
  final bool published; // publikovane
  final String? author; // autor

  // Lectio Divina sekcie
  final String? lectioText;
  final String? commentary; // komentar
  final String? meditatioText;
  final String? oratioHtml;
  final String? contemplatioText;
  final String? actioText;
  final String? introductoryPrayers; // uvodne_modlitby

  // Média
  final String? illustrationImage; // ilustracny_obrazok
  final String? audioRecording; // audio_nahravka

  // Audio fields
  final String? introAudio; // uvod_audio
  final String? introductoryPrayersAudio; // uvodne_modlitby_audio
  final String? lectioAudio; // lectio_audio
  final String? commentaryAudio; // komentar_audio
  final String? meditatioAudio; // meditatio_audio
  final String? oratioAudio; // oratio_audio
  final String? contemplatioAudio; // contemplatio_audio
  final String? actioAudio; // actio_audio

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const Adoration({
    required this.id,
    required this.lang,
    required this.title,
    required this.biblicalText,
    required this.introduction,
    required this.order,
    required this.published,
    this.author,
    this.lectioText,
    this.commentary,
    this.meditatioText,
    this.oratioHtml,
    this.contemplatioText,
    this.actioText,
    this.introductoryPrayers,
    this.illustrationImage,
    this.audioRecording,
    this.introAudio,
    this.introductoryPrayersAudio,
    this.lectioAudio,
    this.commentaryAudio,
    this.meditatioAudio,
    this.oratioAudio,
    this.contemplatioAudio,
    this.actioAudio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Adoration.fromJson(Map<String, dynamic> json) {
    return Adoration(
      id: json['id'].toString(),
      lang: json['lang']?.toString() ?? 'sk',
      title: json['nazov']?.toString() ?? '',
      biblicalText: json['biblicky_text']?.toString() ?? '',
      introduction: json['uvod']?.toString() ?? '',
      order: _parseIntSafely(json['poradie']) ?? 0,
      published: _parseBoolSafely(json['publikovane']) ?? true,
      author: json['autor']?.toString(),
      lectioText: json['lectio_text']?.toString(),
      commentary: json['komentar']?.toString(),
      meditatioText: json['meditatio_text']?.toString(),
      oratioHtml: json['oratio_html']?.toString(),
      contemplatioText: json['contemplatio_text']?.toString(),
      actioText: json['actio_text']?.toString(),
      introductoryPrayers: json['uvodne_modlitby']?.toString(),
      illustrationImage: json['ilustracny_obrazok']?.toString(),
      audioRecording: json['audio_nahravka']?.toString(),
      introAudio: json['uvod_audio']?.toString(),
      introductoryPrayersAudio: json['uvodne_modlitby_audio']?.toString(),
      lectioAudio: json['lectio_audio']?.toString(),
      commentaryAudio: json['komentar_audio']?.toString(),
      meditatioAudio: json['meditatio_audio']?.toString(),
      oratioAudio: json['oratio_audio']?.toString(),
      contemplatioAudio: json['contemplatio_audio']?.toString(),
      actioAudio: json['actio_audio']?.toString(),
      createdAt: _parseDateSafely(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateSafely(json['updated_at']) ?? DateTime.now(),
    );
  }

  // Helper metódy pre bezpečné parsovanie
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _parseBoolSafely(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (value is int) return value == 1;
    return null;
  }

  static DateTime? _parseDateSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Vráti true ak má adorácia dostupné audio
  bool get hasAudio => audioRecording != null && audioRecording!.isNotEmpty;

  // Vráti true ak má adorácia ilustračný obrázok
  bool get hasImage =>
      illustrationImage != null && illustrationImage!.isNotEmpty;

  // Vráti true ak má nejaké audio nahrávky pre jednotlivé sekcie
  bool get hasSectionAudios =>
      (introAudio?.isNotEmpty ?? false) ||
      (lectioAudio?.isNotEmpty ?? false) ||
      (meditatioAudio?.isNotEmpty ?? false) ||
      (oratioAudio?.isNotEmpty ?? false) ||
      (contemplatioAudio?.isNotEmpty ?? false) ||
      (actioAudio?.isNotEmpty ?? false);
}

// Štatistiky adorácií
class AdorationStats {
  final int totalCount;
  final int withAudio;
  final int withImages;

  const AdorationStats({
    required this.totalCount,
    required this.withAudio,
    required this.withImages,
  });
}

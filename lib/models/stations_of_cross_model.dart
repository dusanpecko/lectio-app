// lib/models/stations_of_cross_model.dart

/// Model pre Krížovú cestu (Stations of the Cross)
class StationsOfCross {
  final String id;
  final String lang;
  final String title; // nazov
  final String? subtitle; // podnazov
  final String? author; // autor
  final String? illustrationImage; // ilustracny_obrazok
  final bool published; // publikovane
  final int order; // poradie
  final DateTime createdAt;
  final DateTime updatedAt;

  // Zastavenia (ak boli načítané)
  final List<Station> stations;

  const StationsOfCross({
    required this.id,
    required this.lang,
    required this.title,
    this.subtitle,
    this.author,
    this.illustrationImage,
    required this.published,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.stations = const [],
  });

  factory StationsOfCross.fromJson(Map<String, dynamic> json) {
    final stationsJson = json['krizove_cesty_zastavenia'];
    List<Station> stations = [];
    if (stationsJson is List) {
      stations =
          stationsJson
              .map<Station>((s) => Station.fromJson(s as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
    }

    return StationsOfCross(
      id: json['id'].toString(),
      lang: json['lang']?.toString() ?? 'en',
      title: json['nazov']?.toString() ?? '',
      subtitle: json['podnazov']?.toString(),
      author: json['autor']?.toString(),
      illustrationImage: json['ilustracny_obrazok']?.toString(),
      published: _parseBoolSafely(json['publikovane']) ?? true,
      order: _parseIntSafely(json['poradie']) ?? 0,
      createdAt: _parseDateSafely(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateSafely(json['updated_at']) ?? DateTime.now(),
      stations: stations,
    );
  }

  bool get hasImage =>
      illustrationImage != null && illustrationImage!.isNotEmpty;

  int get stationsWithAudioCount => stations.where((s) => s.hasAudio).length;

  int get stationsWithTextCount => stations.where((s) => s.hasText).length;

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
    if (value is int) return value != 0;
    return null;
  }

  static DateTime? _parseDateSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Model pre jedno zastavenie
class Station {
  final String id;
  final String krizovaCestaId;
  final String type; // typ: 'uvod', 'zastavenie', 'zaver'
  final int order; // poradie: 0=úvod, 1-14=zastavenia, 15=záver
  final String title; // nazov
  final String content; // text_obsah (HTML)
  final String? image; // obrazok
  final String? audio; // audio URL
  final DateTime createdAt;
  final DateTime updatedAt;

  const Station({
    required this.id,
    required this.krizovaCestaId,
    required this.type,
    required this.order,
    required this.title,
    required this.content,
    this.image,
    this.audio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'].toString(),
      krizovaCestaId: json['krizova_cesta_id']?.toString() ?? '',
      type: json['typ']?.toString() ?? 'zastavenie',
      order: (json['poradie'] is int)
          ? json['poradie'] as int
          : int.tryParse(json['poradie']?.toString() ?? '0') ?? 0,
      title: json['nazov']?.toString() ?? '',
      content: json['text_obsah']?.toString() ?? '',
      image: json['obrazok']?.toString(),
      audio: json['audio']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get hasAudio => audio != null && audio!.isNotEmpty;
  bool get hasText => content.isNotEmpty && content != '<p></p>';
  bool get hasImage => image != null && image!.isNotEmpty;

  bool get isIntro => type == 'uvod';
  bool get isConclusion => type == 'zaver';
  bool get isStation => type == 'zastavenie';

  /// Rímske číslo pre zastavenie
  String get romanNumeral {
    if (isIntro || isConclusion) return '';
    const romans = [
      '',
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
      'XIII',
      'XIV',
    ];
    if (order >= 1 && order <= 14) return romans[order];
    return order.toString();
  }
}

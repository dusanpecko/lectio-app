import 'package:flutter/material.dart';

/// Model pre audio stopu v Lectio Divina
class LectioAudioTrack {
  final String key;
  final String label;
  final String url;
  final IconData icon;
  final Color color;

  /// Lokálna cesta k stiahnutému súboru (null ak nie je stiahnuté)
  final String? localPath;

  const LectioAudioTrack({
    required this.key,
    required this.label,
    required this.url,
    required this.icon,
    required this.color,
    this.localPath,
  });

  /// Či je audio dostupné offline
  bool get isDownloaded => localPath != null;

  /// Efektívna URL/cesta pre prehrávanie - preferuje lokálny súbor
  String get effectiveUrl => localPath ?? url;

  /// Konverzia na Map pre spätnú kompatibilitu
  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'url': url,
    'icon': icon,
    'color': color,
    'localPath': localPath,
  };

  /// Vytvorenie z Map
  factory LectioAudioTrack.fromMap(Map<String, dynamic> map) {
    return LectioAudioTrack(
      key: map['key'] as String,
      label: map['label'] as String,
      url: map['url'] as String,
      icon: map['icon'] as IconData,
      color: map['color'] as Color,
      localPath: map['localPath'] as String?,
    );
  }

  /// Kópia s lokálnou cestou
  LectioAudioTrack copyWithLocalPath(String? localPath) {
    return LectioAudioTrack(
      key: key,
      label: label,
      url: url,
      icon: icon,
      color: color,
      localPath: localPath,
    );
  }
}

/// Helper trieda pre generovanie audio tracks z lectio dát
class LectioAudioTracksBuilder {
  final Map<String, dynamic> lectioData;
  final String selectedBible;
  final String languageCode;

  LectioAudioTracksBuilder({
    required this.lectioData,
    required this.selectedBible,
    required this.languageCode,
  });

  /// Vygeneruje zoznam dostupných audio stôp
  List<LectioAudioTrack> build() {
    final tracks = <LectioAudioTrack>[];

    // Modlitba audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'modlitba_audio',
      label: languageCode == 'sk' ? 'Modlitba' : 'Prayer',
      icon: Icons.favorite,
      color: Colors.red,
    );

    // Bible audio
    final bibleNumber = _extractBibleNumber();
    final bibleAudioKey = 'biblia_${bibleNumber}_audio';
    final nazovKey = 'nazov_biblia_$bibleNumber';

    _addTrackIfExists(
      tracks: tracks,
      dataKey: bibleAudioKey,
      label:
          lectioData[nazovKey] as String? ??
          (languageCode == 'sk' ? 'Biblický text' : 'Biblical text'),
      icon: Icons.menu_book,
      color: Colors.purple,
    );

    // Lectio audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'lectio_audio',
      label: 'Lectio',
      icon: Icons.book_outlined,
      color: Colors.green,
    );

    // Meditatio audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'meditatio_audio',
      label: 'Meditatio',
      icon: Icons.visibility_outlined,
      color: Colors.purple.shade700,
    );

    // Oratio audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'oratio_audio',
      label: 'Oratio',
      icon: Icons.favorite_border,
      color: Colors.orange,
    );

    // Contemplatio audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'contemplatio_audio',
      label: 'Contemplatio',
      icon: Icons.chat_bubble_outline,
      color: Colors.pink,
    );

    // Actio audio
    _addTrackIfExists(
      tracks: tracks,
      dataKey: 'actio_audio',
      label: 'Actio',
      icon: Icons.play_arrow,
      color: Colors.teal,
    );

    return tracks;
  }

  /// Extrahuje číslo biblie z selectedBible stringu
  String _extractBibleNumber() {
    if (selectedBible.startsWith('bible_en_')) {
      return selectedBible.replaceAll('bible_en_', '');
    }
    return selectedBible.replaceAll('biblia', '');
  }

  /// Pridá stopu ak existuje v dátach
  void _addTrackIfExists({
    required List<LectioAudioTrack> tracks,
    required String dataKey,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final url = lectioData[dataKey];
    if (url != null && url.toString().isNotEmpty) {
      tracks.add(
        LectioAudioTrack(
          key: dataKey,
          label: label,
          url: url.toString(),
          icon: icon,
          color: color,
        ),
      );
    }
  }
}

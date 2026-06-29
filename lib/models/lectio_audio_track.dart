import 'package:easy_localization/easy_localization.dart';
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
      label: tr('prayer'),
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
      label: lectioData[nazovKey] as String? ?? tr('section_title_bible'),
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
    // Najprv migrujeme hodnotu na nový formát
    final migrated = _migrateBibleValue(selectedBible);

    // Teraz máme určite biblia_1, biblia_2 alebo biblia_3
    if (migrated.startsWith('biblia_')) {
      return migrated.replaceAll('biblia_', '');
    }

    // Fallback
    return '1';
  }

  /// Migruje starú hodnotu na nový formát (biblia_1, biblia_2, biblia_3)
  String _migrateBibleValue(String oldValue) {
    // Ak je už v správnom formáte, vráť ho
    if (oldValue == 'biblia_1' ||
        oldValue == 'biblia_2' ||
        oldValue == 'biblia_3') {
      return oldValue;
    }

    // Migrácia zo starých formátov
    switch (oldValue.toLowerCase()) {
      // Starý formát bez podčiarkovníka
      case 'biblia1':
      case 'bible_en_1':
        return 'biblia_1';

      case 'biblia2':
      case 'bible_en_2':
        return 'biblia_2';

      case 'biblia3':
      case 'bible_en_3':
        return 'biblia_3';

      // Databázové kódy
      case 'ssv':
      case 'standardny':
        return 'biblia_1';

      case 'jeruzalemsky':
      case 'jeruzalem':
        return 'biblia_2';

      case 'ekumenicky':
      case 'ekumen':
        return 'biblia_3';

      default:
        // Fallback na prvú bibliu
        return 'biblia_1';
    }
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

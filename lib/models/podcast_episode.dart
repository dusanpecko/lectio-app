/// Jedna podcast epizóda z tabuľky `podcast_episodes` (generovaná v Next.js
/// backende a publikovaná do RSS feedu pre Spotify/Apple).
///
/// Na home obrazovke zobrazujeme „dnešnú" = najnovšiu `ready` epizódu pre daný
/// jazyk s `publish_date <= dnes` (zhodné s logikou verejného RSS feedu).
class PodcastEpisode {
  final String id;
  final String lang;
  final String? audioUrl;
  final int? durationSeconds;
  final String? title;
  final String? description;
  final String? publishDate;
  final int? episodeNumber;
  final String? coverImageUrl;

  /// Kombinované „celé Lectio" audio z `lectio_sources` (pripojené pri načítaní
  /// epizódy). V appke sa namiesto podcastu prehráva práve tento súbor — podcast
  /// ostáva len na Spotify. Dlhé = s hudbou + výzvou; krátke = len kroky.
  final String? fullLongAudio;
  final String? fullShortAudio;

  const PodcastEpisode({
    required this.id,
    required this.lang,
    this.audioUrl,
    this.durationSeconds,
    this.title,
    this.description,
    this.publishDate,
    this.episodeNumber,
    this.coverImageUrl,
    this.fullLongAudio,
    this.fullShortAudio,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) {
    return PodcastEpisode(
      id: json['id'].toString(),
      lang: (json['lang'] as String?) ?? '',
      audioUrl: json['audio_url'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      publishDate: json['publish_date'] as String?,
      episodeNumber: (json['episode_number'] as num?)?.toInt(),
      coverImageUrl: json['cover_image_url'] as String?,
      fullLongAudio: json['full_long_audio'] as String?,
      fullShortAudio: json['full_short_audio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lang': lang,
        'audio_url': audioUrl,
        'duration_seconds': durationSeconds,
        'title': title,
        'description': description,
        'publish_date': publishDate,
        'episode_number': episodeNumber,
        'cover_image_url': coverImageUrl,
      };

  /// Čistý názov bez biblickej súradnice.
  ///
  /// Backend skladá `title = "hlava — súradnice"`; pre zobrazenie chceme len
  /// hlavu (liturgický deň). Súradnicu vraciame zvlášť cez [displaySubtitle].
  String get displayTitle {
    final t = (title ?? '').trim();
    if (t.isEmpty) return '';
    final i = t.indexOf(' — ');
    return i != -1 ? t.substring(0, i).trim() : t;
  }

  /// Podnadpis = biblická súradnica / referencia (bez duplicity s názvom a bez
  /// CTA riadku „…lectio.one"). `null` ak nič zmysluplné nie je.
  String? get displaySubtitle {
    // 1) Súradnica z titulu "hlava — súradnica".
    final t = (title ?? '');
    final i = t.indexOf(' — ');
    if (i != -1) {
      final ref = t.substring(i + 3).trim();
      if (ref.isNotEmpty) return ref;
    }
    // 2) Prvý zmysluplný riadok z description (preskoč hlavu a CTA).
    final desc = description;
    if (desc != null) {
      final main = displayTitle.toLowerCase();
      for (final raw in desc.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (line.toLowerCase() == main) continue;
        if (line.toLowerCase().contains('lectio.one')) continue;
        return line;
      }
    }
    return null;
  }

  Duration get duration => Duration(seconds: durationSeconds ?? 0);

  /// Zaokrúhlená dĺžka v minútach pre meta „8 min" (min. 1 ak je audio).
  int get durationMinutes {
    final s = durationSeconds ?? 0;
    if (s <= 0) return 0;
    final m = (s / 60).round();
    return m < 1 ? 1 : m;
  }

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
}

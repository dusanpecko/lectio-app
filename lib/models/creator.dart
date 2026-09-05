// Modely pre sekciu „Tvorcovia" (Creator Studio) v appke.
// Dáta prichádzajú z verejného API `/api/creator-content/*` (jeden zdroj pravdy
// so subdoménovými stránkami — appka nerieši gate-logiku pobožností sama).

import 'package:easy_localization/easy_localization.dart';

String? _opt(dynamic v) {
  final s = v?.toString();
  return (s != null && s.isNotEmpty) ? s : null;
}

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dbl(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Počty publikovaného obsahu tvorcu (pre dlaždicu v adresári).
class CreatorCounts {
  final int series, novenas, adorations, stations, rosaries, podcasts, total;
  const CreatorCounts({
    this.series = 0, this.novenas = 0, this.adorations = 0,
    this.stations = 0, this.rosaries = 0, this.podcasts = 0, this.total = 0,
  });

  factory CreatorCounts.fromJson(Map<String, dynamic> j) => CreatorCounts(
    series: _int(j['series']), novenas: _int(j['novenas']), adorations: _int(j['adorations']),
    stations: _int(j['stations']), rosaries: _int(j['rosaries']), podcasts: _int(j['podcasts']),
    total: _int(j['total']),
  );
}

/// Položka adresára tvorcov (`/api/creator-content/creators`).
class CreatorSummary {
  final String id;
  final String slug;
  final String type; // 'individual' | 'organization'
  final String displayName;
  final String? title;
  final String? photoUrl;
  final String accent; // hex #RRGGBB
  final CreatorCounts counts;

  const CreatorSummary({
    required this.id, required this.slug, required this.type, required this.displayName,
    this.title, this.photoUrl, this.accent = '#4A5085', required this.counts,
  });

  factory CreatorSummary.fromJson(Map<String, dynamic> j) => CreatorSummary(
    id: j['id']?.toString() ?? '',
    slug: j['slug']?.toString() ?? '',
    type: j['type']?.toString() ?? 'individual',
    displayName: j['display_name']?.toString() ?? '',
    title: _opt(j['title']),
    photoUrl: _opt(j['photo_url']),
    accent: _opt(j['accent']) ?? '#4A5085',
    counts: CreatorCounts.fromJson((j['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
  );
}

/// Profil tvorcu v detaile (`/api/creator-content/creator/[slug]`).
class CreatorProfileDetail {
  final String id, slug, type, displayName;
  final String? title, bio, photoUrl;
  final String accent;
  final Map<String, String> links;
  final int followerCount;

  const CreatorProfileDetail({
    required this.id, required this.slug, required this.type, required this.displayName,
    this.title, this.bio, this.photoUrl, this.accent = '#4A5085', this.links = const {},
    this.followerCount = 0,
  });

  factory CreatorProfileDetail.fromJson(Map<String, dynamic> j) {
    final rawLinks = (j['links'] as Map?)?.cast<String, dynamic>() ?? const {};
    final links = <String, String>{};
    rawLinks.forEach((k, v) { final s = v?.toString(); if (s != null && s.isNotEmpty) links[k] = s; });
    return CreatorProfileDetail(
      id: j['id']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
      type: j['type']?.toString() ?? 'individual',
      displayName: j['display_name']?.toString() ?? '',
      title: _opt(j['title']),
      bio: _opt(j['bio']),
      photoUrl: _opt(j['photo_url']),
      accent: _opt(j['accent']) ?? '#4A5085',
      links: links,
      followerCount: _int(j['follower_count']),
    );
  }
}

/// Kolekcia (kanál) tvorcu.
class CreatorCollection {
  final String id, name, slug;
  final int displayOrder;
  const CreatorCollection({required this.id, required this.name, required this.slug, this.displayOrder = 0});

  factory CreatorCollection.fromJson(Map<String, dynamic> j) => CreatorCollection(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    slug: j['slug']?.toString() ?? '',
    displayOrder: _int(j['display_order']),
  );
}

/// Druh obsahovej položky tvorcu — určuje, kam sa naviguje pri kliknutí.
enum CreatorItemKind { series, novena, adoration, station, rosary, podcast, exercise }

/// Jednotná obsahová položka (karta) v detaile tvorcu. `refId` je identifikátor
/// pre detailovú obrazovku (séria=slug, deviatnik=shortcode, ostatné=id).
class CreatorContentItem {
  final CreatorItemKind kind;
  final String id;
  final String refId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? collectionId; // len pri sériách
  /// Tvorca, ktorému položka patrí. Vypĺňa sa v adresári (`/discover`), kde sú
  /// vedľa seba položky viacerých tvorcov a karta k nim musí nájsť meno,
  /// akcentovú farbu aj slug pre navigáciu. V detaile jedného tvorcu je `null`
  /// — tam je tvorca známy z obrazovky.
  final String? ownerProfileId;
  // Len pri podcastoch — odkazy na kanál (Spotify/Apple/YouTube/RSS).
  final String? spotifyUrl, appleUrl, youtubeUrl, rssUrl;

  const CreatorContentItem({
    required this.kind, required this.id, required this.refId,
    required this.title, this.subtitle, this.imageUrl, this.collectionId,
    this.ownerProfileId,
    this.spotifyUrl, this.appleUrl, this.youtubeUrl, this.rssUrl,
  });

  factory CreatorContentItem.series(Map<String, dynamic> j) {
    final sessions = _int(j['total_sessions']);
    return CreatorContentItem(
      kind: CreatorItemKind.series,
      id: j['id']?.toString() ?? '',
      refId: j['slug']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      subtitle: sessions > 0
          ? tr('creator_series_parts', namedArgs: {'count': '$sessions'})
          : _opt(j['description']),
      imageUrl: _opt(j['image_url']),
      collectionId: _opt(j['collection_id']),
      ownerProfileId: _opt(j['owner_profile_id']),
    );
  }

  factory CreatorContentItem.novena(Map<String, dynamic> j) {
    final days = ((j['novena_days'] as List?) ?? const []);
    final count = days.isNotEmpty ? _int((days.first as Map)['count']) : 0;
    return CreatorContentItem(
      kind: CreatorItemKind.novena,
      id: j['id']?.toString() ?? '',
      refId: j['shortcode']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      subtitle: count > 0 ? '$count dní' : _opt(j['description']),
      imageUrl: _opt(j['image_url']),
      ownerProfileId: _opt(j['owner_profile_id']),
    );
  }

  factory CreatorContentItem.adoration(Map<String, dynamic> j) => CreatorContentItem(
    kind: CreatorItemKind.adoration,
    id: j['id']?.toString() ?? '',
    refId: j['id']?.toString() ?? '',
    title: j['nazov']?.toString() ?? '',
    subtitle: _opt(j['biblicky_text']),
    imageUrl: _opt(j['ilustracny_obrazok']),
    ownerProfileId: _opt(j['owner_profile_id']),
  );

  factory CreatorContentItem.station(Map<String, dynamic> j) => CreatorContentItem(
    kind: CreatorItemKind.station,
    id: j['id']?.toString() ?? '',
    refId: j['id']?.toString() ?? '',
    title: j['nazov']?.toString() ?? '',
    subtitle: _opt(j['podnazov']),
    imageUrl: _opt(j['ilustracny_obrazok']),
    ownerProfileId: _opt(j['owner_profile_id']),
  );

  factory CreatorContentItem.rosary(Map<String, dynamic> j) => CreatorContentItem(
    kind: CreatorItemKind.rosary,
    id: j['id']?.toString() ?? '',
    refId: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    subtitle: _opt(j['description']) ?? _opt(j['category']),
    imageUrl: _opt(j['image_url']),
    ownerProfileId: _opt(j['owner_profile_id']),
  );

  factory CreatorContentItem.exercise(Map<String, dynamic> j) => CreatorContentItem(
    kind: CreatorItemKind.exercise,
    id: j['id']?.toString() ?? '',
    refId: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    subtitle: _opt(j['location_city']) ?? _opt(j['description']),
    imageUrl: _opt(j['image_url']),
    ownerProfileId: _opt(j['owner_profile_id']),
  );

  factory CreatorContentItem.podcast(Map<String, dynamic> j) => CreatorContentItem(
    kind: CreatorItemKind.podcast,
    id: j['id']?.toString() ?? '',
    refId: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    subtitle: _opt(j['description']),
    imageUrl: _opt(j['image_url']),
    ownerProfileId: _opt(j['owner_profile_id']),
    spotifyUrl: _opt(j['spotify_url']),
    appleUrl: _opt(j['apple_url']),
    youtubeUrl: _opt(j['youtube_url']),
    rssUrl: _opt(j['rss_url']),
  );
}

/// Obsah adresára tvorcov (`/api/creator-content/discover`): všetci tvorcovia
/// a všetok ich publikovaný obsah v jazyku appky, po typoch.
///
/// Poradie sekcií určuje appka, nie server — je to otázka zobrazenia.
class CreatorFeed {
  final List<CreatorSummary> creators;
  final Map<CreatorItemKind, List<CreatorContentItem>> items;

  const CreatorFeed({this.creators = const [], this.items = const {}});

  bool get isEmpty => creators.isEmpty;

  factory CreatorFeed.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) make) =>
        ((j[key] as List?) ?? const [])
            .map((e) => make((e as Map).cast<String, dynamic>()))
            .toList();

    return CreatorFeed(
      creators: list('creators', CreatorSummary.fromJson),
      items: {
        CreatorItemKind.series: list('series', CreatorContentItem.series),
        CreatorItemKind.station: list('stations', CreatorContentItem.station),
        CreatorItemKind.novena: list('novenas', CreatorContentItem.novena),
        CreatorItemKind.rosary: list('rosaries', CreatorContentItem.rosary),
        CreatorItemKind.adoration: list('adorations', CreatorContentItem.adoration),
        CreatorItemKind.podcast: list('podcasts', CreatorContentItem.podcast),
        CreatorItemKind.exercise: list('exercises', CreatorContentItem.exercise),
      },
    );
  }
}

/// Desiatok ruženca (zamyslenie + voliteľné audio).
class RosaryDecade {
  final int number;
  final String? title;
  final String content;
  final String? audioUrl;
  const RosaryDecade({required this.number, this.title, this.content = '', this.audioUrl});

  factory RosaryDecade.fromJson(Map<String, dynamic> j) => RosaryDecade(
    number: _int(j['decade_number']),
    title: _opt(j['title']),
    content: j['content']?.toString() ?? '',
    audioUrl: _opt(j['audio_url']),
  );
}

/// Detail ruženca tvorcu — úvod + desiatky + záver + audio celého ruženca.
class CreatorRosaryDetail {
  final String id;
  final String title;
  final String? category, categoryLabel, lang, author, description, imageUrl;
  final String? introTitle, introContent, introAudioUrl;
  final String? conclusionTitle, conclusionContent, conclusionAudioUrl;
  final String? fullAudioUrl;
  final List<RosaryDecade> decades;
  const CreatorRosaryDetail({
    required this.id, required this.title, this.category, this.categoryLabel, this.lang,
    this.author, this.description, this.imageUrl,
    this.introTitle, this.introContent, this.introAudioUrl,
    this.conclusionTitle, this.conclusionContent, this.conclusionAudioUrl,
    this.fullAudioUrl, this.decades = const [],
  });

  factory CreatorRosaryDetail.fromJson(Map<String, dynamic> j) {
    final r = (j['rosary'] as Map).cast<String, dynamic>();
    return CreatorRosaryDetail(
      id: r['id']?.toString() ?? '',
      title: r['title']?.toString() ?? '',
      category: _opt(r['category']),
      categoryLabel: _opt(r['category_label']),
      lang: _opt(r['lang']),
      author: _opt(r['author']),
      description: _opt(r['description']),
      imageUrl: _opt(r['image_url']),
      introTitle: _opt(r['intro_title']),
      introContent: _opt(r['intro_content']),
      introAudioUrl: _opt(r['intro_audio_url']),
      conclusionTitle: _opt(r['conclusion_title']),
      conclusionContent: _opt(r['conclusion_content']),
      conclusionAudioUrl: _opt(r['conclusion_audio_url']),
      fullAudioUrl: _opt(r['full_audio_url']),
      decades: ((j['decades'] as List?) ?? const [])
          .map((e) => RosaryDecade.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

/// Epizóda podcastu tvorcu (z RSS, parsuje backend).
class PodcastEpisodeItem {
  final String title;
  final String? description;
  final String audioUrl;
  final String? pubDate;
  final String? duration;
  final String? image;
  const PodcastEpisodeItem({
    required this.title, this.description, required this.audioUrl,
    this.pubDate, this.duration, this.image,
  });

  factory PodcastEpisodeItem.fromJson(Map<String, dynamic> j) => PodcastEpisodeItem(
    title: j['title']?.toString() ?? '',
    description: _opt(j['description']),
    audioUrl: j['audioUrl']?.toString() ?? '',
    pubDate: _opt(j['pubDate']),
    duration: _opt(j['duration']),
    image: _opt(j['image']),
  );
}

/// Jedno médium časti série (text=HTML, video/audio/image = URL v `content`).
class CreatorMedia {
  final String type; // 'text' | 'video' | 'audio' | 'image' | 'slide' | 'bible' | 'question' | 'prayer'
  final String? title;
  final String? content;
  /// Slide: obrázok karty (text je v [content]).
  final String? imageUrl;
  /// Slide: '9:16' na výšku (telefón) alebo '16:9' na šírku (projektor).
  final String aspectRatio;
  /// Biblia: referencia („Jn 3, 16") — vypisuje sa pod citátom.
  /// Modlitba: shortcode z knižnice (v appke sa nezobrazuje).
  final String? sourceRef;
  const CreatorMedia({
    required this.type, this.title, this.content, this.imageUrl,
    this.aspectRatio = '9:16', this.sourceRef,
  });

  factory CreatorMedia.fromJson(Map<String, dynamic> j) => CreatorMedia(
    type: j['type']?.toString() ?? 'text',
    title: _opt(j['title']),
    content: _opt(j['content']),
    imageUrl: _opt(j['image_url']),
    aspectRatio: _opt(j['aspect_ratio']) ?? '9:16',
    sourceRef: _opt(j['source_ref']),
  );

  bool get isSlide => type == 'slide';
  /// Bloky, ktoré sa vykresľujú ako formátovaný text (nie médiá s URL).
  bool get isProse => type == 'text' || type == 'bible' || type == 'question' || type == 'prayer';
  /// Pomer šírka/výška pre [AspectRatio] widget.
  double get slideAspect => aspectRatio == '16:9' ? 16 / 9 : 9 / 16;
}

/// Časť série (session) + jej médiá.
class CreatorSession {
  final String id;
  final int order;
  final String title;
  final String? description;
  final int? durationMinutes;
  final String? imageUrl;
  final List<CreatorMedia> media;
  const CreatorSession({
    required this.id, required this.order, required this.title,
    this.description, this.durationMinutes, this.imageUrl, this.media = const [],
  });

  factory CreatorSession.fromJson(Map<String, dynamic> j) => CreatorSession(
    id: j['id']?.toString() ?? '',
    order: _int(j['order']),
    title: j['title']?.toString() ?? '',
    description: _opt(j['description']),
    durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
    imageUrl: _opt(j['image_url']),
    media: ((j['media'] as List?) ?? const [])
        .map((e) => CreatorMedia.fromJson((e as Map).cast<String, dynamic>())).toList(),
  );
}

/// Kompletný detail série (program + časti + médiá).
class CreatorSeriesDetail {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? author;
  final List<CreatorSession> sessions;
  const CreatorSeriesDetail({
    required this.id, required this.title, this.description, this.imageUrl,
    this.author, this.sessions = const [],
  });

  factory CreatorSeriesDetail.fromJson(Map<String, dynamic> j) {
    final s = (j['series'] as Map).cast<String, dynamic>();
    return CreatorSeriesDetail(
      id: s['id']?.toString() ?? '',
      title: s['title']?.toString() ?? '',
      description: _opt(s['description']),
      imageUrl: _opt(s['image_url']),
      author: _opt(s['author']),
      sessions: ((j['sessions'] as List?) ?? const [])
          .map((e) => CreatorSession.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

/// Kompletný balík tvorcu pre detailovú obrazovku.
class CreatorBundle {
  final CreatorProfileDetail creator;
  final List<CreatorCollection> collections;
  final List<CreatorContentItem> series;
  final List<CreatorContentItem> novenas;
  final List<CreatorContentItem> adorations;
  final List<CreatorContentItem> stations;
  final List<CreatorContentItem> rosaries;
  final List<CreatorContentItem> podcasts;
  final List<CreatorContentItem> exercises;

  const CreatorBundle({
    required this.creator, this.collections = const [],
    this.series = const [], this.novenas = const [], this.adorations = const [],
    this.stations = const [], this.rosaries = const [], this.podcasts = const [],
    this.exercises = const [],
  });

  bool get isEmpty =>
      series.isEmpty && novenas.isEmpty && adorations.isEmpty &&
      stations.isEmpty && rosaries.isEmpty && podcasts.isEmpty && exercises.isEmpty;

  static List<CreatorContentItem> _list(dynamic arr, CreatorContentItem Function(Map<String, dynamic>) f) =>
      ((arr as List?) ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();

  factory CreatorBundle.fromJson(Map<String, dynamic> j) => CreatorBundle(
    creator: CreatorProfileDetail.fromJson((j['creator'] as Map).cast<String, dynamic>()),
    collections: ((j['collections'] as List?) ?? const [])
        .map((e) => CreatorCollection.fromJson((e as Map).cast<String, dynamic>())).toList(),
    series: _list(j['series'], CreatorContentItem.series),
    novenas: _list(j['novenas'], CreatorContentItem.novena),
    adorations: _list(j['adorations'], CreatorContentItem.adoration),
    stations: _list(j['stations'], CreatorContentItem.station),
    rosaries: _list(j['rosaries'], CreatorContentItem.rosary),
    podcasts: _list(j['podcasts'], CreatorContentItem.podcast),
    exercises: _list(j['exercises'], CreatorContentItem.exercise),
  );
}

/// Cena za typ izby duchovného cvičenia.
class ExercisePrice {
  final String roomType;
  final double price;
  final double? deposit;
  final String? description;
  const ExercisePrice({required this.roomType, required this.price, this.deposit, this.description});

  factory ExercisePrice.fromJson(Map<String, dynamic> j) => ExercisePrice(
    roomType: j['room_type']?.toString() ?? '',
    price: _dbl(j['price']) ?? 0,
    deposit: _dbl(j['deposit']),
    description: _opt(j['description']),
  );
}

/// Ohlas účastníka duchovného cvičenia.
class ExerciseTestimonial {
  final String authorName;
  final String testimonialText;
  final int? rating;
  const ExerciseTestimonial({required this.authorName, required this.testimonialText, this.rating});

  factory ExerciseTestimonial.fromJson(Map<String, dynamic> j) => ExerciseTestimonial(
    authorName: j['author_name']?.toString() ?? '',
    testimonialText: j['testimonial_text']?.toString() ?? '',
    rating: (j['rating'] as num?)?.toInt(),
  );
}

/// Konfigurácia poľa prihlášky (viditeľnosť / povinnosť) z `form_config`.
class ExerciseFieldCfg {
  final bool visible;
  final bool required;
  const ExerciseFieldCfg({this.visible = true, this.required = false});

  factory ExerciseFieldCfg.fromJson(Map<String, dynamic> j) => ExerciseFieldCfg(
    visible: j['visible'] != false,
    required: j['required'] == true,
  );
}

/// Detail duchovného cvičenia tvorcu (`/api/creator-content/exercise/[id]`)
/// vrátane údajov pre in-app prihlášku (form_config, platba, podmienky).
class CreatorExerciseDetail {
  final int id;
  final String title;
  final String? description, fullDescription, imageUrl;
  final String startDate, endDate; // ISO
  final String locationName;
  final String? locationAddress, locationCity, locationCountry;
  final String? leaderName, leaderBio, leaderPhoto;
  final int? maxCapacity, currentRegistrations;
  final bool paymentBank, paymentOnsite;
  final String? bankDetails, termsText;
  final Map<String, ExerciseFieldCfg> formConfig;
  final List<ExercisePrice> pricing;
  final List<ExerciseTestimonial> testimonials;
  final String organizerName;

  const CreatorExerciseDetail({
    required this.id, required this.title, this.description, this.fullDescription,
    this.imageUrl, required this.startDate, required this.endDate, required this.locationName,
    this.locationAddress, this.locationCity, this.locationCountry,
    this.leaderName, this.leaderBio, this.leaderPhoto, this.maxCapacity, this.currentRegistrations,
    this.paymentBank = false, this.paymentOnsite = false, this.bankDetails, this.termsText,
    this.formConfig = const {}, this.pricing = const [], this.testimonials = const [], this.organizerName = '',
  });

  bool get isFull =>
      maxCapacity != null && (currentRegistrations ?? 0) >= maxCapacity!;

  factory CreatorExerciseDetail.fromJson(Map<String, dynamic> j) {
    final cfgRaw = (j['form_config'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cfg = <String, ExerciseFieldCfg>{};
    cfgRaw.forEach((k, v) {
      if (v is Map) cfg[k] = ExerciseFieldCfg.fromJson(v.cast<String, dynamic>());
    });
    return CreatorExerciseDetail(
      id: _int(j['id']),
      title: j['title']?.toString() ?? '',
      description: _opt(j['description']),
      fullDescription: _opt(j['full_description']),
      imageUrl: _opt(j['image_url']),
      startDate: j['start_date']?.toString() ?? '',
      endDate: j['end_date']?.toString() ?? '',
      locationName: j['location_name']?.toString() ?? '',
      locationAddress: _opt(j['location_address']),
      locationCity: _opt(j['location_city']),
      locationCountry: _opt(j['location_country']),
      leaderName: _opt(j['leader_name']),
      leaderBio: _opt(j['leader_bio']),
      leaderPhoto: _opt(j['leader_photo']),
      maxCapacity: (j['max_capacity'] as num?)?.toInt(),
      currentRegistrations: (j['current_registrations'] as num?)?.toInt(),
      paymentBank: j['payment_bank'] == true,
      paymentOnsite: j['payment_onsite'] == true,
      bankDetails: _opt(j['bank_details']),
      termsText: _opt(j['terms_text']),
      formConfig: cfg,
      pricing: ((j['pricing'] as List?) ?? const [])
          .map((e) => ExercisePrice.fromJson((e as Map).cast<String, dynamic>())).toList(),
      testimonials: ((j['testimonials'] as List?) ?? const [])
          .map((e) => ExerciseTestimonial.fromJson((e as Map).cast<String, dynamic>())).toList(),
      organizerName: j['organizer_name']?.toString() ?? '',
    );
  }
}

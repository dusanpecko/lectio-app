import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/podcast_episode.dart';
import '../utils/app_logger.dart';

/// Čítanie podcast epizód z tabuľky `podcast_episodes`.
///
/// Dáta generuje Next.js backend a publikuje do RSS feedu
/// (`https://lectio.one/api/podcast/{lang}/feed.xml`). Mobil zobrazuje len
/// najnovšiu publikovanú epizódu pre aktuálny jazyk.
class PodcastService {
  PodcastService._();
  static final PodcastService instance = PodcastService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Kanálové (fallback) covery — zhodné s RSS feed configom v backende.
  static const Map<String, String> _channelCover = {
    'sk': 'https://lectio.one/podcast/SK_POD.jpg',
    'en': 'https://lectio.one/podcast/EN_POD.jpg',
    'es': 'https://lectio.one/podcast/ES_POD.jpg',
    'fr': 'https://lectio.one/podcast/FR_POD.jpg',
    'pt-br': 'https://lectio.one/podcast/PT_BR_POD.jpg',
  };

  /// Spotify show URL per jazyk. Pre jazyky bez URL sa tlačidlo skryje.
  /// TODO: doplniť EN/ES/FR/PT-BR keď Spotify schváli príslušné feedy.
  static const Map<String, String> _spotifyShowUrl = {
    'sk': 'https://open.spotify.com/show/033vvO8COOj7q5SOgkai0d',
  };

  /// Fallback cover pre daný jazyk (ak epizóda nemá vlastný `cover_image_url`).
  static String channelCover(String locale) =>
      _channelCover[locale] ?? _channelCover['sk']!;

  /// Spotify show URL alebo `null` ak pre daný jazyk zatiaľ neexistuje.
  static String? spotifyShowUrl(String locale) => _spotifyShowUrl[locale];

  /// Najnovšia publikovaná epizóda pre daný jazyk (= „dnešný" podcast).
  ///
  /// Filter zodpovedá verejnému RSS feedu: `status='ready'`
  /// a `publish_date <= dnes`, zoradené od najnovšej.
  Future<PodcastEpisode?> fetchTodaysEpisode(String locale) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final res = await _supabase
          .from('podcast_episodes')
          .select()
          .eq('lang', locale)
          .eq('status', 'ready')
          .lte('publish_date', today)
          .order('publish_date', ascending: false)
          // Pri prípadnej duplicite na deň vyhrá najnovšie vygenerovaná epizóda.
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        appLogger.d('🎧 Podcast: žiadna ready epizóda pre "$locale"');
        return null;
      }
      await _attachLectioVariants(res);
      final episode = PodcastEpisode.fromJson(res);
      appLogger.i('✅ Podcast: epizóda "${episode.title}" (${episode.publishDate})');
      return episode;
    } catch (e) {
      appLogger.e('❌ Podcast: chyba pri načítaní epizódy: $e');
      return null;
    }
  }

  /// Epizóda pre konkrétny deň (pre Lectio v2 — podcast k danej lekcii).
  Future<PodcastEpisode?> fetchEpisodeForDate(
    DateTime date,
    String locale,
  ) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    try {
      final res = await _supabase
          .from('podcast_episodes')
          .select()
          .eq('lang', locale)
          .eq('status', 'ready')
          .eq('publish_date', dateStr)
          // Pri prípadnej duplicite na deň vyhrá najnovšie vygenerovaná epizóda.
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      await _attachLectioVariants(res);
      return PodcastEpisode.fromJson(res);
    } catch (e) {
      appLogger.e('❌ Podcast: chyba pri načítaní epizódy pre $dateStr: $e');
      return null;
    }
  }

  /// Doplní k epizóde kombinované „celé Lectio" audio (`full_long_audio` /
  /// `full_short_audio`) z `lectio_sources` podľa `lectio_source_id`. V appke
  /// sa namiesto podcastu prehráva práve toto audio (podcast ostáva na Spotify).
  /// Best-effort — pri chybe necháme epizódu bez kombinovaného audia.
  Future<void> _attachLectioVariants(Map<String, dynamic> row) async {
    final sourceId = (row['lectio_source_id'] as num?)?.toInt();
    if (sourceId == null) return;
    try {
      final src = await _supabase
          .from('lectio_sources')
          .select('full_long_audio, full_short_audio')
          .eq('id', sourceId)
          .maybeSingle();
      if (src != null) {
        row['full_long_audio'] = src['full_long_audio'];
        row['full_short_audio'] = src['full_short_audio'];
      }
    } catch (e) {
      appLogger.d('🎧 Podcast: nepodarilo sa načítať lectio varianty: $e');
    }
  }
}

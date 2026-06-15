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
          .limit(1)
          .maybeSingle();

      if (res == null) {
        appLogger.d('🎧 Podcast: žiadna ready epizóda pre "$locale"');
        return null;
      }
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
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return PodcastEpisode.fromJson(res);
    } catch (e) {
      appLogger.e('❌ Podcast: chyba pri načítaní epizódy pre $dateStr: $e');
      return null;
    }
  }
}

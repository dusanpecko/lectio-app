import 'dart:async';
import 'audio_exclusive.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/app_logger.dart';
import 'audio_download_service.dart';
import 'lectio_audio_player.dart';
import 'app_activity_service.dart';
import 'umami_analytics_service.dart';
import '../shared/audio_constants.dart';

/// Jednotná audio zbernica pre v2 (denný podcast aj jednotlivé kroky lectio).
///
/// Používa JEDINÚ povolenú inštanciu [AudioPlayer] (zo singletonu
/// [LectioAudioPlayer]) — `just_audio_background` dovolí len jeden background
/// player, takže vlastné playery by spôsobili pád
/// ("supports only a single player instance"). Zdieľaním tej istej inštancie
/// to obídeme a zároveň sa NEaktivuje starý mini-player (ten reaguje len na
/// playlist `currentTrackKey`, ktorý priamym setAudioSource nenastavujeme).
class MediaPlayerBus extends ChangeNotifier {
  MediaPlayerBus._() {
    // Umami audio_heartbeat_2m — štart/stop podľa stavu prehrávania.
    _player.playingStream.listen((playing) {
      if (playing) {
        _beginSession();
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
    });
    // Najďalej dosiahnutá pozícia v relácii (pre `percent` v audio_finish).
    _player.positionStream.listen((p) {
      final s = _session;
      if (s != null && p > s.furthest) s.furthest = p;
    });
    // Dohrané = koniec relácie. Posledný úsek pripísať ešte pred ukončením
    // (stav už je completed, bežné pripisovanie by ho preskočilo).
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _creditListening(force: true);
        _endSession();
      }
    });
  }
  static final MediaPlayerBus instance = MediaPlayerBus._();

  AudioPlayer get _player => LectioAudioPlayer().player;

  String? _currentId;
  String? get currentId => _currentId;
  bool isCurrent(String id) => _currentId == id;

  /// Identifikátor obsahu aktuálneho média (pre Lectio = deň „yyyy-MM-dd").
  /// Slúži na zistenie, či hrá audio z iného dňa.
  String? get currentContentId => _contentId;

  // Analytics metadáta aktuálneho média.
  String? _contentType;
  String? _contentId;
  String _language = 'sk';
  Timer? _heartbeatTimer;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;

  /// Kombinovaný stav (playing + processingState) — UI z neho vie, že po
  /// dohraní má ukázať ▶ (just_audio necháva `playing=true` aj po completed).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  PlayerState get playerState => _player.playerState;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  Future<void> _setSource({
    required String id,
    required String url,
    required String title,
    String? artUri,
    String? contentType,
    String? contentId,
    String? language,
  }) async {
    _endSession(); // iné médium = koniec predošlej relácie
    _currentId = id;
    _contentType = contentType;
    _contentId = contentId;
    if (language != null) _language = language;
    // Ak je audio stiahnuté offline, prehraj lokálny súbor.
    await AudioDownloadService.instance.initialize();
    final localPath = AudioDownloadService.instance.getLocalPath(url);
    // Zmenši artwork pre media notifikáciu (nenačítavaj plné rozlíšenie do
    // pamäte — Google Play upozornenie na loadArtBitmap).
    final sizedArt = AudioConstants.sizedArtwork(artUri);
    final tag = MediaItem(
      id: id,
      title: title,
      artist: 'Lectio Divina',
      artUri: sizedArt != null ? Uri.tryParse(sizedArt) : null,
    );
    // Offline súbor → lokálne; inak stream s diskovou cache (LockCaching) —
    // seek a opakované prehratie sú potom okamžité.
    final AudioSource source = localPath != null
        ? AudioSource.uri(Uri.file(localPath), tag: tag)
        // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
        : LockCachingAudioSource(Uri.parse(url), tag: tag);
    // Výhradný slot natívneho playera (just_audio_background = 1 naraz).
    await AudioExclusive.acquire(_player);
    await _player.setAudioSource(source);
    notifyListeners();
  }

  /// Spustí / pozastaví médium s daným [id]. Pri zmene [id] načíta nový zdroj.
  /// [contentType]/[contentId]/[language] sa použijú pre Umami eventy.
  Future<void> toggle({
    required String id,
    required String url,
    String title = 'Lectio Divina',
    String? artUri,
    String? contentType,
    String? contentId,
    String? language,
  }) async {
    if (url.isEmpty) return;
    try {
      if (_currentId != id) {
        await _setSource(
          id: id,
          url: url,
          title: title,
          artUri: artUri,
          contentType: contentType,
          contentId: contentId,
          language: language,
        );
      }
      if (_player.playing &&
          _player.processingState != ProcessingState.completed) {
        await _player.pause();
      } else {
        await AudioExclusive.acquire(_player);
        // Po dohraní začni odznova — play() na konci by nič neurobil.
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        // Pri prepnutí média počas hrania `playing` nezmení stav → relácia
        // by sa nezačala. Pred play() (jeho Future končí až pri zastavení).
        _beginSession();
        await _player.play();
      }
    } catch (e) {
      appLogger.e('❌ MediaPlayerBus: $e');
    }
  }

  /// Vždy spustí (re-štartne) dané médium — pre kapitoly, dots, prev/next a
  /// automatické prehranie ďalšej kapitoly.
  Future<void> play({
    required String id,
    required String url,
    String title = 'Lectio Divina',
    String? artUri,
    String? contentType,
    String? contentId,
    String? language,
  }) async {
    if (url.isEmpty) return;
    try {
      if (_currentId != id) {
        await _setSource(
          id: id,
          url: url,
          title: title,
          artUri: artUri,
          contentType: contentType,
          contentId: contentId,
          language: language,
        );
      } else {
        await _player.seek(Duration.zero);
      }
      await AudioExclusive.acquire(_player);
      _beginSession();
      await _player.play();
    } catch (e) {
      appLogger.e('❌ MediaPlayerBus.play: $e');
    }
  }

  Future<void> seek(Duration position) async => _player.seek(position);

  /// Zastaví prehrávanie a zruší aktuálne médium. Ďalšie `toggle`/`play`
  /// (aj rovnaké id) tak začne od začiatku — používa sa pri prepnutí dňa v Lectio.
  Future<void> stop() async {
    try {
      await _player.pause();
    } catch (_) {
      // ignore
    }
    _endSession();
    _currentId = null;
    _contentId = null;
    notifyListeners();
  }

  // ── Umami audio_heartbeat_2m (každé 2 min počas prehrávania) ─────────────
  // Časovač tiká po 30 s kvôli _creditListening (strop 60 s na úsek), do
  // Umami ide len každý 4. tik a s minimom vlastností: Umami účtuje každú
  // vlastnosť ako ďalšiu udalosť — 30-s heartbeat so 4 vlastnosťami tvoril
  // ~2,3 mil. z 2,44 mil. účtovaných udalostí za 9–10/2026. Presný čas
  // počúvania nesie audio_finish (`seconds`); heartbeat je záloha pre
  // relácie, ktoré skončia zabitím appky.
  int _heartbeatTicks = 0;

  void _startHeartbeat() {
    if (_heartbeatTimer != null) return;
    _listenMark = DateTime.now();
    _heartbeatTicks = 0;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _creditListening();
      if (_contentType == null) return;
      if (++_heartbeatTicks % 4 != 0) return;
      UmamiAnalyticsService().trackEvent(
        'audio_heartbeat_2m',
        eventData: {'language': _language},
      );
    });
  }

  void _stopHeartbeat() {
    _creditListening();
    _listenMark = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Čas počúvania (11.2.5) → AppActivityService, oddelene od popredia ──────
  DateTime? _listenMark;

  /// Pripíše čas od poslednej značky. just_audio necháva `playing=true` aj po
  /// dohraní, preto sa ráta len stav ready/buffering; strop 60 s na jeden úsek
  /// (časovač mohol byť uspatý).
  void _creditListening({bool force = false}) {
    final mark = _listenMark;
    final now = DateTime.now();
    _listenMark = now;
    if (mark == null) return;
    final state = _player.processingState;
    if (!force &&
        state != ProcessingState.ready &&
        state != ProcessingState.buffering) {
      return;
    }
    final seconds = now.difference(mark).inSeconds.clamp(0, 60);
    AppActivityService.instance.addListenSeconds(seconds);
    _session?.listened += seconds;
  }

  // ── Umami audio_start / audio_finish (11.2.5) ──────────────────────────────
  // Relácia = jedno médium od prvého spustenia po dohranie, prepnutie na iné
  // médium, stop() alebo odchod z appky s pozastaveným audiom. Pauza reláciu
  // nekončí (človek pokračuje). Meria sa PERCENTO (najďalej dosiahnutá
  // pozícia), nie „dokončené áno/nie“: dĺžka závisí od variantu (dlhé s hudbou,
  // krátke) a kto prestane po Actio, modlitbu dokončil (Dušan 25. 9.).
  _ListenSession? _session;

  void _beginSession() {
    final id = _currentId;
    if (_session != null || id == null) return;
    final session = _ListenSession(
      variant: _variantOf(id, _contentType),
      contentType: _contentType ?? 'other',
      language: _language,
    );
    _session = session;
    UmamiAnalyticsService().trackEvent(
      'audio_start',
      eventData: {
        'variant': session.variant,
        'content_type': session.contentType,
        'language': session.language,
      },
    );
  }

  void _endSession() {
    final s = _session;
    _session = null;
    if (s == null) return;
    final total = _player.duration?.inSeconds ?? 0;
    final percent = total > 0
        ? (s.furthest.inSeconds * 100 / total).round().clamp(0, 100)
        : null;
    UmamiAnalyticsService().trackEvent(
      'audio_finish',
      eventData: {
        'variant': s.variant,
        'content_type': s.contentType,
        'language': s.language,
        'seconds': s.listened,
        'total_seconds': total,
        'percent': ?percent,
      },
    );
  }

  /// Appka odchádza do pozadia: ak audio nehrá (pauza / dohrané), relácia
  /// končí — inak by sa pri zatvorení appky stratila. Hrajúce audio na
  /// pozadí reláciu nekončí.
  void endSessionIfIdle() {
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      return;
    }
    _endSession();
  }

  /// Variant pre analytiku: `lectio_audio_<id>_<long|short>` → long/short,
  /// `podcast_<id>` → podcast, audio jedného kroku lectia (`*_audio`) → step,
  /// inak typ obsahu (rosary, news, …).
  static String _variantOf(String id, String? contentType) {
    if (id.startsWith('lectio_audio_')) return id.split('_').last;
    if (id.startsWith('podcast_')) return 'podcast';
    if (contentType == 'lectio' && id.endsWith('_audio')) return 'step';
    return contentType ?? 'other';
  }
}

class _ListenSession {
  _ListenSession({
    required this.variant,
    required this.contentType,
    required this.language,
  });
  final String variant;
  final String contentType;
  final String language;
  int listened = 0;
  Duration furthest = Duration.zero;
}

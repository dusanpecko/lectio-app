import 'dart:async';
import 'audio_exclusive.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/app_logger.dart';
import 'audio_download_service.dart';
import 'lectio_audio_player.dart';
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
    // Umami audio_heartbeat — štart/stop podľa stavu prehrávania.
    _player.playingStream.listen((playing) {
      if (playing) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
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
  /// [contentType]/[contentId]/[language] sa použijú pre Umami `audio_heartbeat`.
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
    _currentId = null;
    _contentId = null;
    notifyListeners();
  }

  // ── Umami audio_heartbeat (každých 30s počas prehrávania) ──────────────────
  void _startHeartbeat() {
    if (_heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_contentType == null) return;
      UmamiAnalyticsService().trackEvent(
        'audio_heartbeat',
        eventData: {
          'content_type': _contentType,
          'content_id': _contentId,
          'language': _language,
          'position_seconds': position.inSeconds,
        },
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}

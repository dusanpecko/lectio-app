import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/app_logger.dart';
import 'audio_download_service.dart';
import 'lectio_audio_player.dart';
import 'umami_analytics_service.dart';

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
        _currentId = id;
        _contentType = contentType;
        _contentId = contentId;
        if (language != null) _language = language;
        // Ak je audio stiahnuté offline, prehraj lokálny súbor.
        await AudioDownloadService.instance.initialize();
        final localPath = AudioDownloadService.instance.getLocalPath(url);
        final uri = localPath != null ? Uri.file(localPath) : Uri.parse(url);
        await _player.setAudioSource(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: id,
              title: title,
              artist: 'Lectio Divina',
              artUri: artUri != null ? Uri.tryParse(artUri) : null,
            ),
          ),
        );
        notifyListeners();
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      appLogger.e('❌ MediaPlayerBus: $e');
    }
  }

  Future<void> seek(Duration position) async => _player.seek(position);

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

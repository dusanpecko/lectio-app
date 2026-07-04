import 'package:just_audio/just_audio.dart';

/// Zdieľaná konfigurácia [AudioPlayer] pre celú appku — RÝCHLY SEEK na
/// streamovanom audiu (fix 5.7.2026: posun trval 4–5 s, kým sa audio pohlo).
///
/// Prečo bol seek pomalý (defaulty prehrávačov):
///  - **Android/ExoPlayer**: po seeku čaká, kým má nabuffrovaných 5 s
///    (`bufferForPlaybackAfterRebufferDuration`) — až potom začne hrať.
///  - **iOS/AVPlayer**: `automaticallyWaitsToMinimizeStalling` odkladá štart
///    prehrávania po skoku, kým si nevybuduje „bezpečný" buffer.
///
/// Toto nastavenie začne hrať takmer okamžite po doskoku range requestu
/// (~pod 1 s na bežnom pripojení) za cenu mierne vyššieho rizika krátkeho
/// dobuffrovania na veľmi pomalej sieti — rovnaký trade-off robí Spotify.
AudioPlayer createAppAudioPlayer() => AudioPlayer(
      audioLoadConfiguration: AudioLoadConfiguration(
        darwinLoadControl: DarwinLoadControl(
          automaticallyWaitsToMinimizeStalling: false,
        ),
        androidLoadControl: AndroidLoadControl(
          // Štart prehrávania už po ~0,75 s buffra (default 2,5 s)
          bufferForPlaybackDuration: const Duration(milliseconds: 750),
          // Po seeku/rebuffri stačí 1,5 s buffra (default 5 s) — kľúčový fix
          bufferForPlaybackAfterRebufferDuration:
              const Duration(milliseconds: 1500),
        ),
      ),
    );

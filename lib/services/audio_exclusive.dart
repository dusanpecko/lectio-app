import 'package:just_audio/just_audio.dart';

import '../utils/app_logger.dart';

/// Výhradný prístup k natívnemu audio playeru.
///
/// `just_audio_background` dovoľuje **len jeden aktívny natívny player
/// naraz** — druhý pokus o aktiváciu (setAudioSource/load/play) hodí
/// `PlatformException("supports only a single player instance")`. Appka má
/// pritom viac prehrávačov (lectio/bus, modlitby, krížové cesty, adorácie,
/// ruženec, deviatniky, spytovanie) a **pauza slot NEuvoľňuje** — len
/// `stop()`/`dispose()`.
///
/// Preto si každé miesto pred aktiváciou vyžiada slot cez [acquire]:
/// predchádzajúci držiteľ sa zastaví (uvoľní natívny player) a slot
/// preberá nový. Bez toho po prehratí lectio z domovskej obrazovky
/// nefungovalo žiadne ďalšie audio až do reštartu appky (7/2026).
class AudioExclusive {
  AudioExclusive._();

  static AudioPlayer? _holder;

  /// Zavolaj PRED `setAudioSource(s)`/`load`/`play` daného playera.
  /// Idempotentné — ak slot už drží tento player, nič sa nedeje.
  static Future<void> acquire(AudioPlayer player) async {
    if (identical(_holder, player)) return;
    final prev = _holder;
    _holder = player;
    if (prev != null) {
      try {
        // pause() nestačí — natívny player uvoľňuje až stop().
        await prev.stop();
      } catch (e) {
        appLogger.w('AudioExclusive: stop predchádzajúceho playera: $e');
      }
    }
  }

  /// Zavolaj v dispose() vlastníka playera — uprace referenciu.
  static void release(AudioPlayer player) {
    if (identical(_holder, player)) _holder = null;
  }

  /// Zastaví to, čo práve hrá, bez preberania slotu — pre neaudio prehrávače
  /// (in-app video), ktoré nie sú [AudioPlayer], ale nesmú hrať súčasne
  /// s audiom (napr. lectio z busu + video v časti série).
  static Future<void> stopCurrent() async {
    final prev = _holder;
    _holder = null;
    if (prev == null) return;
    try {
      await prev.stop();
    } catch (e) {
      appLogger.w('AudioExclusive: stopCurrent zlyhalo: $e');
    }
  }
}

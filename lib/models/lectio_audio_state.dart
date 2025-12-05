/// Enum pre hlavný stav audio prehrávania v Lectio screen
/// Nahrádza viacero boolean premenných jedným clear stavom
enum LectioPlaybackState {
  /// Žiadne audio sa neprehráva, player je neaktívny
  idle,

  /// Audio sa načítava (loading)
  loading,

  /// Audio sa prehráva
  playing,

  /// Audio je pozastavené
  paused,

  /// Audio bolo zastavené (stopped)
  stopped,

  /// Prebieha seekovanie - ignorujeme completion events
  seeking,

  /// Prehráva sa meditačná hudba medzi sekciami
  playingInterlude,

  /// Spracováva sa prechod z interlude na ďalší track
  processingInterludeTransition,

  /// Prehráva sa interlude (alias pre playingInterlude)
  interlude,

  /// Chyba pri prehrávaní
  error,

  /// Audio dokončené
  completed;

  /// Či je audio aktívne (prehráva sa alebo je pozastavené)
  bool get isActive =>
      this == playing ||
      this == paused ||
      this == playingInterlude ||
      this == seeking;

  /// Či sa niečo prehráva
  bool get isPlaying =>
      this == playing || this == playingInterlude || this == interlude;

  /// Či je v stave kde môžeme spustiť nové audio
  bool get canStartNew =>
      this == idle || this == stopped || this == completed || this == error;

  /// Či by sa mal zobrazovať loading indicator
  bool get showLoading =>
      this == loading || this == processingInterludeTransition;

  /// Či je v interlude móde
  bool get isInterlude =>
      this == playingInterlude ||
      this == interlude ||
      this == processingInterludeTransition;
}

/// Model pre kompletný stav audio v Lectio screen
class LectioAudioModel {
  /// Hlavný stav prehrávania
  final LectioPlaybackState playbackState;

  /// Aktuálna sekcia ktorá sa prehráva (key z tracks)
  final String? currentSection;

  /// Aktuálna pozícia v audio
  final Duration currentPosition;

  /// Celková dĺžka audio
  final Duration totalDuration;

  /// Režim meditačnej hudby: 'none', 'short', 'long'
  final String audioMode;

  /// Ďalší track po interlude (ak je nastavený)
  final Map<String, dynamic>? nextTrackAfterInterlude;

  /// Či používame fallback player (priamy AudioPlayer)
  final bool usingFallbackPlayer;

  /// Či je audio player UI viditeľný
  final bool isPlayerVisible;

  /// Či je player minimalizovaný
  final bool isMinimized;

  const LectioAudioModel({
    this.playbackState = LectioPlaybackState.idle,
    this.currentSection,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.audioMode = 'short',
    this.nextTrackAfterInterlude,
    this.usingFallbackPlayer = false,
    this.isPlayerVisible = false,
    this.isMinimized = false,
  });

  /// Počiatočný stav
  static const LectioAudioModel initial = LectioAudioModel();

  /// Vytvorí kópiu s novými hodnotami
  LectioAudioModel copyWith({
    LectioPlaybackState? playbackState,
    String? currentSection,
    Duration? currentPosition,
    Duration? totalDuration,
    String? audioMode,
    Map<String, dynamic>? nextTrackAfterInterlude,
    bool? clearNextTrack,
    bool? usingFallbackPlayer,
    bool? isPlayerVisible,
    bool? isMinimized,
  }) {
    return LectioAudioModel(
      playbackState: playbackState ?? this.playbackState,
      currentSection: currentSection ?? this.currentSection,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      audioMode: audioMode ?? this.audioMode,
      nextTrackAfterInterlude: clearNextTrack == true
          ? null
          : (nextTrackAfterInterlude ?? this.nextTrackAfterInterlude),
      usingFallbackPlayer: usingFallbackPlayer ?? this.usingFallbackPlayer,
      isPlayerVisible: isPlayerVisible ?? this.isPlayerVisible,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }

  /// Reset na počiatočný stav ale zachová audioMode
  LectioAudioModel reset() {
    return LectioAudioModel(
      audioMode: audioMode,
    );
  }

  /// Či môžeme reagovať na completion event
  bool get canHandleCompletion =>
      playbackState != LectioPlaybackState.seeking &&
      playbackState != LectioPlaybackState.processingInterludeTransition &&
      playbackState != LectioPlaybackState.idle;

  /// Progress ako double (0.0 - 1.0)
  double get progress {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    return (currentPosition.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Zostávajúci čas
  Duration get remaining => totalDuration - currentPosition;

  @override
  String toString() {
    return 'LectioAudioModel('
        'state: $playbackState, '
        'section: $currentSection, '
        'pos: ${currentPosition.inSeconds}s, '
        'dur: ${totalDuration.inSeconds}s, '
        'mode: $audioMode, '
        'fallback: $usingFallbackPlayer, '
        'visible: $isPlayerVisible, '
        'minimized: $isMinimized)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LectioAudioModel &&
        other.playbackState == playbackState &&
        other.currentSection == currentSection &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.audioMode == audioMode &&
        other.usingFallbackPlayer == usingFallbackPlayer &&
        other.isPlayerVisible == isPlayerVisible &&
        other.isMinimized == isMinimized;
  }

  @override
  int get hashCode {
    return Object.hash(
      playbackState,
      currentSection,
      currentPosition,
      totalDuration,
      audioMode,
      usingFallbackPlayer,
      isPlayerVisible,
      isMinimized,
    );
  }
}


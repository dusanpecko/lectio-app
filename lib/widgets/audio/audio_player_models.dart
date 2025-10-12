// widgets/audio/audio_player_models.dart

import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

/// Model pre audio položku - univerzálny pre rosary aj lectio
class UniversalAudioItem {
  final String? audioUrl;
  final String title;
  final String? author;
  final String? albumName;
  final String? artworkUrl;
  final String? id;
  final Duration? duration;

  const UniversalAudioItem({
    required this.audioUrl,
    required this.title,
    this.author,
    this.albumName,
    this.artworkUrl,
    this.id,
    this.duration,
  });

  /// Továrna pre rosary decade
  factory UniversalAudioItem.fromRosaryDecade({
    required String? audioUrl,
    required String title,
    required String? author,
    required String albumName,
    required String? artworkUrl,
    required String id,
  }) {
    return UniversalAudioItem(
      audioUrl: audioUrl,
      title: title,
      author: author ?? 'Ruženec',
      albumName: albumName,
      artworkUrl: artworkUrl,
      id: id,
    );
  }

  /// Továrna pre lectio item
  factory UniversalAudioItem.fromLectio({
    required String? audioUrl,
    required String title,
    required String? speaker,
    required String? artworkUrl,
    required String id,
  }) {
    return UniversalAudioItem(
      audioUrl: audioUrl,
      title: title,
      author: speaker ?? 'Lectio Divina',
      albumName: 'Lectio Divina',
      artworkUrl: artworkUrl,
      id: id,
    );
  }

  /// Konverzia na MediaItem pre audio service
  MediaItem toMediaItem() {
    return MediaItem(
      id: id ?? audioUrl ?? title,
      album: albumName ?? 'Duchovná aplikácia',
      title: title,
      artist: author ?? 'Neznámy autor',
      duration: duration,
      artUri: artworkUrl != null ? Uri.parse(artworkUrl!) : null,
      playable: audioUrl?.isNotEmpty == true,
    );
  }

  /// Má platnú audio URL
  bool get hasValidAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Má artwork/obrázok
  bool get hasArtwork => artworkUrl != null && artworkUrl!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UniversalAudioItem &&
        other.audioUrl == audioUrl &&
        other.title == title &&
        other.author == author &&
        other.id == id;
  }

  @override
  int get hashCode {
    return audioUrl.hashCode ^ title.hashCode ^ author.hashCode ^ id.hashCode;
  }

  @override
  String toString() {
    return 'UniversalAudioItem(title: $title, author: $author, hasAudio: $hasValidAudio)';
  }
}

/// Kombinované dáta pre position a duration streams
class AudioPositionData {
  final Duration position;
  final Duration duration;

  const AudioPositionData({required this.position, required this.duration});

  static const AudioPositionData zero = AudioPositionData(
    position: Duration.zero,
    duration: Duration.zero,
  );

  /// Progress ako double (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Zostávajúci čas
  Duration get remaining => duration - position;

  /// Je na konci
  bool get isAtEnd => position >= duration && duration.inMilliseconds > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioPositionData &&
        other.position == position &&
        other.duration == duration;
  }

  @override
  int get hashCode => position.hashCode ^ duration.hashCode;

  @override
  String toString() =>
      'AudioPositionData(${_formatDuration(position)}/${_formatDuration(duration)})';

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Konfigurácia pre audio player
class AudioPlayerConfig {
  final bool showSkipButtons;
  final bool showStopButton;
  final bool showProgressBar;
  final bool showDuration;
  final int skipBackwardSeconds;
  final int skipForwardSeconds;
  final bool autoPlay;
  final bool showArtwork;
  final bool showTitle;
  final bool showAuthor;

  const AudioPlayerConfig({
    this.showSkipButtons = true,
    this.showStopButton = true,
    this.showProgressBar = true,
    this.showDuration = true,
    this.skipBackwardSeconds = 15,
    this.skipForwardSeconds = 30,
    this.autoPlay = false,
    this.showArtwork = false, // Pre rosary/lectio obvykle false
    this.showTitle = true,
    this.showAuthor = true,
  });

  /// Predvolené nastavenie pre rosary
  static const AudioPlayerConfig rosary = AudioPlayerConfig(
    showSkipButtons: true,
    showStopButton: true,
    skipBackwardSeconds: 10,
    skipForwardSeconds: 30,
    showArtwork: false,
  );

  /// Predvolené nastavenie pre lectio
  static const AudioPlayerConfig lectio = AudioPlayerConfig(
    showSkipButtons: true,
    showStopButton: true,
    skipBackwardSeconds: 15,
    skipForwardSeconds: 30,
    showArtwork: false,
  );

  /// Minimálna konfigurácia
  static const AudioPlayerConfig minimal = AudioPlayerConfig(
    showSkipButtons: false,
    showStopButton: false,
    showDuration: false,
    showAuthor: false,
  );

  AudioPlayerConfig copyWith({
    bool? showSkipButtons,
    bool? showStopButton,
    bool? showProgressBar,
    bool? showDuration,
    int? skipBackwardSeconds,
    int? skipForwardSeconds,
    bool? autoPlay,
    bool? showArtwork,
    bool? showTitle,
    bool? showAuthor,
  }) {
    return AudioPlayerConfig(
      showSkipButtons: showSkipButtons ?? this.showSkipButtons,
      showStopButton: showStopButton ?? this.showStopButton,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      showDuration: showDuration ?? this.showDuration,
      skipBackwardSeconds: skipBackwardSeconds ?? this.skipBackwardSeconds,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      autoPlay: autoPlay ?? this.autoPlay,
      showArtwork: showArtwork ?? this.showArtwork,
      showTitle: showTitle ?? this.showTitle,
      showAuthor: showAuthor ?? this.showAuthor,
    );
  }
}

/// Callback typy pre audio player
typedef AudioPlayerCallback = void Function();
typedef AudioSeekCallback = void Function(Duration position);
typedef AudioErrorCallback = void Function(String error);
typedef AudioStateCallback = void Function(PlayerState state);

/// Enumerácia pre audio player status
enum UniversalAudioStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  stopped,
  error,
  completed;

  /// Je v stave prehrávania
  bool get isPlaying => this == UniversalAudioStatus.playing;

  /// Je v stave načítavania
  bool get isLoading => this == UniversalAudioStatus.loading;

  /// Je pripravený na prehrávanie
  bool get isReady => this == UniversalAudioStatus.ready;

  /// Môže byť spustený
  bool get canPlay => [ready, paused, stopped, idle].contains(this);

  /// Môže byť pozastavený
  bool get canPause => this == UniversalAudioStatus.playing;

  /// Môže byť zastavený
  bool get canStop => [playing, paused].contains(this);

  /// Konverzia z just_audio PlayerState
  static UniversalAudioStatus fromPlayerState(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        return UniversalAudioStatus.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return UniversalAudioStatus.loading;
      case ProcessingState.ready:
        return playerState.playing
            ? UniversalAudioStatus.playing
            : UniversalAudioStatus.ready;
      case ProcessingState.completed:
        return UniversalAudioStatus.completed;
    }
  }

  /// Farebné indikátory pre UI
  String get displayText {
    switch (this) {
      case UniversalAudioStatus.idle:
        return 'Pripravené';
      case UniversalAudioStatus.loading:
        return 'Načítava...';
      case UniversalAudioStatus.ready:
        return 'Pripravené';
      case UniversalAudioStatus.playing:
        return 'Prehráva';
      case UniversalAudioStatus.paused:
        return 'Pozastavené';
      case UniversalAudioStatus.stopped:
        return 'Zastavené';
      case UniversalAudioStatus.error:
        return 'Chyba';
      case UniversalAudioStatus.completed:
        return 'Dokončené';
    }
  }
}

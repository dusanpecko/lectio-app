/// Stav stiahnutia audio súboru
enum AudioDownloadStatus {
  /// Nie je stiahnuté
  notDownloaded,

  /// Práve sa sťahuje
  downloading,

  /// Stiahnuté a dostupné offline
  downloaded,

  /// Chyba pri sťahovaní
  error,
}

/// Model pre stav sťahovania audio súboru
class AudioDownloadState {
  final String url;
  final String? localPath;
  final AudioDownloadStatus status;
  final double progress;
  final String? errorMessage;

  const AudioDownloadState({
    required this.url,
    this.localPath,
    this.status = AudioDownloadStatus.notDownloaded,
    this.progress = 0.0,
    this.errorMessage,
  });

  AudioDownloadState copyWith({
    String? url,
    String? localPath,
    AudioDownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return AudioDownloadState(
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isDownloaded => status == AudioDownloadStatus.downloaded;
  bool get isDownloading => status == AudioDownloadStatus.downloading;
}

/// Stav sťahovania pre celý deň (všetky audio tracky)
class DayDownloadState {
  final String date;
  final Map<String, AudioDownloadState> tracks;
  final bool isComplete;

  const DayDownloadState({
    required this.date,
    this.tracks = const {},
    this.isComplete = false,
  });

  /// Celkový progres sťahovania (0.0 - 1.0)
  double get totalProgress {
    if (tracks.isEmpty) return 0.0;
    final total = tracks.values.fold<double>(
      0.0,
      (sum, state) =>
          sum +
          (state.status == AudioDownloadStatus.downloaded
              ? 1.0
              : state.progress),
    );
    return total / tracks.length;
  }

  /// Počet stiahnutých trackov
  int get downloadedCount => tracks.values
      .where((s) => s.status == AudioDownloadStatus.downloaded)
      .length;

  /// Celkový počet trackov
  int get totalCount => tracks.length;

  /// Či sa niečo práve sťahuje
  bool get isDownloading =>
      tracks.values.any((s) => s.status == AudioDownloadStatus.downloading);
}

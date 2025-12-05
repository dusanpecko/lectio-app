import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/lectio_audio_state.dart';
import '../services/background_audio_manager.dart';
import '../shared/audio_constants.dart';

/// Mixin pre audio playback funkcionalitu v Lectio screen
/// Obsahuje všetku logiku súvisiacu s prehrávaním audio
mixin LectioAudioMixin<T extends StatefulWidget> on State<T> {
  // Audio players
  final AudioPlayer audioPlayer = AudioPlayer();
  final BackgroundAudioManager backgroundAudioManager = BackgroundAudioManager();

  // Audio state
  LectioPlaybackState playbackState = LectioPlaybackState.idle;
  bool showAudioPlayer = false;
  bool isMinimized = false;
  String? currentAudioSection;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  String audioMode = 'short'; // 'none', 'short', 'long'
  Map<String, dynamic>? nextTrackAfterInterlude;
  bool audioPlayerClosed = false;
  bool isProcessingInterludeCompletion = false;
  bool usingFallbackPlayer = false;
  StreamSubscription? fallbackPlayerSubscription;

  // Timer pre pravidelnú aktualizáciu pozície
  Timer? positionUpdateTimer;

  // Playlist controller
  final PageController playlistPageController = PageController();

  /// Inicializácia audio listenrov
  @protected
  void initAudioListeners() {
    // Implementácia v hlavnom widgete
  }

  /// Spustí position update timer
  @protected
  void startPositionTimer() {
    positionUpdateTimer = Timer.periodic(
      Duration(milliseconds: AudioTimingConstants.positionUpdateInterval),
      (_) => updatePositionFromPlayer(),
    );
  }

  /// Aktualizuje pozíciu z playera
  @protected
  void updatePositionFromPlayer();

  /// Dispose audio resources
  @protected
  void disposeAudio() {
    positionUpdateTimer?.cancel();
    fallbackPlayerSubscription?.cancel();
    backgroundAudioManager.clearOnSectionCompleted();
    audioPlayer.dispose();
    playlistPageController.dispose();
  }

  /// Aktualizuje hlavný playback stav
  void setPlaybackState(LectioPlaybackState state) {
    if (mounted) {
      setState(() {
        playbackState = state;
        isPlaying = state.isPlaying;
        isProcessingInterludeCompletion =
            state == LectioPlaybackState.processingInterludeTransition;
      });
      debugPrint('🎵 Playback state: $state');
    }
  }

  /// Určí, či má byť použitý fallback player
  bool get shouldUseFallbackPlayer =>
      currentAudioSection == 'interlude' || usingFallbackPlayer;

  /// Vykoná audio operáciu na správnom playeri
  Future<void> executeAudioOperation({
    required String operationName,
    required Future<void> Function() fallbackOperation,
    required Future<void> Function() backgroundOperation,
  }) async {
    debugPrint(
      '🎵 $operationName: section=$currentAudioSection, fallback=$usingFallbackPlayer',
    );
    try {
      if (shouldUseFallbackPlayer) {
        await fallbackOperation();
        debugPrint('✅ AudioPlayer $operationName (fallback)');
      } else if (backgroundAudioManager.isInitialized) {
        await backgroundOperation();
        debugPrint('✅ BackgroundAudioManager $operationName');
      }
    } catch (e) {
      debugPrint('❌ Error in $operationName: $e');
    }
  }

  /// Pozastaví audio
  Future<void> pauseAudio() async {
    await executeAudioOperation(
      operationName: 'pause',
      fallbackOperation: () => audioPlayer.pause(),
      backgroundOperation: () => backgroundAudioManager.pause(),
    );
  }

  /// Obnoví prehrávanie audio
  Future<void> resumeAudio() async {
    await executeAudioOperation(
      operationName: 'resume',
      fallbackOperation: () => audioPlayer.play(),
      backgroundOperation: () => backgroundAudioManager.resume(),
    );
  }

  /// Seekne na pozíciu
  Future<void> seekAudio(Duration position) async {
    await executeAudioOperation(
      operationName: 'seek to ${position.inSeconds}s',
      fallbackOperation: () => audioPlayer.seek(position),
      backgroundOperation: () => backgroundAudioManager.seek(position),
    );
  }

  /// Zastaví audio
  Future<void> stopAudio() async {
    debugPrint('🛑 Stopping audio');

    if (backgroundAudioManager.isInitialized) {
      await backgroundAudioManager.stop();
    }
    await audioPlayer.stop();

    if (mounted) {
      setState(() {
        playbackState = LectioPlaybackState.stopped;
        currentAudioSection = null;
        nextTrackAfterInterlude = null;
        isPlaying = false;
        currentPosition = Duration.zero;
        totalDuration = Duration.zero;
        isProcessingInterludeCompletion = false;
      });
    }
  }

  /// Formátovanie duration na string (mm:ss)
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Získa názov aktuálne prehrávanej stopy
  String getNowPlayingTitle(List<Map<String, dynamic>> tracks) {
    if (currentAudioSection == 'interlude') {
      return 'Meditačná hudba';
    }

    final currentTrack = tracks.firstWhere(
      (t) => t['key'] == currentAudioSection,
      orElse: () => {'label': 'Audio'},
    );

    return currentTrack['label'] ?? 'Audio';
  }
}


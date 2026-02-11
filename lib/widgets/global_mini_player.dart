import 'dart:async';

import 'package:flutter/material.dart';

import '../services/lectio_audio_player.dart';
import '../shared/app_colors.dart';

/// Globálny mini prehrávač zobrazený na všetkých obrazovkách
/// Sleduje singleton LectioAudioPlayer a zobrazuje mini bar na spodku
/// Na LectioScreen sa nezobrazuje (tam je plný prehrávač)
class GlobalMiniPlayer extends StatefulWidget {
  final Widget child;

  /// Statická hodnota pre skrytie mini playera na konkrétnych obrazovkách
  static final ValueNotifier<bool> hideOnCurrentScreen = ValueNotifier(false);

  const GlobalMiniPlayer({super.key, required this.child});

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  final LectioAudioPlayer _player = LectioAudioPlayer();
  Timer? _progressTimer;

  bool _isPlaying = false;
  String? _currentTrackKey;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    GlobalMiniPlayer.hideOnCurrentScreen.addListener(_onVisibilityChanged);
    // Timer pre update pozície
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _updateProgress(),
    );
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    GlobalMiniPlayer.hideOnCurrentScreen.removeListener(_onVisibilityChanged);
    _progressTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    // Odloži setState ak sme v build fáze
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    _updateState();
  }

  void _updateProgress() {
    if (!mounted || !_player.isInitialized) return;

    final position = _player.position;
    final duration = _player.duration;

    if (position != _position || (duration != null && duration != _duration)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _position = position;
          if (duration != null) {
            _duration = duration;
          }
        });
      });
    }
  }

  void _updateState() {
    if (!mounted) return;
    final trackKey = _player.currentTrackKey;
    final isPlaying = _player.isPlaying;

    // Odloži setState ak sme v build fáze
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentTrackKey = trackKey;
        _isPlaying = isPlaying;
      });
    });
  }

  bool get _shouldShow {
    // Skry mini player ak je na obrazovke s plným prehrávačom
    if (GlobalMiniPlayer.hideOnCurrentScreen.value) return false;
    // Zobraz mini player len ak audio hrá alebo je pauza (nie stopped)
    if (!_player.isInitialized) return false;
    if (_player.currentTrackIndex < 0) return false;
    if (_currentTrackKey == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Mini player FAB vľavo dole
        if (_shouldShow)
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: _MiniPlayerFAB(
              isPlaying: _isPlaying,
              position: _position,
              duration: _duration,
              onTap: () async {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
              onLongPress: () async {
                await _player.stop();
                setState(() {
                  _currentTrackKey = null;
                });
              },
            ),
          ),
      ],
    );
  }
}

class _MiniPlayerFAB extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MiniPlayerFAB({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // Main button
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

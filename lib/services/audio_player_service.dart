import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audio Player Service pre Lectio Divina
/// Spravuje prehrávanie audio nahrávok s podporou meditačnej hudby
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentAudioSection;
  String _audioMode = 'short'; // 'none', 'short', 'long'
  Map<String, dynamic>? _nextTrackAfterInterlude;

  // Getters
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  String? get currentAudioSection => _currentAudioSection;
  String get audioMode => _audioMode;
  AudioPlayer get audioPlayer => _audioPlayer;

  // URLs pre meditačnú hudbu
  static const String _shortInterludeUrl =
      'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/audio_null.mp3';
  static const String _longInterludeUrl =
      'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/lectio_full.mp3';

  AudioPlayerService() {
    _setupListeners();
    _loadAudioMode();
  }

  void _setupListeners() {
    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();

      // Auto-play next track when current ends
      if (state.processingState == ProcessingState.completed) {
        debugPrint(
          '🎵 Audio dokončené. Current section: $_currentAudioSection',
        );

        // Ak práve skončila meditačná hudba (interlude), prehraj uloženú nahrávku
        if (_currentAudioSection == 'interlude' &&
            _nextTrackAfterInterlude != null) {
          final nextTrack = _nextTrackAfterInterlude!;
          _nextTrackAfterInterlude = null;
          debugPrint(
            '✅ Meditačná hudba skončila, prehrávam: ${nextTrack['key']}',
          );
          playAudio(nextTrack['url'], nextTrack['key']);
        }
        // Poznámka: Ďalšia nahrávka bude spustená z LectioScreen cez callback
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration;
        notifyListeners();
      }
    });
  }

  Future<void> _loadAudioMode() async {
    final prefs = await SharedPreferences.getInstance();
    _audioMode = prefs.getString('audioMode') ?? 'short';
    notifyListeners();
  }

  Future<void> setAudioMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audioMode', mode);
    _audioMode = mode;
    notifyListeners();
  }

  Future<void> playAudio(String url, String sectionKey) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      _currentAudioSection = sectionKey;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Chyba pri prehrávaní audia: $e');
      rethrow;
    }
  }

  Future<void> playInterlude(
    Map<String, dynamic> nextTrack,
    String currentSection,
  ) async {
    String interludeUrl;

    if (_audioMode == 'short') {
      // Krátke meditačné pozadie
      if (currentSection == 'contemplatio_audio') {
        interludeUrl = _longInterludeUrl;
      } else {
        interludeUrl = _shortInterludeUrl;
      }
    } else {
      // Dlhé meditačné pozadie
      interludeUrl = _longInterludeUrl;
    }

    try {
      // Ulož nasledujúcu nahrávku
      _nextTrackAfterInterlude = nextTrack;

      // Prehrať prechodové audio
      await _audioPlayer.setUrl(interludeUrl);
      await _audioPlayer.play();

      _currentAudioSection = 'interlude';
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Chyba pri prehrávaní meditačnej hudby: $e');
      // Ak zlyhá, prehraj priamo ďalšiu nahrávku
      _nextTrackAfterInterlude = null;
      await playAudio(nextTrack['url'], nextTrack['key']);
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentAudioSection = null;
    _isPlaying = false;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

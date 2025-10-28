import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';
import 'note_detail_screen.dart';

class LectioScreen extends StatefulWidget {
  const LectioScreen({
    super.key,
    this.selectedLang,
    this.selectedDate, // ← NOVÝ parameter
  });

  final String? selectedLang;
  final DateTime? selectedDate; // ← NOVÝ parameter

  @override
  State<LectioScreen> createState() => _LectioScreenState();
}

class _LectioScreenState extends State<LectioScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? lectioData;
  bool isLoading = true;
  bool _dataLoaded = false;
  DateTime selectedDate = DateTime.now();
  String _selectedBible = 'biblia1';

  // Audio player state - KOMPLETNE PREPÍSANÉ
  bool _showAudioPlayer = false;
  bool _isMinimized = false;
  String? _currentAudioSection;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String _audioMode = 'short'; // 'none', 'short', 'long'
  Map<String, dynamic>? _nextTrackAfterInterlude;
  bool _audioPlayerClosed = false; // Flag pre sledovanie zatvorenia prehrávača
  bool _isProcessingInterludeCompletion =
      false; // Flag pre zabránenie dvojitého volania

  // Cache pre tracks
  List<Map<String, dynamic>>? _cachedTracks;
  String? _lastCachedBible;
  Map<String, dynamic>? _lastCachedLectioData;

  // PageView controller
  final PageController _playlistPageController = PageController();

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      // Nastaviť selectedDate ak je poskytnutý z HomeScreen
      if (widget.selectedDate != null) {
        selectedDate = widget.selectedDate!;
      }

      _loadSelectedBible().then((_) => fetchLectioData());
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playlistPageController.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      debugPrint(
        '🎵 Player state changed: playing=${state.playing}, processingState=${state.processingState}',
      );
      debugPrint('🎵 Current _currentAudioSection: $_currentAudioSection');
      setState(() {
        _isPlaying = state.playing;
      });

      // Auto-play next track when current ends
      if (state.processingState == ProcessingState.completed) {
        debugPrint('🎵 Volám _onAudioCompleted()');
        _onAudioCompleted();
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  Future<void> _onAudioCompleted() async {
    debugPrint('🎵 Audio dokončené: $_currentAudioSection');
    debugPrint('🎵 _audioPlayerClosed: $_audioPlayerClosed');
    debugPrint('🎵 _isPlaying: $_isPlaying');

    // Ak bol prehrávač zatvorený, nič nerob
    if (_audioPlayerClosed) {
      debugPrint('🛑 Prehrávač bol zatvorený, zastavujem playback');
      return;
    }

    // Ak nie je nastavená sekcia, nič nerob
    if (_currentAudioSection == null) {
      debugPrint('🛑 _currentAudioSection je null, zastavujem');
      return;
    }

    // Ak skončila meditačná hudba, prehraj uloženú nahrávku
    if (_currentAudioSection == 'interlude') {
      if (_nextTrackAfterInterlude != null &&
          !_isProcessingInterludeCompletion) {
        _isProcessingInterludeCompletion = true; // Zabráň dvojitému volaniu
        final next = _nextTrackAfterInterlude!;
        _nextTrackAfterInterlude = null;
        debugPrint('✅ Meditácia skončila → ${next['key']}');
        debugPrint('🔄 Zavolám _playAudio pre ďalší track po interlude');

        // Spustíme ďalší track - animácia sa spustí hneď
        await _playAudio(next['url'], next['key']);

        // Reset flag po dokončení spracovania
        _isProcessingInterludeCompletion = false;
      } else if (_currentAudioSection == 'interlude' &&
          _nextTrackAfterInterlude == null) {
        // Už spracované alebo žiadna ďalšia nahrávka
        debugPrint(
          '🛑 Interlude completion: _nextTrackAfterInterlude=null, _isProcessingInterludeCompletion=$_isProcessingInterludeCompletion',
        );
        if (!_isProcessingInterludeCompletion) {
          debugPrint('🛑 Zastavujem audio - žiadna ďalšia nahrávka');
          _stopAudio();
        } else {
          debugPrint(
            '🛑 Preskakujem stop audio - práve sa spracováva interlude completion',
          );
        }
      } else {
        // Žiadna ďalšia nahrávka
        debugPrint(
          '🛑 Iný prípad: _currentAudioSection=$_currentAudioSection, _nextTrackAfterInterlude=$_nextTrackAfterInterlude',
        );
        if (!_isProcessingInterludeCompletion) {
          _stopAudio();
        }
      }
      return;
    }

    // Normálna nahrávka skončila → pokračuj na ďalšiu
    await _playNextTrack();
  }

  Future<void> fetchLectioData() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final today = DateFormat('yyyy-MM-dd').format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;

    try {
      debugPrint('🔍 Načítavam lectio pre dátum: $today, jazyk: $lang');

      // 1. Nájdi deň v liturgical_calendar
      final calendarResponse = await supabase
          .from('liturgical_calendar')
          .select('*, liturgical_years(*)')
          .eq('datum', today)
          .eq('locale_code', lang)
          .maybeSingle();

      if (calendarResponse == null) {
        debugPrint('❌ Liturgický kalendár nenájdený pre dátum $today');
        if (mounted) {
          setState(() {
            lectioData = null;
            isLoading = false;
          });
          _invalidateTracksCache();
        }
        return;
      }

      final lectioHlava = calendarResponse['lectio_hlava'];
      if (lectioHlava == null) {
        debugPrint('❌ Tento deň nemá priradenú lectio hlavičku');
        if (mounted) {
          setState(() {
            lectioData = null;
            isLoading = false;
          });
        }
        return;
      }

      // 2. Určíme či použiť cyklus (A/B/C) alebo 'N' pre všedné dni
      final celebrationTitle = calendarResponse['celebration_title'] ?? '';
      final celebrationRankNum = calendarResponse['celebration_rank_num'];

      final isWeekday = RegExp(
        r'(Pondelok|Utorok|Streda|Štvrtok|Piatok|Sobota).+týždňa v Cezročnom období',
      ).hasMatch(celebrationTitle);

      final isSpecialDay =
          !isWeekday &&
          (celebrationTitle.toLowerCase().contains('nedeľa') ||
              celebrationTitle.toLowerCase().contains('sunday') ||
              (celebrationRankNum != null && celebrationRankNum > 1));

      final liturgicalYear = calendarResponse['liturgical_years'];
      final lectionaryCycle = liturgicalYear?['lectionary_cycle'] ?? 'A';
      final rokToSearch = isSpecialDay ? lectionaryCycle : 'N';

      debugPrint(
        '🔍 Hľadám rok: "$rokToSearch" (všedný deň: ${isWeekday ? "ÁNO" : "NIE"}, špeciálny deň: $isSpecialDay)',
      );

      // 3. Nájdi zodpovedajúci záznam v lectio_sources
      var lectioSource = await supabase
          .from('lectio_sources')
          .select()
          .eq('hlava', lectioHlava)
          .eq('lang', lang)
          .eq('rok', rokToSearch)
          .maybeSingle();

      // Fallback logika
      if (lectioSource == null) {
        debugPrint('❌ Lectio source nenájdený pre $lang, rok $rokToSearch');

        // Pre sviatky: skús rok 'N'
        if (isSpecialDay && rokToSearch != 'N') {
          debugPrint('🔄 Sviatok nenájdený s rokom A/B/C, skúšam rok N...');
          lectioSource = await supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', lang)
              .eq('rok', 'N')
              .maybeSingle();
        }

        // Fallback na slovenčinu
        if (lectioSource == null && lang != 'sk') {
          debugPrint('🔄 Skúšam načítať lectio source pre slovenčinu...');
          lectioSource = await supabase
              .from('lectio_sources')
              .select()
              .eq('hlava', lectioHlava)
              .eq('lang', 'sk')
              .eq('rok', rokToSearch)
              .maybeSingle();

          // Pre sviatky v slovenčine: aj tu skús 'N'
          if (lectioSource == null && isSpecialDay && rokToSearch != 'N') {
            debugPrint('🔄 Skúšam slovenčinu s rokom N...');
            lectioSource = await supabase
                .from('lectio_sources')
                .select()
                .eq('hlava', lectioHlava)
                .eq('lang', 'sk')
                .eq('rok', 'N')
                .maybeSingle();
          }
        }
      }

      if (lectioSource != null) {
        debugPrint('✅ Lectio source nájdený: ${lectioSource['hlava']}');
      } else {
        debugPrint('❌ Lectio source neexistuje pre žiadny jazyk');
      }

      if (mounted) {
        setState(() {
          lectioData = lectioSource;
          isLoading = false;
        });
        _invalidateTracksCache();
      }
    } catch (e) {
      debugPrint('❌ Chyba pri načítavaní Lectio dát: $e');
      if (mounted) {
        setState(() {
          lectioData = null;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedBible() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedBible = prefs.getString('selectedBible') ?? 'biblia1';
        _audioMode = prefs.getString('audioMode') ?? 'short';
      });
      _invalidateTracksCache();
    }
  }

  Future<void> _saveAudioMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audioMode', mode);
    if (mounted) {
      setState(() {
        _audioMode = mode;
      });
    }
  }

  void _invalidateTracksCache() {
    _cachedTracks = null;
    _lastCachedBible = null;
    _lastCachedLectioData = null;
  }

  List<Map<String, dynamic>> _getAvailableAudioTracks() {
    if (lectioData == null) return [];

    // Cache check - ak sa nič nezmenilo, vráť cache
    if (_cachedTracks != null &&
        _lastCachedBible == _selectedBible &&
        _lastCachedLectioData == lectioData) {
      return _cachedTracks!;
    }

    final tracks = <Map<String, dynamic>>[];
    final lang = widget.selectedLang ?? context.locale.languageCode;

    // Modlitba audio
    if (lectioData!['modlitba_audio'] != null &&
        lectioData!['modlitba_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'modlitba_audio',
        'label': lang == 'sk' ? 'Modlitba' : 'Prayer',
        'url': lectioData!['modlitba_audio'],
        'icon': Icons.favorite,
        'color': Colors.red,
      });
    }

    // Bible audio (dynamické podľa vybranej biblie - rovnako ako v Next.js)
    // Konvertovať 'biblia1' → 'biblia_1_audio'
    final bibleNumber = _selectedBible.replaceAll('biblia', '');
    final bibleAudioKey = 'biblia_${bibleNumber}_audio';
    final nazovKey = 'nazov_biblia_$bibleNumber';

    if (lectioData![bibleAudioKey] != null &&
        lectioData![bibleAudioKey].toString().isNotEmpty) {
      tracks.add({
        'key': bibleAudioKey,
        'label':
            lectioData![nazovKey] ??
            (lang == 'sk' ? 'Biblický text' : 'Biblical text'),
        'url': lectioData![bibleAudioKey],
        'icon': Icons.menu_book,
        'color': Colors.purple,
      });
    }

    // Lectio audio
    if (lectioData!['lectio_audio'] != null &&
        lectioData!['lectio_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'lectio_audio',
        'label': 'Lectio',
        'url': lectioData!['lectio_audio'],
        'icon': Icons.book_outlined,
        'color': Colors.green,
      });
    }

    // Meditatio audio
    if (lectioData!['meditatio_audio'] != null &&
        lectioData!['meditatio_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'meditatio_audio',
        'label': 'Meditatio',
        'url': lectioData!['meditatio_audio'],
        'icon': Icons.visibility_outlined,
        'color': Colors.purple.shade700,
      });
    }

    // Oratio audio
    if (lectioData!['oratio_audio'] != null &&
        lectioData!['oratio_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'oratio_audio',
        'label': 'Oratio',
        'url': lectioData!['oratio_audio'],
        'icon': Icons.favorite_border,
        'color': Colors.orange,
      });
    }

    // Contemplatio audio
    if (lectioData!['contemplatio_audio'] != null &&
        lectioData!['contemplatio_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'contemplatio_audio',
        'label': 'Contemplatio',
        'url': lectioData!['contemplatio_audio'],
        'icon': Icons.chat_bubble_outline,
        'color': Colors.pink,
      });
    }

    // Actio audio
    if (lectioData!['actio_audio'] != null &&
        lectioData!['actio_audio'].toString().isNotEmpty) {
      tracks.add({
        'key': 'actio_audio',
        'label': 'Actio',
        'url': lectioData!['actio_audio'],
        'icon': Icons.play_arrow,
        'color': Colors.teal,
      });
    }

    // Ulož do cache
    _cachedTracks = tracks;
    _lastCachedBible = _selectedBible;
    _lastCachedLectioData = lectioData;

    return tracks;
  }

  Future<void> _playAudio(
    String url,
    String sectionKey, {
    bool skipAnimation = false,
  }) async {
    try {
      debugPrint('▶️ Prehrávam: $sectionKey');

      // Zastaviť aktuálne audio ak beží
      if (_currentAudioSection != null && _currentAudioSection != sectionKey) {
        debugPrint('🛑 Zastavujem predchádzajúce audio: $_currentAudioSection');
        await _audioPlayer.stop();
      }

      if (mounted) {
        debugPrint('🎵 Nastavujem state pre $sectionKey PRED setUrl');
        setState(() {
          _currentAudioSection = sectionKey;
          _isPlaying = false; // Ešte sa nehraje
          _audioPlayerClosed = false; // Reset flag keď začína nové audio
          _isMinimized = false; // Reset minimalizácie pri novom tracku
          // Vždy otvor prehrávač pri novom tracku
          _showAudioPlayer = true;
        });
        debugPrint(
          '🎵 State nastavený: _currentAudioSection=$_currentAudioSection',
        );
      }

      // 🎯 NOVÁ LOGIKA: Animovať HNEĎ pri spustení normálnej nahrávky (nie interlude)
      if (mounted && sectionKey != 'interlude' && !skipAnimation) {
        debugPrint('🎵 🚀 Animujem HNEĎ pri spustení nahrávky: $sectionKey');
        await Future.delayed(const Duration(milliseconds: 50));

        final tracks = _getAvailableAudioTracks();
        final trackIndex = tracks.indexWhere((t) => t['key'] == sectionKey);
        debugPrint('🎵 Posúvam na track index: $trackIndex pre $sectionKey');

        if (trackIndex >= 0 && _playlistPageController.hasClients) {
          debugPrint(
            '🎵 🎯 ANIMUJEM na stránku $trackIndex PRED načítaním audio',
          );
          await _playlistPageController.animateToPage(
            trackIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          debugPrint('🎵 ✅ Animácia dokončená na stránku $trackIndex');

          // Krátka stabilizácia
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          debugPrint(
            '🎵 ❌ Nemôžem animovať: trackIndex=$trackIndex, hasClients=${_playlistPageController.hasClients}',
          );
        }
      }

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      if (mounted) {
        debugPrint('🎵 Audio spustené úspešne');
      } else {
        debugPrint('🎵 ❌ Widget nie je mounted!');
      }
    } catch (e) {
      debugPrint('❌ Chyba pri prehrávaní: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepodarilo sa prehrať audio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _resumeAudio() async {
    await _audioPlayer.play();
    if (mounted) {
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _stopAudio() async {
    debugPrint('🛑 Zastavujem audio');
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _currentAudioSection = null;
        _nextTrackAfterInterlude = null;
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _audioPlayerClosed = false; // Reset flag
        _isProcessingInterludeCompletion =
            false; // Reset interlude processing flag
      });
    }
  }

  Future<void> _playNextTrack() async {
    if (_currentAudioSection == null || _currentAudioSection == 'interlude') {
      return;
    }

    final tracks = _getAvailableAudioTracks();
    final currentIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );

    if (currentIndex == -1) {
      debugPrint('⚠️ Track nenájdený');
      return;
    }

    // Je ešte ďalší track?
    final hasNext = currentIndex < tracks.length - 1;

    if (!hasNext) {
      // Posledný track - počkaj trochu pred spustením záverečnej meditácie
      debugPrint('🎵 ⏳ Čakám 500ms pred záverečnou meditáciou');
      await Future.delayed(const Duration(milliseconds: 500));

      if (_audioMode != 'none') {
        _playMeditationMusic(null); // Žiadny ďalší track
      } else {
        _stopAudio();
      }
      return;
    }

    // Máme ďalší track - počkaj pred spustením interlude
    final nextTrack = tracks[currentIndex + 1];
    debugPrint(
      '🎵 ⏳ Čakám 500ms pred spustením interlude pre ${nextTrack['key']}',
    );
    await Future.delayed(const Duration(milliseconds: 500));

    if (_audioMode != 'none') {
      // Prehraj meditáciu → potom nextTrack
      _playMeditationMusic(nextTrack);
    } else {
      // Rovno nextTrack - BEZ animácie (automatický prechod)
      _playAudio(nextTrack['url'], nextTrack['key'], skipAnimation: true);
    }
  }

  Future<void> _playMeditationMusic(Map<String, dynamic>? nextTrack) async {
    // Vyber správnu meditačnú hudbu
    String url;
    if (_audioMode == 'short') {
      // Short: pre contemplatio alebo actio → lectio_full, inak audio_null
      if (_currentAudioSection == 'contemplatio_audio' || nextTrack == null) {
        url =
            'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/lectio_full.mp3';
      } else {
        url =
            'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/audio_null.mp3';
      }
    } else {
      // Long: vždy lectio_full
      url =
          'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/lectio_full.mp3';
    }

    try {
      _nextTrackAfterInterlude = nextTrack; // Ulož ďalší track (alebo null)

      // 🎯 KRITICKÁ OPRAVA: Odlišné čakanie pre audio_null vs normálne audio
      final isAudioNull = url.contains('audio_null.mp3');

      if (isAudioNull) {
        debugPrint(
          '🎵 ⏳ Čakám 1200ms pred spustením KRÁTKEHO interlude (audio_null)',
        );
        await Future.delayed(const Duration(milliseconds: 1200));
      } else {
        debugPrint(
          '🎵 ⏳ Čakám 700ms pred spustením DLHÉHO interlude (lectio_full)',
        );
        await Future.delayed(const Duration(milliseconds: 700));
      }

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      if (mounted) {
        setState(() {
          _currentAudioSection = 'interlude';
          _isPlaying = true;
        });
        debugPrint(
          '🎵 🎸 Interlude spustené - state zmenený na interlude (${isAudioNull ? "KRÁTKE" : "DLHÉ"})',
        );
      }
    } catch (e) {
      debugPrint('❌ Meditácia zlyhala: $e');
      _nextTrackAfterInterlude = null;
      if (nextTrack != null) {
        _playAudio(nextTrack['url'], nextTrack['key'], skipAnimation: true);
      } else {
        _stopAudio();
      }
    }
  }

  void _playPreviousTrack() {
    final tracks = _getAvailableAudioTracks();
    if (tracks.isEmpty || _currentAudioSection == null) return;

    final currentIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );
    if (currentIndex <= 0) return;

    // Prehraj predchádzajúcu stopu
    final previousTrack = tracks[currentIndex - 1];
    _playAudio(
      previousTrack['url'],
      previousTrack['key'],
      // Manuálne previous = animovať hneď
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getNowPlayingTitle() {
    if (_currentAudioSection == 'interlude') {
      return 'Meditačná hudba';
    }

    // Nájdi aktuálny track
    final tracks = _getAvailableAudioTracks();
    final currentTrack = tracks.firstWhere(
      (t) => t['key'] == _currentAudioSection,
      orElse: () => {'label': 'Audio'},
    );

    return currentTrack['label'] ?? 'Audio';
  }

  Widget _buildAudioModeIconButton(
    String mode,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _audioMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveAudioMode(mode),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade600,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String? title,
    String subtitle = '',
    required String text,
    String? reference,
  }) {
    return _SimpleSection(
      title: title,
      subtitle: subtitle,
      text: text,
      reference: reference,
    );
  }

  void _goToPreviousDay() {
    setState(
      () => selectedDate = selectedDate.subtract(const Duration(days: 1)),
    );
    fetchLectioData();
  }

  void _goToNextDay() {
    setState(() => selectedDate = selectedDate.add(const Duration(days: 1)));
    fetchLectioData();
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(
                0xFF4A5085,
              ), // Rovnaká farba ako v HomeScreen
              onPrimary: Colors.white,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchLectioData();
    }
  }

  void _handleAddNote() {
    if (lectioData == null) return;
    String bibleReference = '';
    if (_selectedBible == 'biblia1') {
      bibleReference = lectioData?['biblia_1'] ?? '';
    } else if (_selectedBible == 'biblia2') {
      bibleReference = lectioData?['biblia_2'] ?? '';
    } else if (_selectedBible == 'biblia3') {
      bibleReference = lectioData?['biblia_3'] ?? '';
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('d.M.yyyy').format(now);

    final noteData = {
      'id': null,
      'title': formattedDate,
      'content': '',
      'bible_reference': lectioData?['suradnice_pismo'] ?? '',
      'bible_quote': bibleReference,
    };

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteDetailScreen(note: noteData)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat(
      'dd.MM.yyyy',
      context.locale.toString(),
    ).format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A5085).withValues(alpha: 0.1),
                  theme.scaffoldBackgroundColor,
                  const Color(0xFF4A5085).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                // Hero SliverAppBar s obrázkom
                SliverAppBar(
                  expandedHeight: 250,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF4A5085),
                  foregroundColor: Colors.white,
                  actions: [
                    if (Supabase.instance.client.auth.currentUser != null)
                      IconButton(
                        icon: const Icon(Icons.note_add_outlined),
                        tooltip: "Pridať poznámku",
                        onPressed: _handleAddNote,
                      ),
                    // Audio button
                    if (_getAvailableAudioTracks().isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _showAudioPlayer
                              ? Icons.music_note
                              : Icons.music_note_outlined,
                        ),
                        tooltip: "Audio prehrávač",
                        onPressed: () {
                          setState(() {
                            _showAudioPlayer = !_showAudioPlayer;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: fetchLectioData,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    title: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "Lectio Divina",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4A5085), Color(0xFF6B73A8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background image
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/lectio_header.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(),
                            ),
                          ),
                          // Gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0x4D4A5085),
                                    Color(0xFF4A5085),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Date badge
                          Positioned(
                            top: 120,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Color(0xFF4A5085),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Date Navigation Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.07),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: tr("previous_day"),
                            icon: const Icon(Icons.chevron_left, size: 32),
                            onPressed: _goToPreviousDay,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showDatePicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4A5085,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 20,
                                      color: Color(0xFF4A5085),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formattedDate,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF4A5085),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: tr("next_day"),
                            icon: const Icon(Icons.chevron_right, size: 32),
                            onPressed: _goToNextDay,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Divider(height: 1, color: theme.dividerColor),
                ),

                // Main Content
                SliverToBoxAdapter(
                  child: isLoading
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : lectioData == null
                      ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tr("lectio_not_available"),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // Title and Bible Reference
                            if ((lectioData?['hlava'] ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Center(
                                  child: Text(
                                    lectioData?['hlava'] ?? '',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4A5085),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            if ((lectioData?['suradnice_pismo'] ?? '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 8,
                                ),
                                child: Center(
                                  child: Text(
                                    lectioData?['suradnice_pismo'] ?? '',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),

                            // Biblický text podľa vybranej biblie
                            if (lang == 'sk') ...[
                              if (_selectedBible == 'biblia1')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_1'],
                                  text: lectioData?['biblia_1'] ?? '',
                                ),
                              if (_selectedBible == 'biblia2')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_2'],
                                  text: lectioData?['biblia_2'] ?? '',
                                ),
                              if (_selectedBible == 'biblia3')
                                _buildSection(
                                  title: lectioData?['nazov_biblia_3'],
                                  text: lectioData?['biblia_3'] ?? '',
                                ),
                            ] else ...[
                              _buildSection(
                                title: lectioData?['nazov_biblia_1'],
                                text: lectioData?['biblia_1'] ?? '',
                              ),
                            ],

                            // Lectio Divina sekcie
                            _buildSection(
                              title: "LECTIO",
                              subtitle: tr("l_commenter"),
                              text: lectioData?['lectio_text'] ?? '',
                            ),
                            _buildSection(
                              title: "MEDITATIO",
                              subtitle: tr("l_meditatio"),
                              text: lectioData?['meditatio_text'] ?? '',
                            ),
                            _buildSection(
                              title: "ORATIO",
                              subtitle: tr("l_oratio"),
                              text: lectioData?['oratio_text'] ?? '',
                            ),
                            _buildSection(
                              title: "CONTEMPLATIO",
                              subtitle: tr("l_contemplatio"),
                              text: lectioData?['contemplatio_text'] ?? '',
                            ),
                            _buildSection(
                              title: "ACTIO",
                              subtitle: tr("l_actio"),
                              text: lectioData?['actio_text'] ?? '',
                              reference: lectioData?['reference'],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Floating Audio Player
          if (_showAudioPlayer && _getAvailableAudioTracks().isNotEmpty)
            _buildFloatingAudioPlayer(theme),
        ],
      ),
    );
  }

  Widget _buildFloatingAudioPlayer(ThemeData theme) {
    final tracks = _getAvailableAudioTracks();
    final currentTrackIndex = tracks.indexWhere(
      (t) => t['key'] == _currentAudioSection,
    );

    // Zobraz current track alebo interlude
    final currentTrack = currentTrackIndex >= 0
        ? tracks[currentTrackIndex]
        : null;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(_isMinimized ? 12 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: _isMinimized
                    ? BorderRadius.circular(12)
                    : const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audio prehrávač',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minimize button
                      IconButton(
                        icon: Icon(
                          _isMinimized ? Icons.expand_less : Icons.minimize,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: _isMinimized ? 'Rozbaliť' : 'Minimalizovať',
                        onPressed: () {
                          setState(() {
                            _isMinimized = !_isMinimized;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      // Close button
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Zatvoriť a zastaviť',
                        onPressed: () async {
                          debugPrint('🔒 Zatváram prehrávač');
                          setState(() {
                            _audioPlayerClosed =
                                true; // Nastav flag pred zatvorením
                            _showAudioPlayer = false;
                          });
                          await _stopAudio(); // Zastaviť audio
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Minimalizovaný režim - len progress bar
            if (_isMinimized && currentTrack != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Track info
                    Row(
                      children: [
                        Icon(
                          currentTrack['icon'],
                          color: currentTrack['color'],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getNowPlayingTitle(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Play/Pause button
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 24,
                          ),
                          color: AppColors.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            debugPrint(
                              '🎮 MINIMALIZOVANÉ PLAY tlačidlo stlačené',
                            );
                            debugPrint('🎮 _isPlaying: $_isPlaying');
                            debugPrint(
                              '🎮 _currentAudioSection: $_currentAudioSection',
                            );

                            if (_isPlaying) {
                              debugPrint('🎮 -> Pozastavujem audio (mini)');
                              _pauseAudio();
                            } else if (_currentAudioSection != null) {
                              debugPrint(
                                '🎮 -> Obnovujem pozastavené audio (mini)',
                              );
                              _resumeAudio();
                            } else {
                              debugPrint('🎮 -> Spúšťam prvú nahrávku (mini)');
                              final tracks = _getAvailableAudioTracks();
                              debugPrint(
                                '🎮 -> Počet dostupných tracks (mini): ${tracks.length}',
                              );
                              final firstTrack = tracks.isNotEmpty
                                  ? tracks[0]
                                  : null;
                              if (firstTrack != null) {
                                debugPrint(
                                  '� -> Prvý track (mini): ${firstTrack['key']} - ${firstTrack['label']}',
                                );
                                _playAudio(
                                  firstTrack['url'],
                                  firstTrack['key'],
                                  // Manuálne spustenie = animovať hneď
                                );
                              } else {
                                debugPrint(
                                  '🎮 -> CHYBA: Žiaden track k dispozícii! (mini)',
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12.0,
                              ),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: Slider(
                              value: _currentPosition.inSeconds.toDouble(),
                              max: _totalDuration.inSeconds.toDouble() > 0
                                  ? _totalDuration.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                _audioPlayer.seek(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Plný obsah prehrávača
            if (!_isMinimized)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Audio Mode Selector - len ikony v kruhu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAudioModeIconButton(
                          'none',
                          Icons.music_off,
                          theme,
                        ),
                        const SizedBox(width: 12),
                        _buildAudioModeIconButton(
                          'short',
                          Icons.music_note,
                          theme,
                        ),
                        const SizedBox(width: 12),
                        _buildAudioModeIconButton(
                          'long',
                          Icons.queue_music,
                          theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Now Playing - s animáciou
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: _currentAudioSection != null
                          ? Container(
                              key: ValueKey(_currentAudioSection),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _currentAudioSection == 'interlude'
                                        ? Icons
                                              .spa // Ikona pre meditáciu
                                        : (currentTrack?['icon'] ??
                                              Icons.music_note),
                                    color: _currentAudioSection == 'interlude'
                                        ? Colors.blue.shade300
                                        : (currentTrack?['color'] ??
                                              AppColors.primary),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Práve hrá',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                        ),
                                        Text(
                                          _getNowPlayingTitle(),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ), // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          color: currentTrackIndex > 0
                              ? const Color(0xFF4A5085)
                              : Colors.grey.shade400,
                          onPressed: currentTrackIndex > 0
                              ? _playPreviousTrack
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A5085),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A5085,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 32,
                            ),
                            color: Colors.white,
                            onPressed: () {
                              debugPrint('🎮 HLAVNÉ PLAY tlačidlo stlačené');
                              debugPrint('🎮 _isPlaying: $_isPlaying');
                              debugPrint(
                                '🎮 _currentAudioSection: $_currentAudioSection',
                              );
                              debugPrint(
                                '🎮 _showAudioPlayer: $_showAudioPlayer',
                              );

                              if (_isPlaying) {
                                debugPrint('🎮 -> Pozastavujem audio');
                                _pauseAudio();
                              } else if (_currentAudioSection != null) {
                                debugPrint('🎮 -> Obnovujem pozastavené audio');
                                _resumeAudio();
                              } else {
                                debugPrint('🎮 -> Spúšťam prvú nahrávku');
                                final tracks = _getAvailableAudioTracks();
                                debugPrint(
                                  '🎮 -> Počet dostupných tracks: ${tracks.length}',
                                );
                                final firstTrack = tracks.isNotEmpty
                                    ? tracks[0]
                                    : null;
                                if (firstTrack != null) {
                                  debugPrint(
                                    '� -> Prvý track: ${firstTrack['key']} - ${firstTrack['label']}',
                                  );
                                  debugPrint('🎮 -> URL: ${firstTrack['url']}');
                                  _playAudio(
                                    firstTrack['url'],
                                    firstTrack['key'],
                                    // Manuálne spustenie = animovať hneď
                                  );
                                } else {
                                  debugPrint(
                                    '🎮 -> CHYBA: Žiaden track k dispozícii!',
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          color: currentTrackIndex < tracks.length - 1
                              ? const Color(0xFF4A5085)
                              : Colors.grey.shade400,
                          onPressed: currentTrackIndex < tracks.length - 1
                              ? _playNextTrack
                              : null,
                        ),
                      ],
                    ),

                    // Progress bar - zobrazuj vždy
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16.0,
                              ),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: Slider(
                              value: _currentPosition.inSeconds.toDouble(),
                              max: _totalDuration.inSeconds.toDouble() > 0
                                  ? _totalDuration.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (value) {
                                _audioPlayer.seek(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Playlist - horizontálny swipe
                    Text(
                      'Dostupné nahrávky',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // PageView so swipe
                    SizedBox(
                      height: 70,
                      child: PageView.builder(
                        controller: _playlistPageController,
                        itemCount: tracks.length,
                        onPageChanged: (index) {
                          // Voliteľne môžeme prehrať nahrávku pri manuálnom swipe
                          // final track = tracks[index];
                          // _playAudio(track['url'], track['key']);
                        },
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final isCurrentTrack =
                              track['key'] == _currentAudioSection;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GestureDetector(
                              onTap: () => _playAudio(
                                track['url'],
                                track['key'],
                                // Priame kliknutie používateľa = animovať hneď (skipAnimation: false)
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  gradient: isCurrentTrack
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isCurrentTrack
                                      ? null
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isCurrentTrack
                                      ? Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                  boxShadow: isCurrentTrack
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      // Ikona
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          track['icon'],
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Názov nahrávky + playing indicator
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track['label'],
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    color: isCurrentTrack
                                                        ? AppColors.primary
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                    fontWeight: isCurrentTrack
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isCurrentTrack &&
                                                _isPlaying) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(AppColors.primary),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Práve hrá',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              AppColors.primary,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Page indicator (dots)
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(tracks.length, (index) {
                        final isCurrentPage =
                            tracks[index]['key'] == _currentAudioSection;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isCurrentPage ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isCurrentPage
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleSection extends StatelessWidget {
  const _SimpleSection({
    required this.title,
    required this.subtitle,
    required this.text,
    this.reference,
  });

  final String? title;
  final String subtitle;
  final String text;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTitle = title;
    if (text.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (localTitle != null && localTitle.isNotEmpty)
                Text(
                  localTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A5085),
                  ),
                ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5, // Lepšie riadkovanie pre čitateľnosť
                  ),
                ),
              ],
              if (reference != null && reference!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reference!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

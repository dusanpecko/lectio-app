import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class LectioScreen extends StatefulWidget {
  const LectioScreen({super.key, this.selectedLang});
  final String? selectedLang;

  @override
  State<LectioScreen> createState() => _LectioScreenState();
}

class _AudioSection {
  final String key;
  final String label;
  _AudioSection({required this.key, required this.label});
}

class _LectioScreenState extends State<LectioScreen> {
  Map<String, dynamic>? lectioData;
  bool isLoading = true;
  bool _dataLoaded = false;
  final AudioPlayer _player = AudioPlayer();

  DateTime selectedDate = DateTime.now();
  String _selectedBible = 'biblia1';
  Map<String, bool> _selectedAudios = {};

  int _currentAudioIndex = 0;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isPlayerExpanded = false;

  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _currentDuration = _player.duration ?? Duration.zero;
      });
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        if (_currentAudioIndex < _playlist.length - 1) {
          await _playAudioAtIndex(_currentAudioIndex + 1);
        } else {
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _loadSelectedBible().then((_) {
        fetchLectioData();
      });
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _positionSubscription.cancel();
    _playerStateSubscription.cancel();
    super.dispose();
  }

  Future<void> fetchLectioData() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final today = DateFormat('yyyy-MM-dd').format(selectedDate);

    final lang = widget.selectedLang ?? context.locale.languageCode;

    var result = await supabase
        .from('lectio')
        .select()
        .eq('datum', today)
        .eq('lang', lang)
        .maybeSingle();

    if (result == null && lang != "sk") {
      result = await supabase
          .from('lectio')
          .select()
          .eq('datum', today)
          .eq('lang', "sk")
          .maybeSingle();
    }

    if (mounted) {
      setState(() {
        lectioData = result;
        isLoading = false;
        _resetSelectedAudios();
      });
    }
  }

  Future<void> _loadSelectedBible() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedBible = prefs.getString('selectedBible') ?? 'biblia1';
      });
    }
  }

  List<_AudioSection> getAllAudioSections(BuildContext context) {
    final bibleSections = getBibleAudioSections(context);
    return [
      _AudioSection(key: 'uvod_audio', label: tr('audio_intro')),
      _AudioSection(key: 'modlitba_audio', label: tr('audio_prayer')),
      ...bibleSections,
      _AudioSection(key: 'lectio_audio', label: tr('audio_lectio')),
      _AudioSection(key: 'meditatio_audio', label: tr('audio_meditatio')),
      _AudioSection(key: 'oratio_audio', label: tr('audio_oratio')),
      _AudioSection(key: 'contemplatio_audio', label: tr('audio_contemplatio')),
      _AudioSection(key: 'actio_audio', label: tr('audio_actio')),
      _AudioSection(key: 'audio_5_min', label: tr('audio_5min')),
    ];
  }

  List<_AudioSection> getBibleAudioSections(BuildContext context) {
    final List<_AudioSection> bibleAudioSections = [];
    if (_selectedBible == 'biblia1' &&
        (lectioData?['biblia_1_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        _AudioSection(key: 'biblia_1_audio', label: tr('audio_bible1')),
      );
    }
    if (_selectedBible == 'biblia2' &&
        (lectioData?['biblia_2_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        _AudioSection(key: 'biblia_2_audio', label: tr('audio_bible2')),
      );
    }
    if (_selectedBible == 'biblia3' &&
        (lectioData?['biblia_3_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        _AudioSection(key: 'biblia_3_audio', label: tr('audio_bible3')),
      );
    }
    return bibleAudioSections;
  }

  void _resetSelectedAudios() {
    if (lectioData == null) return;
    final sections = getAllAudioSections(context);
    setState(() {
      _selectedAudios = {
        for (var sec in sections)
          if ((lectioData![sec.key] ?? '').toString().isNotEmpty) sec.key: true,
      };
      _currentAudioIndex = 0;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _currentDuration = Duration.zero;
    });
  }

  List<_AudioSection> get _playlist => getAllAudioSections(context)
      .where(
        (section) =>
            (_selectedAudios[section.key] ?? false) &&
            (lectioData?[section.key] ?? '').toString().isNotEmpty,
      )
      .toList();

  Widget _buildMiniAudioPlayer(BuildContext context) {
    final currentSection = _playlist.isNotEmpty
        ? _playlist[_currentAudioIndex]
        : null;
    final currentLabel = currentSection?.label ?? '';

    return GestureDetector(
      onTap: () => setState(() => _isPlayerExpanded = true),
      child: AnimatedOpacity(
        opacity: _playlist.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.07 * 255).toInt()),
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          height: 56,
          child: Row(
            children: [
              Icon(Icons.headphones, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentLabel.isEmpty ? tr('audio_player') : currentLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _playlist.isEmpty ? null : _togglePlayPause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(BuildContext context) {
    final allSections = getAllAudioSections(context);

    final currentSection = _playlist.isNotEmpty
        ? _playlist[_currentAudioIndex]
        : null;
    final currentLabel = currentSection?.label ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.headphones, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('audio_player'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: tr('audio_choose_title'),
                  onPressed: () =>
                      _showAudioSelectionPopup(context, allSections),
                ),
              ],
            ),
            if (currentSection != null) ...[
              const SizedBox(height: 8),
              Text(
                currentLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? _currentPosition;
                  final duration = _player.duration ?? _currentDuration;
                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: duration.inMilliseconds.toDouble() > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        value: position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble(),
                        onChanged: (value) {
                          _player.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(duration)),
                        ],
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _currentAudioIndex > 0 ? _playPrevious : null,
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 36,
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _isPlaying ? _stop : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: _currentAudioIndex < _playlist.length - 1
                        ? _playNext
                        : null,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                tr('audio_no_tracks_selected'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.playlist_play),
                label: Text(tr('audio_play_selected')),
                onPressed: _playlist.isEmpty
                    ? null
                    : () async {
                        await _playAudioAtIndex(0);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _playAudioAtIndex(int index) async {
    final playlist = _playlist;
    if (!mounted || playlist.isEmpty || index >= playlist.length) return;

    setState(() {
      _currentAudioIndex = index;
      _isPlaying = true;
    });

    final url = lectioData?[playlist[_currentAudioIndex].key];
    if (url is String && url.isNotEmpty) {
      try {
        await _player.setUrl(url);
        await _player.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Nepodarilo sa prehrať ${playlist[_currentAudioIndex].label}.',
              ),
            ),
          );
          setState(() {
            _isPlaying = false;
          });
        }
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_player.playing;
    });
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _stop() {
    _player.stop();
    setState(() {
      _isPlaying = false;
      _currentPosition = Duration.zero;
    });
  }

  Future<void> _playNext() async {
    final playlist = _playlist;
    if (_currentAudioIndex < playlist.length - 1) {
      await _playAudioAtIndex(_currentAudioIndex + 1);
    }
  }

  Future<void> _playPrevious() async {
    if (_currentAudioIndex > 0) {
      await _playAudioAtIndex(_currentAudioIndex - 1);
    }
  }

  void _showAudioSelectionPopup(
    BuildContext context,
    List<_AudioSection> sections,
  ) async {
    final Map<String, bool> tempSelection = Map<String, bool>.from(
      _selectedAudios,
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('audio_choose_title')),
              content: SingleChildScrollView(
                child: Column(
                  children: sections.map((section) {
                    final audioExists = (lectioData?[section.key] ?? '')
                        .toString()
                        .isNotEmpty;
                    return CheckboxListTile(
                      value: tempSelection[section.key] ?? audioExists,
                      title: Text(section.label),
                      onChanged: audioExists
                          ? (v) {
                              setStateDialog(() {
                                tempSelection[section.key] = v ?? false;
                              });
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('audio_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedAudios = Map<String, bool>.from(tempSelection)
                        ..removeWhere((key, value) => value == false);
                      _currentAudioIndex = 0;
                      _isPlaying = false;
                      _currentPosition = Duration.zero;
                      _currentDuration = Duration.zero;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(tr('audio_ok')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ZMENA: Parameter `subtitle` je teraz non-nullable s predvolenou hodnotou.
  Widget _buildSection({
    required String? title,
    String subtitle = '',
    required String text,
  }) {
    // ZMENA: Zjednodušená podmienka, keďže `subtitle` už nemôže byť null.
    if (text.isEmpty && subtitle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.isNotEmpty)
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            // Podmienka `subtitle != null` je už zbytočná, ale neprekáža.
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  void _goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
    fetchLectioData();
  }

  void _goToNextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
    fetchLectioData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat(
      'dd.MM.yyyy',
      context.locale.toString(),
    ).format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;

    final playlist = _playlist;
    if (_currentAudioIndex >= playlist.length && playlist.isNotEmpty) {
      _currentAudioIndex = 0;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final expandedPlayerHeight = screenHeight * 0.55;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lectio divina"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchLectioData,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha((0.9 * 255).toInt()),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withAlpha(
                            (0.07 * 255).toInt(),
                          ),
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
                        Text(formattedDate, style: theme.textTheme.titleMedium),
                        IconButton(
                          tooltip: tr("next_day"),
                          icon: const Icon(Icons.chevron_right, size: 32),
                          onPressed: _goToNextDay,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : lectioData == null
                      ? Center(
                          child: Text(
                            tr("lectio_not_available"),
                            style: theme.textTheme.titleMedium,
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.only(
                            top: 10,
                            bottom:
                                (_isPlayerExpanded
                                    ? expandedPlayerHeight
                                    : 56) +
                                16,
                          ),
                          children: [
                            if ((lectioData?['hlava'] ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Center(
                                  child: Text(
                                    lectioData?['hlava'] ?? '',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
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
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/lectio_header.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            _buildSection(
                              title: tr("intro"),
                              text: lectioData?['uvod'] ?? '',
                            ),
                            _buildSection(
                              title: tr("video"),
                              text: lectioData?['video'] ?? '',
                            ),
                            _buildSection(
                              title: tr("prayer_intro"),
                              text: lectioData?['modlitba_uvod'] ?? '',
                            ),
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
                            ),
                            _buildSection(
                              title: tr("prayer_outro"),
                              text: lectioData?['modlitba_zaver'] ?? '',
                            ),
                            _buildSection(
                              title: tr("outro"),
                              text: lectioData?['zaver'] ?? '',
                            ),
                            _buildSection(
                              title: tr("blessing"),
                              text: lectioData?['pozehnanie'] ?? '',
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),
              height: _isPlayerExpanded ? expandedPlayerHeight : 56,
              curve: Curves.easeInOut,
              child: Material(
                elevation: 12,
                color: Colors.transparent,
                child: _isPlayerExpanded
                    ? Container(
                        color: theme.colorScheme.surface,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: Icon(Icons.expand_more),
                                onPressed: () =>
                                    setState(() => _isPlayerExpanded = false),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildAudioPlayer(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildMiniAudioPlayer(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

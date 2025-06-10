import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:lectio_divina/services/audio_handler.dart';
import 'package:lectio_divina/main.dart';
import 'note_detail_screen.dart'; // <- nezabudni importovať, ak ešte nie je!

class MediaState {
  final MediaItem? mediaItem;
  final PlaybackState playbackState;
  MediaState(this.mediaItem, this.playbackState);
}

class LectioScreen extends StatefulWidget {
  const LectioScreen({super.key, this.selectedLang});
  final String? selectedLang;

  @override
  State<LectioScreen> createState() => _LectioScreenState();
}

class _LectioScreenState extends State<LectioScreen> {
  Map<String, dynamic>? lectioData;
  bool isLoading = true;
  bool _dataLoaded = false;
  DateTime selectedDate = DateTime.now();
  String _selectedBible = 'biblia1';
  Map<String, bool> _selectedAudios = {};
  bool _isPlayerExpanded = false;

  // >>>>> PRIDANÉ: getter na usera
  User? get _currentUser => Supabase.instance.client.auth.currentUser;

  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, PlaybackState, MediaState>(
        audioHandler.mediaItem,
        audioHandler.playbackState,
        (mediaItem, playbackState) => MediaState(mediaItem, playbackState),
      );

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

  List<AudioSection> getAllAudioSections(BuildContext context) {
    final bibleSections = getBibleAudioSections(context);
    return [
      AudioSection(key: 'uvod_audio', label: tr('audio_intro')),
      AudioSection(key: 'modlitba_audio', label: tr('audio_prayer')),
      ...bibleSections,
      AudioSection(key: 'lectio_audio', label: tr('audio_lectio')),
      AudioSection(key: 'meditatio_audio', label: tr('audio_meditatio')),
      AudioSection(key: 'oratio_audio', label: tr('audio_oratio')),
      AudioSection(key: 'contemplatio_audio', label: tr('audio_contemplatio')),
      AudioSection(key: 'actio_audio', label: tr('audio_actio')),
      AudioSection(key: 'audio_5_min', label: tr('audio_5min')),
    ];
  }

  List<AudioSection> getBibleAudioSections(BuildContext context) {
    final List<AudioSection> bibleAudioSections = [];
    if (_selectedBible == 'biblia1' &&
        (lectioData?['biblia_1_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        AudioSection(key: 'biblia_1_audio', label: tr('audio_bible1')),
      );
    }
    if (_selectedBible == 'biblia2' &&
        (lectioData?['biblia_2_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        AudioSection(key: 'biblia_2_audio', label: tr('audio_bible2')),
      );
    }
    if (_selectedBible == 'biblia3' &&
        (lectioData?['biblia_3_audio'] ?? '').isNotEmpty) {
      bibleAudioSections.add(
        AudioSection(key: 'biblia_3_audio', label: tr('audio_bible3')),
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
    });
  }

  List<AudioSection> get _playlist => getAllAudioSections(context)
      .where(
        (section) =>
            (_selectedAudios[section.key] ?? false) &&
            (lectioData?[section.key] ?? '').toString().isNotEmpty,
      )
      .toList();

  Future<void> playOrPauseHandler(bool isPlaying) async {
    if (audioHandler.queue.valueOrNull == null ||
        audioHandler.queue.valueOrNull!.isEmpty) {
      if (_playlist.isEmpty) return;
      await audioHandler.loadPlaylist(lectioData!, _playlist);
    }
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  Widget _buildMiniAudioPlayer(BuildContext context) {
    return StreamBuilder<MediaState>(
      stream: _mediaStateStream,
      builder: (context, snapshot) {
        final mediaState = snapshot.data;
        final mediaItem = mediaState?.mediaItem;
        final playbackState = mediaState?.playbackState;
        final isPlaying = playbackState?.playing ?? false;

        return GestureDetector(
          onTap: () => setState(() => _isPlayerExpanded = true),
          child: AnimatedOpacity(
            opacity: (audioHandler.queue.valueOrNull?.isNotEmpty ?? false)
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
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
                      mediaItem?.title ?? tr('audio_player'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => playOrPauseHandler(isPlaying),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioPlayer(BuildContext context) {
    return StreamBuilder<MediaState>(
      stream: _mediaStateStream,
      builder: (context, snapshot) {
        final mediaState = snapshot.data;
        final mediaItem = mediaState?.mediaItem;
        final playbackState = mediaState?.playbackState;
        final isPlaying = playbackState?.playing ?? false;
        final processingState =
            playbackState?.processingState ?? AudioProcessingState.idle;
        final duration = mediaItem?.duration ?? Duration.zero;
        final sideControlsEnabled = mediaItem != null;

        return StreamBuilder<Duration>(
          stream: audioHandler.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.headphones,
                          color: Theme.of(context).primaryColor,
                        ),
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
                          onPressed: () => _showAudioSelectionPopup(
                            context,
                            getAllAudioSections(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mediaItem?.title ?? tr('audio_nothing_playing'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble() > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1.0,
                      value: position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                      onChanged: sideControlsEnabled && duration > Duration.zero
                          ? (value) {
                              audioHandler.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                            }
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position)),
                        Text(_formatDuration(duration)),
                      ],
                    ),
                    if (processingState == AudioProcessingState.loading ||
                        processingState == AudioProcessingState.buffering)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: sideControlsEnabled
                                ? audioHandler.skipToPrevious
                                : null,
                          ),
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            iconSize: 36,
                            onPressed: () => playOrPauseHandler(isPlaying),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: sideControlsEnabled
                                ? audioHandler.stop
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: sideControlsEnabled
                                ? audioHandler.skipToNext
                                : null,
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.playlist_play),
                        label: Text(tr('audio_play_selected')),
                        onPressed: _playlist.isEmpty
                            ? null
                            : () async {
                                await audioHandler.loadPlaylist(
                                  lectioData!,
                                  _playlist,
                                );
                                audioHandler.play();
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showAudioSelectionPopup(
    BuildContext context,
    List<AudioSection> sections,
  ) async {
    final Map<String, bool> tempSelection = Map<String, bool>.from(
      _selectedAudios,
    );
    final bool? result = await showDialog<bool>(
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
                      value: tempSelection[section.key] ?? false,
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
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('audio_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, true);
                  },
                  child: Text(tr('audio_ok')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _selectedAudios = tempSelection;
      });
      final newPlaylist = _playlist;
      if (newPlaylist.isNotEmpty) {
        await audioHandler.loadPlaylist(lectioData!, newPlaylist);
      } else {
        await audioHandler.stop();
      }
    }
  }

  Widget _buildSection({
    required String? title,
    String subtitle = '',
    required String text,
  }) {
    return _SimpleSection(title: title, subtitle: subtitle, text: text);
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

  // >>>>> PRIDANÉ: funkcia na otvorenie poznámky
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
      'title': formattedDate, // tu je dnesný dátum
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
    final expandedPlayerHeight = 360.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lectio divina"),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.note_add_outlined),
              tooltip: "Pridať poznámku",
              onPressed: _handleAddNote,
            ),
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
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            top: 10,
                            bottom:
                                (_isPlayerExpanded
                                    ? expandedPlayerHeight
                                    : 56) +
                                16,
                          ),
                          child: Column(
                            children: [
                              if ((lectioData?['hlava'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Center(
                                    child: Text(
                                      lectioData?['hlava'] ?? '',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
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
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
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

class _SimpleSection extends StatelessWidget {
  const _SimpleSection({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  final String? title;
  final String subtitle;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTitle = title;
    if (text.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 4,
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
                  ),
                ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';
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
    super.dispose();
  }

  Future<void> fetchLectioData() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final today = DateFormat('yyyy-MM-dd').format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;

    try {
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
        });
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
      });
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

  bool _hasAudio() {
    final audioUrl = lectioData?['lectio_audio'];
    return audioUrl != null && audioUrl.toString().isNotEmpty;
  }

  String _getAudioId() {
    final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);
    final lang = widget.selectedLang ?? context.locale.languageCode;
    return 'lectio_${dateString}_$lang';
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
      body: Container(
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
                                  style: theme.textTheme.titleMedium?.copyWith(
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
                        if ((lectioData?['suradnice_pismo'] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Center(
                              child: Text(
                                lectioData?['suradnice_pismo'] ?? '',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),

                        // Audio Player - zobrazí sa len ak má lectio_audio
                        if (_hasAudio())
                          UniversalAudioPlayer.lectio(
                            audioUrl: lectioData?['lectio_audio'],
                            title: lectioData?['hlava'] ?? 'Lectio Divina',
                            speaker: 'Dušan Pecko',
                            artworkUrl: null,
                            id: _getAudioId(),
                            audioPlayer: _audioPlayer,
                            config: AudioPlayerConfig.lectio.copyWith(
                              showTitle: true,
                              showAuthor: true,
                              showSkipButtons: true,
                              skipBackwardSeconds: 15,
                              skipForwardSeconds: 30,
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
                        ),
                        const SizedBox(height: 40),
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
            ],
          ),
        ),
      ),
    );
  }
}

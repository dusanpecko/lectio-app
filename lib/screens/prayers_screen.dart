import 'dart:async';
import '../services/audio_exclusive.dart';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';

import '../models/prayer.dart';
import '../services/prayers_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/audio/audio_progress_bar.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../shared/audio_player_factory.dart';

const List<String> _kCanonicalLangs = ['sk', 'cs', 'en', 'es', 'fr', 'pt-br'];

/// Zoradí jazykové varianty modlitby: aktuálny jazyk appky prvý, potom poradie.
List<Prayer> _orderVariants(List<Prayer> variants, String locale) {
  final order = <String>[
    locale,
    ..._kCanonicalLangs.where((l) => l != locale),
  ];
  int rank(String lang) {
    final i = order.indexOf(lang);
    return i < 0 ? 999 : i;
  }

  final list = [...variants]..sort((a, b) => rank(a.lang).compareTo(rank(b.lang)));
  return list;
}

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

enum _Status { loading, ready, error }

class _PrayersScreenState extends State<PrayersScreen> {
  _Status _status = _Status.loading;
  List<Prayer> _prayers = [];
  List<PrayerCategory> _categories = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Normalizácia pre vyhľadávanie — malé písmená bez diakritiky
  /// („otce nas" nájde „Otče náš").
  static String _fold(String s) {
    const from = 'áäàâãčćďéěëèêíîĺľňñóôöòõŕřšťúůüùûýžÁÄÀÂÃČĆĎÉĚËÈÊÍÎĹĽŇÑÓÔÖÒÕŔŘŠŤÚŮÜÙÛÝŽ';
    const to = 'aaaaaccdeeeeeiillnnooooorrstuuuuuyzaaaaaccdeeeeeiillnnooooorrstuuuuuyz';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Modlitba (skupina variantov) zodpovedá hľadaniu, ak sa dopyt nachádza
  /// v názve alebo texte KTORÉHOKOĽVEK jazykového variantu.
  bool _matches(List<Prayer> variants, String foldedQuery) {
    for (final p in variants) {
      if (_fold(p.title).contains(foldedQuery) ||
          _fold(p.content).contains(foldedQuery)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final prayers = await PrayersService.instance.fetchPrayers();
      final categories = await PrayersService.instance.fetchCategories();
      if (!mounted) return;
      setState(() {
        _prayers = prayers;
        _categories = categories;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  /// Lokalizovaný názov kategórie (fallback na kód).
  String _catLabel(String code) {
    final locale = context.locale.languageCode;
    for (final c in _categories) {
      if (c.code == code) return c.titleFor(locale);
    }
    return code;
  }

  /// Zoskupí modlitby: kategória → zoznam modlitieb (každá = jazykové varianty
  /// zoskupené podľa baseCode, zoradené aktuálny jazyk prvý).
  List<MapEntry<String, List<List<Prayer>>>> _grouped() {
    final locale = context.locale.languageCode;

    // base → varianty
    final byBase = <String, List<Prayer>>{};
    for (final p in _prayers) {
      byBase.putIfAbsent(p.baseCode, () => []).add(p);
    }

    // kategória → zoznam skupín (každá skupina = zoradené varianty);
    // pri aktívnom hľadaní prežijú len skupiny so zhodou v niektorom variante
    final foldedQuery = _fold(_query.trim());
    final byCat = <String, List<List<Prayer>>>{};
    for (final variants in byBase.values) {
      if (foldedQuery.isNotEmpty && !_matches(variants, foldedQuery)) continue;
      final ordered = _orderVariants(variants, locale);
      final primary = ordered.first;
      byCat.putIfAbsent(primary.category, () => []).add(ordered);
    }

    // zoradenie skupín v rámci kategórie podľa primárnej modlitby
    for (final groups in byCat.values) {
      groups.sort((a, b) {
        final pa = a.first;
        final pb = b.first;
        if (pa.displayOrder != pb.displayOrder) {
          return pa.displayOrder.compareTo(pb.displayOrder);
        }
        return pa.title.compareTo(pb.title);
      });
    }

    final catOrder = _categories.map((c) => c.code).toList();
    final ordered = <MapEntry<String, List<List<Prayer>>>>[];
    for (final code in catOrder) {
      if (byCat.containsKey(code)) ordered.add(MapEntry(code, byCat[code]!));
    }
    for (final entry in byCat.entries) {
      if (!catOrder.contains(entry.key)) ordered.add(entry);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            if (_status == _Status.ready && _prayers.isNotEmpty)
              _buildSearchField(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'prayers.title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'prayers.subtitle'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 15, color: HomeV2.textDark(context)),
        decoration: InputDecoration(
          hintText: 'prayers.search_hint'.tr(),
          hintStyle: TextStyle(color: HomeV2.textMuted(context)),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: HomeV2.textMuted(context),
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: HomeV2.textMuted(context),
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: HomeV2.card(context),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: HomeV2.primary.withValues(alpha: 0.10),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: HomeV2.primary.withValues(alpha: 0.10),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: HomeV2.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_status == _Status.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_status == _Status.error) {
      return _buildMessage(
        Icons.cloud_off_rounded,
        'prayers.error'.tr(),
        action: TextButton.icon(
          onPressed: _load,
          icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
          label: Text(
            'retry'.tr(),
            style: TextStyle(color: HomeV2.primary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (_prayers.isEmpty) {
      return _buildMessage(Icons.menu_book_outlined, 'prayers.empty'.tr());
    }

    final groups = _grouped();
    final locale = context.locale.languageCode;

    if (groups.isEmpty && _query.trim().isNotEmpty) {
      return _buildMessage(
        Icons.search_off_rounded,
        'prayers.search_empty'.tr(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: HomeV2.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        children: [
          for (final cat in groups) ...[
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, AppSpacing.md),
              child: Text(
                _catLabel(cat.key),
                style: HomeV2.serifTitle(context, size: 20),
              ),
            ),
            ...cat.value.map((variants) => _buildPrayerCard(variants, locale)),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _buildPrayerCard(List<Prayer> variants, String locale) {
    final primary = variants.first;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrayerDetailScreen(
                  variants: variants,
                  categoryLabel: _catLabel(primary.category),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeV2.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      size: 22, color: HomeV2.iconAccent(context)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: HomeV2.textDark(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (variants.length > 1) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: variants
                              .map((v) => _langChip(v.langBadge,
                                  active: v.lang == locale))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (variants.any((v) => v.hasAudio)) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.headphones_rounded,
                      size: 18, color: HomeV2.iconAccent(context)),
                ],
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded,
                    color: HomeV2.textMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _langChip(String code, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? HomeV2.primary.withValues(alpha: 0.12)
            : HomeV2.textMuted(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: active ? HomeV2.iconAccent(context) : HomeV2.textMuted(context),
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Detail modlitby — jazykové slidy (aktuálny jazyk prvý)
// ═════════════════════════════════════════════════════════════════════════════
class PrayerDetailScreen extends StatefulWidget {
  /// Jazykové varianty tej istej modlitby, už zoradené (aktuálny jazyk prvý).
  final List<Prayer> variants;
  final String categoryLabel;
  const PrayerDetailScreen({
    super.key,
    required this.variants,
    required this.categoryLabel,
  });

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  late final PageController _controller = PageController();
  int _index = 0;

  final AudioPlayer _player = createAppAudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _isPlaying = false;
  bool _audioLoading = false;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      if (completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      setState(() => _isPlaying = state.playing && !completed);
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    AudioExclusive.release(_player);
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  Prayer get _current => widget.variants[_index];

  Future<void> _toggleAudio() async {
    final url = _current.audioUrl;
    if (url == null) return;
    HapticFeedback.lightImpact();
    try {
      // Výhradný slot natívneho playera (just_audio_background = 1 naraz).
      await AudioExclusive.acquire(_player);
      if (_loadedUrl != url) {
        setState(() => _audioLoading = true);
        // just_audio_background vyžaduje MediaItem tag na každom zdroji.
        // LockCaching: stream + disková cache → seek a opakované prehratie
        // modlitby sú okamžité (fix 7.7.2026).
        await _player.setAudioSource(
          // ignore: experimental_member_use  (LockCaching je stabilný napriek @experimental)
          LockCachingAudioSource(
            Uri.parse(url),
            tag: MediaItem(
              id: _current.shortcode,
              album: 'prayers.title'.tr(),
              title: _current.title,
              artist: widget.categoryLabel,
            ),
          ),
        );
        _loadedUrl = url;
        if (mounted) setState(() => _audioLoading = false);
        await _player.play();
      } else if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (e) {
      debugPrint('❌ Prayer audio play failed: $e');
      _loadedUrl = null;
      if (mounted) {
        setState(() => _audioLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeV2.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            content: Text('prayers.audio_error'.tr()),
          ),
        );
      }
    }
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Skopíruje text aktuálnej (jazykovej) modlitby do schránky.
  Future<void> _copyCurrent() async {
    final raw = _current.content;
    final text = _isHtml(raw) ? _htmlToPlain(raw) : raw;
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HomeV2.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        duration: const Duration(seconds: 2),
        content: Text('copied_to_clipboard'.tr()),
      ),
    );
  }

  String _htmlToPlain(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Pri zmene jazykového slidu resetuj prehrávač (audio je per-jazyk),
  /// aby progres ukazoval 0:00 pre nový jazyk.
  void _onPageChanged(int i) {
    _player.stop();
    _loadedUrl = null;
    setState(() {
      _index = i;
      _isPlaying = false;
    });
  }

  bool _isHtml(String s) =>
      RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(s);

  @override
  Widget build(BuildContext context) {
    final multi = widget.variants.length > 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(multi),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.variants.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (_, i) => _buildSlide(widget.variants[i]),
              ),
            ),
            if (_current.hasAudio) _buildPlayerBar(),
          ],
        ),
      ),
    );
  }

  /// Spodný mini-prehrávač s play/pause a progresom (ako v lectio).
  Widget _buildPlayerBar() {
    return Container(
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              _AudioButton(
                isPlaying: _isPlaying,
                loading: _audioLoading,
                onTap: _toggleAudio,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AudioProgressBar(
                  audioPlayer: _player,
                  accentColor: HomeV2.primary,
                  onSeek: (pos) => _player.seek(pos),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool multi) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        multi ? AppSpacing.md : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              _CircleButton(
                icon: Icons.copy_rounded,
                onTap: _copyCurrent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _current.title,
            style: HomeV2.serifTitle(context, size: 27, height: 1.15),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.categoryLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomeV2.gold,
            ),
          ),
          if (multi) ...[
            const SizedBox(height: AppSpacing.md),
            // Jazykové záložky
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.variants.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final active = i == _index;
                  return GestureDetector(
                    onTap: () => _goTo(i),
                    child: AnimatedContainer(
                      duration: HomeV2.anim,
                      curve: HomeV2.curve,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? HomeV2.primary
                            : HomeV2.card(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow:
                            active ? null : HomeV2.softShadowSm(context),
                      ),
                      child: Text(
                        widget.variants[i].langBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : HomeV2.textMuted(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlide(Prayer prayer) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
      ),
      children: [
        if (_isHtml(prayer.content))
          Html(
            data: prayer.content,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(17),
                lineHeight: const LineHeight(1.7),
                color: HomeV2.textDark(context),
              ),
            },
          )
        else
          SelectableText(
            prayer.content,
            style: TextStyle(
              fontSize: 17,
              height: 1.75,
              color: HomeV2.textDark(context),
            ),
          ),
      ],
    );
  }
}

/// Plné kruhové tlačidlo na prehratie/pozastavenie zvukovej nahrávky modlitby.
class _AudioButton extends StatelessWidget {
  final bool isPlaying;
  final bool loading;
  final VoidCallback onTap;
  const _AudioButton({
    required this.isPlaying,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

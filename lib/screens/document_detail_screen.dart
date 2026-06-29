import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/pdf_document.dart';
import '../services/documents_service.dart';
import '../services/media_player_bus.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// Prehrávač dokumentu — vizuálne aj funkčne podľa mobilnej verzie webu
/// (`/[locale]/dokumenty`): flip obálka, kapitolové bodky/počítadlo, transport
/// (predchádzajúca/-15s/play/+15s/ďalšia), progress a režim čítania textu.
class DocumentDetailScreen extends StatefulWidget {
  final PdfDocument document;
  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

enum _Status { loading, ready, error }

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  static const int _maxDots = 9;

  _Status _status = _Status.loading;
  List<DocChapter> _chapters = [];

  int _activeIndex = -1; // index práve načítanej kapitoly tejto obrazovky
  bool _showText = false;
  bool _coverFlipped = false;

  StreamSubscription<ProcessingState>? _procSub;

  MediaPlayerBus get _bus => MediaPlayerBus.instance;
  PdfDocument get _doc => widget.document;

  @override
  void initState() {
    super.initState();
    _load();
    // Autoplay ďalšej kapitoly po dohraní.
    _procSub = _bus.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) return;
      if (_activeIndex < 0 || _activeIndex >= _chapters.length) return;
      if (!_bus.isCurrent(_audioId(_chapters[_activeIndex]))) return;
      if (_activeIndex < _chapters.length - 1) {
        _startPlay(_activeIndex + 1);
      }
    });
  }

  @override
  void dispose() {
    _procSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final detail = await DocumentsService.instance.fetchDetail(_doc.slug);
      if (!mounted) return;
      // Ak už hrá kapitola tohto dokumentu, zosynchronizuj aktívny index.
      var active = -1;
      for (var i = 0; i < detail.chapters.length; i++) {
        if (_bus.isCurrent(_audioId(detail.chapters[i]))) {
          active = i;
          break;
        }
      }
      setState(() {
        _chapters = detail.chapters;
        _activeIndex = active;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  String _audioId(DocChapter ch) => 'doc_${_doc.slug}_ch_${ch.chapterIndex}';

  String _chapterLabel(DocChapter ch, int displayNo) {
    final t = ch.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '${'documents.chapter'.tr()} $displayNo';
  }

  // ── Transport ────────────────────────────────────────────────────────────
  void _startPlay(int index) {
    if (index < 0 || index >= _chapters.length) return;
    final ch = _chapters[index];
    if (ch.audioUrl == null || ch.audioUrl!.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _activeIndex = index);
    _bus.play(
      id: _audioId(ch),
      url: ch.audioUrl!,
      title: _chapterLabel(ch, index + 1),
      artUri: _doc.coverImageUrl,
      contentType: 'document',
      contentId: _doc.slug,
      language: _doc.lang,
    );
  }

  void _togglePlay() {
    if (_activeIndex < 0) {
      if (_chapters.isNotEmpty) _startPlay(0);
      return;
    }
    final ch = _chapters[_activeIndex];
    if (ch.audioUrl == null || ch.audioUrl!.isEmpty) return;
    HapticFeedback.lightImpact();
    _bus.toggle(
      id: _audioId(ch),
      url: ch.audioUrl!,
      title: _chapterLabel(ch, _activeIndex + 1),
      artUri: _doc.coverImageUrl,
      contentType: 'document',
      contentId: _doc.slug,
      language: _doc.lang,
    );
  }

  bool get _isActiveCurrent =>
      _activeIndex >= 0 && _bus.isCurrent(_audioId(_chapters[_activeIndex]));

  void _prev() => _startPlay(_activeIndex - 1);
  void _next() => _startPlay(_activeIndex + 1);

  void _rewind15() {
    if (!_isActiveCurrent) return;
    final p = _bus.position - const Duration(seconds: 15);
    _bus.seek(p < Duration.zero ? Duration.zero : p);
  }

  void _forward15() {
    if (!_isActiveCurrent) return;
    final dur = _bus.duration ?? Duration.zero;
    final p = _bus.position + const Duration(seconds: 15);
    _bus.seek(p > dur ? dur : p);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
        body: SafeArea(
          bottom: false,
          child: _status == _Status.loading
              ? const Center(child: CircularProgressIndicator())
              : _status == _Status.error
                  ? _buildError()
                  : (_showText ? _buildTextView() : _buildPlayerView()),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: HomeV2.textMuted(context)),
          const SizedBox(height: AppSpacing.md),
          Text('documents.error'.tr(),
              style: TextStyle(color: HomeV2.textMuted(context))),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
            label: Text('retry'.tr(),
                style: TextStyle(
                    color: HomeV2.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  DocChapter? get _activeChapter =>
      _activeIndex >= 0 && _activeIndex < _chapters.length
          ? _chapters[_activeIndex]
          : null;

  // ── Player view ─────────────────────────────────────────────────────────
  Widget _buildPlayerView() {
    final active = _activeChapter;
    final label = active != null
        ? _chapterLabel(active, _activeIndex + 1)
        : (_chapters.isNotEmpty
            ? _chapterLabel(_chapters.first, 1)
            : 'documents.select_chapter'.tr());
    final hasText = _chapters.any((c) => c.content.trim().isNotEmpty);

    return Column(
      children: [
        _topBar(centerLabel: 'documents.title'.tr()),
        // Flip cover
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: Center(child: _buildFlipCover()),
          ),
        ),
        // Title + chapter
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: Column(
            children: [
              Text(
                _doc.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: HomeV2.gold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: HomeV2.serifTitle(context, size: 22, height: 1.15),
              ),
            ],
          ),
        ),
        _buildDots(),
        _buildControls(),
        _buildProgressBar(),
        if (hasText)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showText = true),
              icon: const Icon(Icons.notes_rounded, size: 16),
              label: Text('documents.show_text'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeV2.iconAccent(context),
                side: BorderSide(
                  color: HomeV2.primary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + AppSpacing.lg),
      ],
    );
  }

  Widget _topBar({required String centerLabel, VoidCallback? onClose}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          _circleIcon(
            onClose != null ? Icons.close_rounded : Icons.chevron_left_rounded,
            onClose ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              centerLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: HomeV2.iconAccent(context), size: 24),
        ),
      ),
    );
  }

  // ── Flip cover ────────────────────────────────────────────────────────────
  Widget _buildFlipCover() {
    final hasDescription =
        _doc.description != null && _doc.description!.trim().isNotEmpty;
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: hasDescription
            ? () {
                HapticFeedback.lightImpact();
                setState(() => _coverFlipped = !_coverFlipped);
              }
            : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _coverFlipped ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) {
            final angle = t * math.pi;
            final showBack = t > 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _coverBack(),
                    )
                  : _coverFront(hasDescription),
            );
          },
        ),
      ),
    );
  }

  Widget _coverFront(bool hasDescription) {
    final cover = _doc.coverImageUrl;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeV2.radius + 4),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null && cover.isNotEmpty)
            CachedNetworkImage(
              imageUrl: cover,
              fit: BoxFit.cover,
              placeholder: (_, _) => _coverFallback(),
              errorWidget: (_, _, _) => _coverFallback(),
            )
          else
            _coverFallback(),
          if (hasDescription)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'i',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coverFallback() {
    return ColoredBox(
      color: HomeV2.primary.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 56,
          color: HomeV2.iconAccent(context).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _coverBack() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.primary,
        borderRadius: BorderRadius.circular(HomeV2.radius + 4),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _doc.langBadge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: Text(
              _doc.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HomeV2.serifTitle(context, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(width: 32, height: 1, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: Text(
              _doc.description ?? '',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'documents.flip_hint'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chapter dots / counter ────────────────────────────────────────────────
  Widget _buildDots() {
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: _chapters.isEmpty
          ? const SizedBox.shrink()
          : _chapters.length <= _maxDots
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_chapters.length, (i) {
                    final active = i == _activeIndex;
                    return GestureDetector(
                      onTap: () => _startPlay(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? HomeV2.primary
                              : HomeV2.primary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                )
              : Text(
                  _activeIndex >= 0
                      ? '${_activeIndex + 1} / ${_chapters.length}'
                      : '— / ${_chapters.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
                  ),
                ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  Widget _buildControls({bool compact = false}) {
    final hasActive = _activeIndex >= 0;
    final canPrev = _activeIndex > 0;
    final canNext = hasActive && _activeIndex < _chapters.length - 1;
    final big = compact ? 48.0 : 64.0;

    return StreamBuilder<bool>(
      stream: _bus.playingStream,
      builder: (context, snap) {
        final playing = _isActiveCurrent && (snap.data ?? _bus.isPlaying);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ctrlIcon(Icons.skip_previous_rounded, canPrev ? _prev : null,
                size: compact ? 22 : 26),
            _ctrlIcon(Icons.replay_rounded, hasActive ? _rewind15 : null,
                size: compact ? 20 : 24, badge: '15'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Material(
                color: (_chapters.isEmpty) ? HomeV2.primary.withValues(alpha: 0.4) : HomeV2.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _chapters.isEmpty ? null : _togglePlay,
                  child: SizedBox(
                    width: big,
                    height: big,
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: compact ? 26 : 32,
                    ),
                  ),
                ),
              ),
            ),
            _ctrlIcon(Icons.forward_rounded, hasActive ? _forward15 : null,
                size: compact ? 20 : 24, badge: '15'),
            _ctrlIcon(Icons.skip_next_rounded, canNext ? _next : null,
                size: compact ? 22 : 26),
          ],
        );
      },
    );
  }

  Widget _ctrlIcon(IconData icon, VoidCallback? onTap,
      {double size = 24, String? badge}) {
    final color = onTap == null
        ? HomeV2.textMuted(context).withValues(alpha: 0.3)
        : HomeV2.iconAccent(context);
    final child = badge == null
        ? Icon(icon, size: size, color: color)
        : Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: size + 4, color: color),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          );
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }

  // ── Progress ──────────────────────────────────────────────────────────────
  Widget _buildProgressBar({bool compact = false}) {
    return StreamBuilder<Duration>(
      stream: _bus.positionStream,
      builder: (context, snap) {
        final pos = _isActiveCurrent ? (snap.data ?? Duration.zero) : Duration.zero;
        final dur = _isActiveCurrent ? (_bus.duration ?? Duration.zero) : Duration.zero;
        final max = dur.inMilliseconds.toDouble();
        final value =
            max > 0 ? pos.inMilliseconds.clamp(0, max).toDouble() : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: compact ? 0 : AppSpacing.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(_fmt(pos),
                    textAlign: TextAlign.right, style: _timeStyle()),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: HomeV2.primary,
                    inactiveTrackColor: HomeV2.primary.withValues(alpha: 0.16),
                    thumbColor: HomeV2.primary,
                  ),
                  child: Slider(
                    value: value,
                    max: max > 0 ? max : 1,
                    onChanged: max > 0 && _isActiveCurrent
                        ? (v) => _bus.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(_fmt(dur), style: _timeStyle()),
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _timeStyle() =>
      TextStyle(fontSize: 11, color: HomeV2.textMuted(context));

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Text view (čítačka) ─────────────────────────────────────────────────────
  Widget _buildTextView() {
    final ch = _activeChapter ?? (_chapters.isNotEmpty ? _chapters.first : null);
    final content = ch?.content.trim() ?? '';
    final chapterTitle = ch != null
        ? _chapterLabel(ch, (_activeIndex >= 0 ? _activeIndex : 0) + 1)
        : '—';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (_doc.coverImageUrl != null &&
                  _doc.coverImageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: _doc.coverImageUrl!,
                    width: 36,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _doc.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: HomeV2.iconAccent(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showText = false);
                  },
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.close_rounded,
                        size: 20, color: HomeV2.iconAccent(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.10)),
        const SizedBox(height: AppSpacing.sm),
        _buildControls(compact: true),
        _buildProgressBar(compact: true),
        _buildDots(),
        Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.10)),
        Expanded(
          child: content.isEmpty
              ? Center(
                  child: Text(
                    'documents.text_unavailable'.tr(),
                    style: TextStyle(color: HomeV2.textMuted(context)),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                  ),
                  children: [
                    SelectableText(
                      content,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.85,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

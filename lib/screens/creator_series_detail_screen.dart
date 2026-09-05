import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/creator.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/brand_loading.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'creator_session_screen.dart';

/// Detail série tvorcu vo v2 štýle: fixný hero (obálka + názov/autor/počet
/// častí) → karta „O sérii" → časti ako full-width slide carousel (vzor
/// featured carousel na home) s obrázkom každej časti.
/// Poradie kariet: NAJNOVŠIA ČASŤ PRVÁ (posledne pridaná = prvý slide), takže
/// vracajúci sa poslucháč vidí nový obsah hneď. Číslo časti na karte je vždy
/// skutočné `session.order`, nie index.
class CreatorSeriesDetailScreen extends StatefulWidget {
  const CreatorSeriesDetailScreen({
    super.key,
    required this.item,
    required this.accent,
    required this.creatorSlug,
  });
  final CreatorContentItem item;
  final Color accent;
  final String creatorSlug; // pre zdieľanie verejnej URL série

  @override
  State<CreatorSeriesDetailScreen> createState() => _CreatorSeriesDetailScreenState();
}

class _CreatorSeriesDetailScreenState extends State<CreatorSeriesDetailScreen> {
  CreatorSeriesDetail? _series;
  bool _loading = true;

  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Event: zobrazenie série (creator štatistiky, Fáza 3).
    CreatorsService.instance.track(programId: widget.item.id, action: 'view');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await CreatorsService.instance.fetchSeries(widget.item.id);
    if (!mounted) return;
    setState(() {
      _series = data;
      _loading = false;
    });
  }

  /// Časti v poradí na zobrazenie — najnovšia (najvyššie poradie) prvá.
  /// API vracia vzostupne (kanonické poradie série); reverz je len prezentácia.
  List<CreatorSession> get _slides {
    final list = [...(_series?.sessions ?? const <CreatorSession>[])];
    list.sort((a, b) => b.order.compareTo(a.order));
    return list;
  }

  /// Zdieľanie verejnej stránky série na subdoméne tvorcu.
  Future<void> _shareSeries() async {
    final locale = context.locale.languageCode;
    final url = 'https://${widget.creatorSlug}.lectio.one/$locale/s/${widget.item.refId}';
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: '${widget.item.title}\n$url',
      subject: widget.item.title,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  }

  void _openSession(CreatorSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreatorSessionScreen(
        session: session,
        accent: widget.accent,
        programId: widget.item.id,
      ),
      settings: const RouteSettings(name: '/creator-session'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = _series;
    final slides = _slides;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _hero(s),
            Expanded(
              child: (_loading && s == null)
                  ? const BrandLoading()
                  : s == null
                      ? Center(
                          child: Text(tr('creator_open_failed'),
                              style: TextStyle(color: HomeV2.textMuted(context))),
                        )
                      : ListView(
                          padding: EdgeInsets.only(
                            bottom: AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          children: [
                            if (s.description != null && s.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _sectionCard(
                                tr('creator_series_about'),
                                Text(s.description!,
                                    style: TextStyle(fontSize: 15, height: 1.55, color: HomeV2.textDark(context))),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            if (slides.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                child: Text(tr('creator_series_no_parts'),
                                    style: TextStyle(color: HomeV2.textMuted(context))),
                              )
                            else
                              _partsCarousel(slides),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero (v2 vzor: obálka + gradient do pozadia, kruhové tlačidlá) ──────────
  Widget _hero(CreatorSeriesDetail? s) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final img = s?.imageUrl ?? widget.item.imageUrl;
    final title = s?.title ?? widget.item.title;
    final count = s?.sessions.length;
    final author = s?.author;

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: (img != null && img.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, _) => _heroFallback(),
                    errorWidget: (_, _, _) => _heroFallback(),
                  )
                : _heroFallback(),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: 0.45), Colors.transparent, bg.withValues(alpha: 0.7), bg],
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.of(context).maybePop()),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            right: AppSpacing.lg,
            child: _circleBtn(Icons.ios_share_rounded, _shareSeries),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: HomeV2.serifTitle(context, size: 22, color: HomeV2.textDark(context), height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (count != null && count > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    tr('creator_series_parts', namedArgs: {'count': '$count'}),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.accent),
                  ),
                ],
                if (author != null && author.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    author,
                    style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFallback() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.accent, widget.accent.withValues(alpha: 0.65)],
          ),
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ── Časti ako slide carousel (vzor featured carousel na home) ───────────────
  Widget _partsCarousel(List<CreatorSession> slides) {
    final mq = MediaQuery.of(context);
    // Na tablete vyššia karta; v landscape ešte vyššia (inak je karta na šírku nízka).
    final cardH = mq.size.shortestSide < 600
        ? 200.0
        : (mq.orientation == Orientation.landscape ? 300.0 : 260.0);
    final multi = slides.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(tr('creator_section_series'), style: HomeV2.serifTitle(context, size: 19)),
              ),
              if (multi)
                Text(tr('creator_series_newest_first'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HomeV2.textMuted(context))),
            ],
          ),
        ),
        SizedBox(
          height: cardH,
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SessionSlide(
              session: slides[i],
              seriesImage: _series?.imageUrl ?? widget.item.imageUrl,
              accent: widget.accent,
              height: cardH,
              onTap: () => _openSession(slides[i]),
            ),
          ),
        ),
        if (multi) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == _page.clamp(0, slides.length - 1);
              return AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? widget.accent : widget.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HomeV2.serifTitle(context, size: 19)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Karta jednej časti ako slide (vzor FeaturedProjectCard na home): obrázok
/// časti na celú plochu + gradient + zlatý overline „Časť N" + serif názov.
/// Bez vlastného obrázka spadne na obálku série, potom na accent gradient.
class _SessionSlide extends StatelessWidget {
  const _SessionSlide({
    required this.session,
    required this.seriesImage,
    required this.accent,
    required this.height,
    required this.onTap,
  });
  final CreatorSession session;
  final String? seriesImage;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = (session.imageUrl != null && session.imageUrl!.isNotEmpty)
        ? session.imageUrl
        : ((seriesImage != null && seriesImage!.isNotEmpty) ? seriesImage : null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (img != null)
                CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _fallbackBg(),
                  errorWidget: (_, _, _) => _fallbackBg(),
                )
              else
                _fallbackBg(),

              // Gradient pre čitateľnosť textu (rovnaký ako home slide).
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black26, Colors.black87],
                    stops: [0.35, 0.65, 1.0],
                  ),
                ),
              ),

              // Play indikátor vpravo hore — naznačí, že karta je prehrávateľná.
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),

              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, size: 15, color: HomeV2.goldLight),
                        const SizedBox(width: 6),
                        Text(
                          tr('creator_part_number', namedArgs: {'n': '${session.order}'}).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: HomeV2.goldLight,
                          ),
                        ),
                        if (session.durationMinutes != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text('· ${session.durationMinutes} min',
                              style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.title,
                      style: HomeV2.serifTitle(context, size: 20).copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (session.description != null && session.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        session.description!,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBg() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.85), accent],
          ),
        ),
      );
}

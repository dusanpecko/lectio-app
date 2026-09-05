import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';

import '../models/creator.dart';
import '../services/creators_service.dart';
import '../services/novenas_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/brand_loading.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'creator_podcast_detail_screen.dart';
import 'creator_rosary_detail_screen.dart';
import 'creator_series_detail_screen.dart';
import 'adoration_detail_screen.dart';
import 'stations_of_cross_detail_screen.dart';
import 'creator_exercise_detail_screen.dart';
import 'creators_screen.dart' show creatorAccentColor;
import 'novena_detail_screen.dart';

/// Detail tvorcu — hero (foto + meno), bio a jeho obsah po sekciách
/// (série / deviatniky / adorácie / krížové cesty / ružence / podcasty).
/// v1 = prehľad (browse); prehrávanie/detail položiek pridáme v ďalšom kroku.
class CreatorDetailScreen extends StatefulWidget {
  const CreatorDetailScreen({super.key, required this.summary});
  final CreatorSummary summary;

  @override
  State<CreatorDetailScreen> createState() => _CreatorDetailScreenState();
}

class _CreatorDetailScreenState extends State<CreatorDetailScreen> {
  CreatorBundle? _bundle;
  bool _loading = true;
  String? _loadedLang;

  int _followers = 0;
  bool _following = false;
  bool _followBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.locale.languageCode;
    if (lang != _loadedLang) {
      _loadedLang = lang;
      _load(lang);
    }
  }

  Future<void> _load(String lang) async {
    if (mounted) setState(() => _loading = true);
    final data = await CreatorsService.instance.fetchCreator(widget.summary.slug, lang);
    if (!mounted) return;
    setState(() {
      _bundle = data;
      _loading = false;
      _followers = data?.creator.followerCount ?? 0;
    });
    // Aktuálny stav sledovania (autoritatívny počet + či ho tento používateľ sleduje).
    if (data != null) {
      final st = await CreatorsService.instance.followStatus(data.creator.id);
      if (!mounted) return;
      setState(() {
        _followers = st.count;
        _following = st.following;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final b = _bundle;
    if (b == null || _followBusy) return;
    setState(() => _followBusy = true);
    final res = await CreatorsService.instance.setFollow(b.creator.id, !_following);
    if (!mounted) return;
    setState(() => _followBusy = false);
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('creator_login_to_follow'))));
      return;
    }
    setState(() {
      _following = res.following;
      _followers = res.count;
    });
  }

  /// Klik na položku — otvorí detail podľa typu.
  Future<void> _open(CreatorContentItem item) async {
    final accent = creatorAccentColor(widget.summary.accent);
    switch (item.kind) {
      case CreatorItemKind.novena:
        await _openNovena(item);
      case CreatorItemKind.podcast:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorPodcastDetailScreen(podcast: item, accent: accent),
          settings: const RouteSettings(name: '/creator-podcast'),
        ));
      case CreatorItemKind.series:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorSeriesDetailScreen(
            item: item,
            accent: accent,
            creatorSlug: widget.summary.slug,
          ),
          settings: const RouteSettings(name: '/creator-series'),
        ));
      case CreatorItemKind.rosary:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorRosaryDetailScreen(item: item, accent: accent),
          settings: const RouteSettings(name: '/creator-rosary'),
        ));
      case CreatorItemKind.adoration:
        // Zdieľaná tabuľka lectio_divina_adoracia → hlavný v2 detail podľa id.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdorationDetailScreen(adorationId: item.id),
          settings: const RouteSettings(name: '/creator-adoration'),
        ));
      case CreatorItemKind.station:
        // Zdieľaná tabuľka krizove_cesty → hlavný v2 detail podľa id.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StationsOfCrossDetailScreen(stationsOfCrossId: item.id),
          settings: const RouteSettings(name: '/creator-stations'),
        ));
      case CreatorItemKind.exercise:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorExerciseDetailScreen(item: item, accent: accent),
          settings: const RouteSettings(name: '/creator-exercise'),
        ));
    }
  }

  /// Deviatnik — dotiahne plný obsah zo zdieľanej tabuľky a otvorí existujúcu obrazovku.
  Future<void> _openNovena(CreatorContentItem item) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final novena = await NovenasService.instance.fetchNovenaById(item.id);
    if (!mounted) return;
    Navigator.of(context).pop(); // zavri loader
    if (novena == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('creator_open_failed'))));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NovenaDetailScreen(variants: [novena]),
      settings: const RouteSettings(name: '/novena-detail'),
    ));
  }

  /// Zdieľanie verejnej stránky tvorcu (subdoména) — akvizičný odkaz.
  Future<void> _shareCreator() async {
    final s = widget.summary;
    final locale = context.locale.languageCode;
    final url = 'https://${s.slug}.lectio.one/$locale';
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: '${s.displayName}\n$url',
      subject: s.displayName,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final accent = creatorAccentColor(s.accent);
    final b = _bundle;

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
            _CreatorHero(
              name: s.displayName,
              title: s.title,
              photoUrl: s.photoUrl,
              accent: accent,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: _shareCreator,
            ),
            Expanded(
              child: (_loading && b == null)
                  ? const BrandLoading()
                  : b == null
                      ? const SizedBox.shrink()
                      : CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(child: _followBar(context, accent)),
                            if (b.creator.bio != null && b.creator.bio!.isNotEmpty)
                              SliverToBoxAdapter(child: _bio(context, b.creator.bio!)),
                            ..._sectionSlivers(context, b, accent),
                            SliverToBoxAdapter(
                              child: SizedBox(height: AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bio(BuildContext context, String html) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        child: Html(
          data: html,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(15),
              lineHeight: const LineHeight(1.6),
              color: HomeV2.textDark(context),
            ),
          },
        ),
      );

  /// Lišta sledovania — počet sledovateľov + tlačidlo Sledovať/Sledované.
  Widget _followBar(BuildContext context, Color accent) {
    final followingLabel = _following ? tr('creator_following') : tr('creator_follow');
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Row(
        children: [
          Icon(Icons.people_alt_rounded, size: 18, color: accent),
          const SizedBox(width: 6),
          Text(
            '$_followers ${tr('creator_followers')}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: HomeV2.textDark(context),
            ),
          ),
          const Spacer(),
          _FollowButton(
            following: _following,
            busy: _followBusy,
            accent: accent,
            label: followingLabel,
            onTap: _toggleFollow,
          ),
        ],
      ),
    );
  }

  List<Widget> _sectionSlivers(BuildContext context, CreatorBundle b, Color accent) {
    final sections = <(String, List<CreatorContentItem>)>[
      ('creator_section_series', b.series),
      ('creator_section_novenas', b.novenas),
      ('creator_section_adorations', b.adorations),
      ('creator_section_stations', b.stations),
      ('creator_section_rosaries', b.rosaries),
      ('creator_section_podcasts', b.podcasts),
      ('creator_section_exercises', b.exercises),
    ];
    final out = <Widget>[];
    for (final (key, items) in sections) {
      if (items.isEmpty) continue;
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
          child: Text(tr(key), style: HomeV2.serifTitle(context, size: 20)),
        ),
      ));
      // Položky sekcie ako full-width slide (jedna na šírku, swipe) — vhodné kým je
      // obsahu málo; neskôr sa dá vrátiť na užšie dlaždice.
      out.add(SliverToBoxAdapter(child: _SectionCarousel(items: items, accent: accent, onOpen: _open)));
    }
    return out;
  }
}

/// Fixný hero profilu tvorcu — vzor ako deviatnik/adorácia: foto na celú plochu
/// + gradient do pozadia, kruhové tlačidlá (späť/zdieľať), bez ikony, meno
/// (serif) + titul dole vľavo (left-aligned).
class _CreatorHero extends StatelessWidget {
  const _CreatorHero({
    required this.name,
    this.title,
    this.photoUrl,
    required this.accent,
    required this.onBack,
    required this.onShare,
  });
  final String name;
  final String? title;
  final String? photoUrl;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final img = (photoUrl != null && photoUrl!.isNotEmpty) ? photoUrl : null;

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: img != null
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, _) => _HeroFallback(accent: accent),
                    errorWidget: (_, _, _) => _HeroFallback(accent: accent),
                  )
                : _HeroFallback(accent: accent),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HomeV2.radius + 6)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Menej „do stratena": foto ostáva výrazné v strede, len horný jemný
                // scrim (pre tlačidlá) a spodný okraj plynie do pozadia (pre text).
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.transparent,
                    bg.withValues(alpha: 0.72),
                    bg,
                  ],
                  stops: const [0.0, 0.2, 0.6, 0.9, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            right: AppSpacing.lg,
            child: _CircleBtn(icon: Icons.ios_share_rounded, onTap: onShare),
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
                  name,
                  style: HomeV2.serifTitle(context, size: 22, color: HomeV2.textDark(context), height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (title != null && title!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    title!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeV2.textMuted(context)),
                    maxLines: 2,
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
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.65)],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}


IconData _kindIcon(CreatorItemKind k) {
  switch (k) {
    case CreatorItemKind.series:
      return Icons.library_music_rounded;
    case CreatorItemKind.novena:
      return Icons.auto_awesome_rounded;
    case CreatorItemKind.adoration:
      return Icons.church_rounded;
    case CreatorItemKind.station:
      return Icons.timeline_rounded;
    case CreatorItemKind.rosary:
      return Icons.circle_outlined;
    case CreatorItemKind.podcast:
      return Icons.podcasts_rounded;
    case CreatorItemKind.exercise:
      return Icons.church_rounded;
  }
}

/// Tlačidlo Sledovať / Sledované — vyplnené keď nesleduje, obrysové keď sleduje.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.busy,
    required this.accent,
    required this.label,
    required this.onTap,
  });
  final bool following;
  final bool busy;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = following ? accent : Colors.white;
    return Material(
      color: following ? Colors.transparent : accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: following ? BorderSide(color: accent, width: 1.4) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(following ? Icons.check_rounded : Icons.add_rounded, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sekcia ako full-width carousel (PageView) — jedna dlaždica na šírku, swipe
/// medzi položkami + bodkový indikátor. Kým je obsahu málo, prehľadnejšie než úzke dlaždice.
class _SectionCarousel extends StatefulWidget {
  const _SectionCarousel({required this.items, required this.accent, required this.onOpen});
  final List<CreatorContentItem> items;
  final Color accent;
  final void Function(CreatorContentItem) onOpen;

  @override
  State<_SectionCarousel> createState() => _SectionCarouselState();
}

class _SectionCarouselState extends State<_SectionCarousel> {
  final PageController _pc = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pageW = w * 0.92 - 2 * AppSpacing.sm; // šírka karty (mínus gap)
    final tileH = pageW * 9 / 16 + 70; // obrázok 16:9 + text
    final multi = widget.items.length > 1;
    return Column(
      children: [
        SizedBox(
          height: tileH,
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? AppSpacing.lg : AppSpacing.sm, right: AppSpacing.sm),
              child: _ContentTile(
                item: widget.items[i],
                accent: widget.accent,
                // Všetky typy obsahu tvorcu majú detail (viď _open).
                onTap: () => widget.onOpen(widget.items[i]),
              ),
            ),
          ),
        ),
        if (multi) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? widget.accent : widget.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Dlaždica obsahu (image-top) — vyplní šírku slajdu.
class _ContentTile extends StatelessWidget {
  const _ContentTile({required this.item, required this.accent, this.onTap});
  final CreatorContentItem item;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          child: AspectRatio(aspectRatio: 16 / 9, child: _thumb(context)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(item.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, color: HomeV2.textDark(context)),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(item.subtitle!,
              style: TextStyle(fontSize: 13, color: HomeV2.textMuted(context)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, child: tile);
  }

  Widget _thumb(BuildContext context) {
    final fallback = Container(
      color: accent.withValues(alpha: 0.12),
      child: Icon(_kindIcon(item.kind), color: accent, size: 34),
    );
    if (item.imageUrl == null) return fallback;
    return CachedNetworkImage(
      imageUrl: item.imageUrl!, fit: BoxFit.cover,
      placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback,
    );
  }
}

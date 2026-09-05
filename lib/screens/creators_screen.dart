import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/creator.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../services/novenas_service.dart';
import 'adoration_detail_screen.dart';
import 'creator_detail_screen.dart';
import 'creator_exercise_detail_screen.dart';
import 'creator_podcast_detail_screen.dart';
import 'creator_rosary_detail_screen.dart';
import 'creator_series_detail_screen.dart';
import 'novena_detail_screen.dart';
import 'stations_of_cross_detail_screen.dart';

/// Prevedie hex akcent (#RRGGBB) na Color; fallback na brand primary.
Color creatorAccentColor(String hex) {
  final h = hex.replaceFirst('#', '').trim();
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? HomeV2.primary : Color(v);
}

/// Poradie sekcií obsahu v adresári. Séria je prvá (najviac obsahu na jednu
/// položku), potom pobožnosti; duchovné cvičenia idú na konec, sú to udalosti
/// s dátumom, nie obsah na každý deň.
const List<CreatorItemKind> _sectionOrder = [
  CreatorItemKind.series,
  CreatorItemKind.station,
  CreatorItemKind.novena,
  CreatorItemKind.rosary,
  CreatorItemKind.adoration,
  CreatorItemKind.podcast,
  CreatorItemKind.exercise,
];

String _sectionTitle(CreatorItemKind k) {
  switch (k) {
    case CreatorItemKind.series:
      return tr('creator_section_series');
    case CreatorItemKind.station:
      return tr('creator_section_stations');
    case CreatorItemKind.novena:
      return tr('creator_section_novenas');
    case CreatorItemKind.rosary:
      return tr('creator_section_rosaries');
    case CreatorItemKind.adoration:
      return tr('creator_section_adorations');
    case CreatorItemKind.podcast:
      return tr('creator_section_podcasts');
    case CreatorItemKind.exercise:
      return tr('creator_section_exercises');
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

/// Počet položiek tvorcu v správnom páde („1 položka / 2 položky / 5 položiek").
///
/// Formu vyberáme sami a NEPOUŽÍVAME `plural()` z easy_localization: ten má
/// prepínač `ignorePluralRules` defaultne zapnutý, takže pre slovenčinu spadne
/// na 0/1/2/ostatné a napíše „4 položiek". Vypnúť sa dá len globálne pri
/// inicializácii appky, a to je zásah mimo tejto obrazovky.
String _itemsCount(BuildContext context, int n) {
  final lang = context.locale.languageCode;
  // Slovenčina a čeština majú tri formy (1 / 2–4 / 5+), ostatné jazyky appky dve.
  final form = (lang == 'sk' || lang == 'cs')
      ? (n == 1 ? 'one' : (n >= 2 && n <= 4 ? 'few' : 'other'))
      : (n == 1 ? 'one' : 'other');
  return tr('creators_items_count.$form', namedArgs: {'count': '$n'});
}

/// Adresár tvorcov (Creator Studio) — objavovanie obsahu naprieč tvorcami.
///
/// Skladba: hľadanie, kruhy tvorcov, „Sledujem", potom sekcie obsahu po typoch.
/// Obsah je zámerne v NÁHODNOM poradí (premieša sa pri každom načítaní), aby sa
/// tvorcovia striedali a nezvýhodňovalo to toho, kto je v abecede prvý.
/// Výnimka je „Sledujem" — tam si používateľ vybral sám, poradie sa nemieša.
class CreatorsScreen extends StatefulWidget {
  const CreatorsScreen({super.key});

  @override
  State<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends State<CreatorsScreen> {
  CreatorFeed _feed = const CreatorFeed();
  Set<String> _followed = const {};
  bool _loading = true;
  String? _loadedLang;

  /// Premiešaný obsah po typoch. Drží sa v stave, nie v `build` — inak by
  /// poradie preskakovalo pri každom prekreslení (napr. pri písaní do hľadania).
  Map<CreatorItemKind, List<CreatorContentItem>> _shuffled = const {};
  Map<String, CreatorSummary> _byId = const {};

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.locale.languageCode;
    if (lang != _loadedLang) {
      _loadedLang = lang;
      _load(lang);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String lang) async {
    if (mounted) setState(() => _loading = true);
    // Sledovaní sa dotiahnu súbežne — je to iný (necachovaný) endpoint.
    final results = await Future.wait([
      CreatorsService.instance.fetchDiscover(lang),
      CreatorsService.instance.fetchFollowedIds(),
    ]);
    if (!mounted) return;
    final feed = results[0] as CreatorFeed;
    final rnd = Random();
    setState(() {
      _feed = feed;
      _followed = results[1] as Set<String>;
      _byId = {for (final c in feed.creators) c.id: c};
      _shuffled = {
        for (final e in feed.items.entries) e.key: [...e.value]..shuffle(rnd),
      };
      _loading = false;
    });
  }

  CreatorSummary? _creatorOf(CreatorContentItem item) =>
      item.ownerProfileId == null ? null : _byId[item.ownerProfileId];

  Future<void> _openCreator(CreatorSummary c) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorDetailScreen(summary: c),
          settings: const RouteSettings(name: '/creator-detail'),
        ),
      );

  /// Otvorí položku podľa typu. Tvorca je pri každej položke iný (na rozdiel od
  /// detailu tvorcu), preto sa slug aj akcent berú z nej.
  Future<void> _openItem(CreatorContentItem item) async {
    final c = _creatorOf(item);
    if (c == null) return; // bez tvorcu nemá séria z čoho poskladať adresu
    final accent = creatorAccentColor(c.accent);
    switch (item.kind) {
      case CreatorItemKind.novena:
        await _openNovena(item);
      case CreatorItemKind.podcast:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorPodcastDetailScreen(podcast: item, accent: accent),
          settings: const RouteSettings(name: '/creator-podcast'),
        ));
      case CreatorItemKind.series:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorSeriesDetailScreen(item: item, accent: accent, creatorSlug: c.slug),
          settings: const RouteSettings(name: '/creator-series'),
        ));
      case CreatorItemKind.rosary:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorRosaryDetailScreen(item: item, accent: accent),
          settings: const RouteSettings(name: '/creator-rosary'),
        ));
      case CreatorItemKind.adoration:
        // Zdieľaná tabuľka lectio_divina_adoracia → hlavný v2 detail podľa id.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdorationDetailScreen(adorationId: item.id),
          settings: const RouteSettings(name: '/creator-adoration'),
        ));
      case CreatorItemKind.station:
        // Zdieľaná tabuľka krizove_cesty → hlavný v2 detail podľa id.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StationsOfCrossDetailScreen(stationsOfCrossId: item.id),
          settings: const RouteSettings(name: '/creator-stations'),
        ));
      case CreatorItemKind.exercise:
        await Navigator.of(context).push(MaterialPageRoute(
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NovenaDetailScreen(variants: [novena]),
      settings: const RouteSettings(name: '/novena-detail'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      appBar: AppBar(
        title: Text(tr('creators_title')),
        backgroundColor: HomeV2.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: HomeV2.primary,
        onRefresh: () => _load(context.locale.languageCode),
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()))
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                children: [
                  _SearchField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                  if (_query.isNotEmpty)
                    ..._searchResults()
                  else if (_feed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(child: Text(tr('creators_empty'),
                          style: TextStyle(color: HomeV2.textMuted(context)))),
                    )
                  else
                    ..._browse(),
                ],
              ),
      ),
    );
  }

  // ── Prehliadanie ──────────────────────────────────────────────────────────

  List<Widget> _browse() {
    final followed = _feed.creators.where((c) => _followed.contains(c.id)).toList();
    return [
      const SizedBox(height: AppSpacing.sm),
      _SectionHeader(title: tr('creators_all')),
      _CreatorCircles(creators: _feed.creators, onTap: _openCreator),
      if (followed.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(title: tr('creators_following_section')),
        _FollowedRow(creators: followed, onTap: _openCreator),
      ],
      for (final kind in _sectionOrder) ...(() {
        final items = _shuffled[kind] ?? const <CreatorContentItem>[];
        if (items.isEmpty) return <Widget>[];
        return [
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: _sectionTitle(kind)),
          _ItemRow(items: items, creatorOf: _creatorOf, onTap: _openItem),
        ];
      })(),
    ];
  }

  // ── Hľadanie ──────────────────────────────────────────────────────────────

  /// Hľadá sa v už načítaných dátach (celý adresár je v pamäti), takže výsledky
  /// naskakujú okamžite bez ďalšieho volania servera.
  List<Widget> _searchResults() {
    final q = _query.toLowerCase();
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);

    final creators = _feed.creators
        .where((c) => hit(c.displayName) || hit(c.title))
        .toList();

    // Meno tvorcu berieme ako hľadaný text aj u položiek — „ružence od Pecka"
    // sa dá nájsť napísaním tvorcu.
    final items = <CreatorContentItem>[];
    for (final kind in _sectionOrder) {
      for (final it in _shuffled[kind] ?? const <CreatorContentItem>[]) {
        if (hit(it.title) || hit(it.subtitle) || hit(_creatorOf(it)?.displayName)) items.add(it);
      }
    }

    if (creators.isEmpty && items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(child: Text(tr('creators_search_empty'),
              style: TextStyle(color: HomeV2.textMuted(context)))),
        ),
      ];
    }

    return [
      if (creators.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        _SectionHeader(title: tr('creators_all')),
        for (final c in creators) _CreatorRow(creator: c, onTap: _openCreator),
      ],
      if (items.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(title: tr('creators_search_content')),
        for (final it in items)
          _ItemRowTile(item: it, creator: _creatorOf(it), onTap: () => _openItem(it)),
      ],
    ];
  }
}

// ── Hľadanie ────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 15, color: HomeV2.textDark(context)),
        decoration: InputDecoration(
          hintText: tr('creators_search_hint'),
          hintStyle: TextStyle(fontSize: 15, color: HomeV2.textMuted(context)),
          prefixIcon: Icon(Icons.search_rounded, color: HomeV2.textMuted(context)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: HomeV2.textMuted(context)),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: HomeV2.card(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Text(title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
    );
  }
}

// ── Tvorcovia ───────────────────────────────────────────────────────────────

/// Kruhy tvorcov — horizontálne posuvná mriežka, ktorá sa plní po stĺpcoch.
///
/// Počet radov rastie s počtom tvorcov (max 3): kým sú tvorcovia dvaja, tri
/// prázdne rady by vyzerali ako chyba; od deviatich sa naplnia všetky tri
/// a ďalej sa posúva do strany.
class _CreatorCircles extends StatelessWidget {
  const _CreatorCircles({required this.creators, required this.onTap});
  final List<CreatorSummary> creators;
  final void Function(CreatorSummary) onTap;

  static const double _tileW = 96;
  // Avatar s krúžkom (70) + medzera (6) + 2 riadky mena. Rezerva navyše preto,
  // že v plnej appke je iná mierka textu než v izolovanom náhľade — pri 104
  // to reálne pretieklo o 2 px („RenderFlex overflowed").
  static const double _tileH = 112;

  @override
  Widget build(BuildContext context) {
    final rows = min(3, (creators.length / 3).ceil()).clamp(1, 3);
    return SizedBox(
      height: rows * _tileH,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        // Pri horizontálnom posune je „cross axis" zvislá os, takže
        // crossAxisCount = počet RADOV a mriežka sa plní stĺpec po stĺpci.
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: rows,
          mainAxisExtent: _tileW,
          crossAxisSpacing: 0,
          mainAxisSpacing: AppSpacing.xs,
        ),
        itemCount: creators.length,
        itemBuilder: (_, i) => _CreatorCircle(creator: creators[i], onTap: onTap),
      ),
    );
  }
}

class _CreatorCircle extends StatelessWidget {
  const _CreatorCircle({required this.creator, required this.onTap});
  final CreatorSummary creator;
  final void Function(CreatorSummary) onTap;

  @override
  Widget build(BuildContext context) {
    final accent = creatorAccentColor(creator.accent);
    return GestureDetector(
      onTap: () => onTap(creator),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(url: creator.photoUrl, accent: accent, name: creator.displayName, size: 62, ring: true),
          const SizedBox(height: 6),
          // Flexible: keď má používateľ zväčšené písmo, meno sa skráti s „…"
          // namiesto pretečenia dlaždice (výška bunky mriežky je pevná).
          Flexible(
            child: Text(creator.displayName,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2,
                    color: HomeV2.textDark(context)),
                maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// „Sledujem" — jeden rad širších kariet. Nemieša sa: poradie je abecedné, ako
/// ho vrátil server, aby používateľ svojich tvorcov našiel vždy na tom istom mieste.
class _FollowedRow extends StatelessWidget {
  const _FollowedRow({required this.creators, required this.onTap});
  final List<CreatorSummary> creators;
  final void Function(CreatorSummary) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: creators.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final c = creators[i];
          final accent = creatorAccentColor(c.accent);
          return GestureDetector(
            onTap: () => onTap(c),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: HomeV2.card(context),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                boxShadow: HomeV2.softShadowSm(context),
              ),
              child: Row(
                children: [
                  _Avatar(url: c.photoUrl, accent: accent, name: c.displayName, size: 48),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(c.displayName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: HomeV2.textDark(context)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_itemsCount(context, c.counts.total),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tvorca vo výsledkoch hľadania (celá šírka, pod sebou).
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.creator, required this.onTap});
  final CreatorSummary creator;
  final void Function(CreatorSummary) onTap;

  @override
  Widget build(BuildContext context) {
    final accent = creatorAccentColor(creator.accent);
    return GestureDetector(
      onTap: () => onTap(creator),
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          boxShadow: HomeV2.softShadowSm(context),
        ),
        child: Row(
          children: [
            _Avatar(url: creator.photoUrl, accent: accent, name: creator.displayName, size: 52),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(creator.displayName,
                      style: HomeV2.serifTitle(context, size: 17),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (creator.title != null) ...[
                    const SizedBox(height: 2),
                    Text(creator.title!,
                        style: TextStyle(fontSize: 12.5, color: HomeV2.textMuted(context)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: HomeV2.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

// ── Obsah ───────────────────────────────────────────────────────────────────

/// Jeden rad obsahu — karty s obrázkom 16:9 a menom tvorcu pod názvom.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.items, required this.creatorOf, required this.onTap});
  final List<CreatorContentItem> items;
  final CreatorSummary? Function(CreatorContentItem) creatorOf;
  final void Function(CreatorContentItem) onTap;

  @override
  Widget build(BuildContext context) {
    const cardW = 210.0;
    return SizedBox(
      height: cardW * 9 / 16 + 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) => SizedBox(
          width: cardW,
          child: _ItemCard(
            item: items[i],
            creator: creatorOf(items[i]),
            onTap: () => onTap(items[i]),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.creator, required this.onTap});
  final CreatorContentItem item;
  final CreatorSummary? creator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = creatorAccentColor(creator?.accent ?? '#4A5085');
    final fallback = Container(
      color: accent.withValues(alpha: 0.12),
      child: Icon(_kindIcon(item.kind), color: accent, size: 32),
    );
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: item.imageUrl == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: item.imageUrl!, fit: BoxFit.cover,
                      placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.25,
                  color: HomeV2.textDark(context)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (creator != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                _Avatar(url: creator!.photoUrl, accent: accent, name: creator!.displayName, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(creator!.displayName,
                      style: TextStyle(fontSize: 11.5, color: HomeV2.textMuted(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Položka obsahu vo výsledkoch hľadania (celá šírka, pod sebou).
class _ItemRowTile extends StatelessWidget {
  const _ItemRowTile({required this.item, required this.creator, required this.onTap});
  final CreatorContentItem item;
  final CreatorSummary? creator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = creatorAccentColor(creator?.accent ?? '#4A5085');
    final fallback = Container(
      width: 64, height: 64,
      color: accent.withValues(alpha: 0.12),
      child: Icon(_kindIcon(item.kind), color: accent, size: 26),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          boxShadow: HomeV2.softShadowSm(context),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: item.imageUrl == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: item.imageUrl!, width: 64, height: 64, fit: BoxFit.cover,
                      placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.25,
                          color: HomeV2.textDark(context)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    creator == null
                        ? _sectionTitle(item.kind)
                        : '${_sectionTitle(item.kind)} · ${creator!.displayName}',
                    style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: HomeV2.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.accent,
    required this.name,
    this.size = 56,
    this.ring = false,
  });
  final String? url;
  final Color accent;
  final String name;
  final double size;

  /// Krúžok v akcentovej farbe okolo fotky (v mriežke tvorcov).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final fallback = Container(
      width: size, height: size,
      alignment: Alignment.center,
      color: accent.withValues(alpha: 0.15),
      child: Text(initials,
          style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: size * 0.4)),
    );
    final avatar = ClipOval(
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url!, width: size, height: size, fit: BoxFit.cover,
              placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback,
            ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
      ),
      child: avatar,
    );
  }
}

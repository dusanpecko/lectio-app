import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Jednotný zbaliteľný hero pre obsahové obrazovky (krížové cesty, adorácie,
/// ruženec, deviatniky). Správanie = vzor krížových ciest (11.7.2026):
///
///  · SliverAppBar 300 px (450 na tablete), pinned
///  · ilustrácia (CachedNetworkImage) alebo [fallbackAsset] / plný [accentColor]
///  · gradient [accentColor] 0.4 → 0.8 zhora nadol
///  · titulok v lište sa OBJAVÍ AŽ PO ZBALENÍ (fade — žiadny dvojitý titulok),
///    počítané z FlexibleSpaceBarSettings (bez scroll-controllera v obrazovke)
///  · biela šípka späť + voliteľné [actions]
///
/// Obsah cez expanded hero dodáva obrazovka v [expandedContent] (napr. titulok
/// dole, alebo ikona + titulok v strede) — správanie ostáva jednotné.
class CollapsibleHeroAppBar extends StatelessWidget {
  const CollapsibleHeroAppBar({
    super.key,
    required this.collapsedTitle,
    this.imageUrl,
    this.fallbackAsset,
    this.accentColor = HomeV2.primary,
    this.expandedContent,
    this.actions = const [],
    this.onBack,
  });

  /// Titulok zobrazený v lište po zbalení hero.
  final String collapsedTitle;

  /// Ilustrácia (network). Bez nej sa použije [fallbackAsset], inak plná farba.
  final String? imageUrl;
  final String? fallbackAsset;

  /// Farba gradientu a pozadia (primary; ruženec má farbu kategórie).
  final Color accentColor;

  /// Obsah cez rozbalený hero (titulok, ikona, autor…) — už na gradientom.
  final Widget? expandedContent;

  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final expandedHeight = isTablet ? 450.0 : 300.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      actions: actions,
      // Titulok rieši flexibleSpace (fade podľa miery zbalenia) — `title:`
      // nechávame prázdny, aby sa nezobrazoval trvalo.
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          // 1.0 = plne rozbalené, 0.0 = zbalené.
          final t = settings == null
              ? 1.0
              : ((settings.currentExtent - settings.minExtent) /
                        (settings.maxExtent - settings.minExtent))
                    .clamp(0.0, 1.0);
          final collapsedOpacity = (1.0 - t * 4).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Ilustrácia / fallback
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: accentColor),
                  errorWidget: (_, _, _) => ColoredBox(color: accentColor),
                )
              else if (fallbackAsset != null)
                Image.asset(fallbackAsset!, fit: BoxFit.cover)
              else
                ColoredBox(color: accentColor),
              // Jednotný gradient (vzor krížové cesty)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.4),
                      accentColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              // Obsah obrazovky — fade-out pri zbaľovaní (plne priehľadný pod
              // 35 % rozbalenia) + ClipRect proti pretečeniu počas animácie.
              if (expandedContent != null)
                ClipRect(
                  child: Opacity(
                    opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                    child: expandedContent!,
                  ),
                ),
              // Zbalený titulok — objaví sa až tesne pred zbalením
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Padding(
                      // Priestor pre leading (56) a REÁLNY počet akcií vpravo
                      // (48 px/ikona) — inak akcie prekrývajú zbalený titulok.
                      padding: EdgeInsets.only(
                        left: 56,
                        right: actions.isEmpty
                            ? 56
                            : 16 + actions.length * 48.0,
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: collapsedOpacity,
                          child: Text(
                            collapsedTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Štandardný obsah hero „ikona v bublinke + titulok + podtitulok v strede"
/// (adorácie, ruženec, deviatniky). Krížové cesty používajú vlastný obsah
/// (titulok dole na intro slide).
class HeroCenteredContent extends StatelessWidget {
  const HeroCenteredContent({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final maxTextWidth =
        MediaQuery.of(context).size.width -
        2 * (isTablet ? AppSpacing.xxl * 1.5 : AppSpacing.xxl);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(
          isTablet ? AppSpacing.xxl * 1.5 : AppSpacing.xxl,
        ),
        // FittedBox: pri zbaľovaní hero sa obsah plynulo ZMENŠÍ namiesto
        // RenderFlex overflow (výška flexibleSpace klesá až ku kToolbarHeight).
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTextWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: EdgeInsets.all(
                        isTablet ? AppSpacing.xl : AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Icon(
                        icon,
                        size: isTablet ? 64 : 48,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isTablet ? AppSpacing.xl : AppSpacing.lg),
                  ],
                  Text(
                    title,
                    style:
                        HomeV2.serifTitle(
                          context,
                          size: isTablet ? 34 : 26,
                          color: Colors.white,
                          height: 1.15,
                        ).copyWith(
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 10),
                          ],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: isTablet ? AppSpacing.md : AppSpacing.sm),
                    Text(
                      subtitle!,
                      style:
                          (isTablet
                                  ? theme.textTheme.headlineMedium
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

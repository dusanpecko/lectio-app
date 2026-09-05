import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/creator.dart';
import '../../screens/creators_screen.dart' show creatorAccentColor;
import '../../services/creators_service.dart';
import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Horizontálny zoznam tvorcov na home (dlaždice foto + meno) + „Zobraziť všetko".
/// Načítava sa sám; ak nie sú žiadni tvorcovia, sekcia sa nezobrazí (fail-soft).
class CreatorsHorizontalList extends StatefulWidget {
  const CreatorsHorizontalList({super.key, required this.onSeeAll, required this.onOpen});
  final VoidCallback onSeeAll;
  final void Function(CreatorSummary) onOpen;

  @override
  State<CreatorsHorizontalList> createState() => _CreatorsHorizontalListState();
}

class _CreatorsHorizontalListState extends State<CreatorsHorizontalList> {
  List<CreatorSummary> _creators = const [];
  bool _loading = true;
  String? _loadedLang;

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
    final data = await CreatorsService.instance.fetchCreators(lang);
    if (!mounted) return;
    setState(() {
      _creators = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _creators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('creators_title'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: widget.onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                  child: Row(children: [
                    Text(tr('show_all'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeV2.primary)),
                    Icon(Icons.chevron_right_rounded, size: 20, color: HomeV2.primary),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _loading ? 4 : _creators.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => _loading ? const _CreatorTileSkeleton() : _CreatorTile(creator: _creators[i], onTap: widget.onOpen),
          ),
        ),
      ],
    );
  }
}

class _CreatorTile extends StatelessWidget {
  const _CreatorTile({required this.creator, required this.onTap});
  final CreatorSummary creator;
  final void Function(CreatorSummary) onTap;

  @override
  Widget build(BuildContext context) {
    final accent = creatorAccentColor(creator.accent);
    final initials = creator.displayName.trim().isNotEmpty ? creator.displayName.trim()[0].toUpperCase() : '?';
    final fallback = Container(
      width: 72, height: 72, alignment: Alignment.center,
      color: accent.withValues(alpha: 0.15),
      child: Text(initials, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 26)),
    );
    return GestureDetector(
      onTap: () => onTap(creator),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: 0.5), width: 2)),
              child: ClipOval(
                child: creator.photoUrl == null
                    ? fallback
                    : CachedNetworkImage(
                        imageUrl: creator.photoUrl!, width: 72, height: 72, fit: BoxFit.cover,
                        placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(creator.displayName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomeV2.textDark(context)),
                maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _CreatorTileSkeleton extends StatelessWidget {
  const _CreatorTileSkeleton();
  @override
  Widget build(BuildContext context) {
    final base = HomeV2.primary.withValues(alpha: 0.08);
    return SizedBox(
      width: 92,
      child: Column(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
        const SizedBox(height: AppSpacing.sm),
        Container(width: 60, height: 10, color: base),
      ]),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/sponsor.dart';
import '../../services/sponsors_service.dart';
import '../../shared/app_spacing.dart';
import '../sponsor_sheet.dart';
import 'home_v2_tokens.dart';

/// „Podporili nás" na home (pod tvorcami): horizontálny pás log na bielych
/// dlaždiciach. Ťuknutie otvorí kartu sponzora odspodu ([showSponsorSheet]).
/// Načítava sa sám; bez zverejnených sponzorov sa sekcia nezobrazí (fail-soft).
class SponsorsHorizontalList extends StatefulWidget {
  const SponsorsHorizontalList({super.key});

  @override
  State<SponsorsHorizontalList> createState() => _SponsorsHorizontalListState();
}

class _SponsorsHorizontalListState extends State<SponsorsHorizontalList> {
  List<Sponsor> _sponsors = const [];
  bool _loading = true;
  String? _loadedLang;

  static const double _tileW = 128;
  static const double _tileH = 76;

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
    final data = await SponsorsService.instance.fetchSponsors(lang);
    if (!mounted) return;
    setState(() {
      _sponsors = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _sponsors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            tr('sponsors_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: HomeV2.textDark(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: _tileH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _loading ? 3 : _sponsors.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) {
              if (_loading) return const _SponsorTileSkeleton(width: _tileW, height: _tileH);
              final s = _sponsors[i];
              return SponsorLogoTile(
                sponsor: s,
                width: _tileW,
                height: _tileH,
                onTap: () => showSponsorSheet(context, s, source: 'home'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SponsorTileSkeleton extends StatelessWidget {
  const _SponsorTileSkeleton({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
    );
  }
}

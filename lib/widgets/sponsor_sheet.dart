import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/sponsor.dart';
import '../services/sponsors_service.dart';
import '../services/umami_analytics_service.dart';
import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Logo sponzora na bielej dlaždici (aj v tmavom režime — tmavé logá by inak
/// zmizli). Ak má sponzor `logoDarkUrl`, v tmavom režime sa použije ono na
/// farbe karty. Bez loga sa vypíše názov.
class SponsorLogoTile extends StatelessWidget {
  const SponsorLogoTile({
    super.key,
    required this.sponsor,
    this.width = 128,
    this.height = 76,
    this.onTap,
  });

  final Sponsor sponsor;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = HomeV2.isDark(context);
    final useDarkLogo = dark && sponsor.logoDarkUrl != null;
    final url = useDarkLogo ? sponsor.logoDarkUrl : sponsor.logoUrl;

    // Pozvánka pre nových partnerov — prerušovaný okraj a text z prekladov.
    if (sponsor.isPlaceholder) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: dark ? 0.16 : 0.05),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(
              color: HomeV2.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: HomeV2.iconAccent(context)),
              const SizedBox(height: 2),
              Text(
                'sponsors_placeholder_title'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: HomeV2.iconAccent(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tile = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: useDarkLogo ? HomeV2.card(context) : Colors.white,
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
        border: Border.all(
          color: HomeV2.primary.withValues(alpha: dark ? 0.25 : 0.10),
        ),
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              sponsor.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: HomeV2.primary,
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => Text(
                sponsor.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.primary,
                ),
              ),
            ),
    );

    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: sponsor.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

String formatSponsorAmount(BuildContext context, Sponsor s) {
  final amount = s.amount ?? 0;
  final whole = amount == amount.roundToDouble();
  final f = NumberFormat.currency(
    locale: context.locale.toString(),
    name: s.currency,
    symbol: s.currency == 'EUR' ? '€' : s.currency,
    decimalDigits: whole ? 0 : 2,
  );
  return f.format(amount);
}

/// Karta sponzora odspodu — rovnaký štýl ako bio člena tímu v O aplikácii.
/// `source` ide do Umami (`home` / `about`), nech vieš, odkiaľ ľudia klikajú.
/// Sheet pozvánky pre nových partnerov („Miesto pre vás“, 24. 9. 2026).
Future<void> _showPlaceholderSheet(
  BuildContext context,
  Sponsor sponsor,
  String source,
) {
  UmamiAnalyticsService().trackEvent(
    'sponsor_placeholder_open',
    eventData: {'source': source},
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final textDark = HomeV2.textDark(sheetContext);
      final textMuted = HomeV2.textMuted(sheetContext);
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: HomeV2.card(sheetContext),
            borderRadius: BorderRadius.circular(HomeV2.radius),
            boxShadow: HomeV2.softShadow(sheetContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                    ),
                    child: Icon(Icons.handshake_rounded, color: HomeV2.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'sponsors_placeholder_title'.tr(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'sponsors_placeholder_body'.tr(),
                style: TextStyle(fontSize: 15, height: 1.5, color: textDark),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = sponsor.websiteUrl?.trim();
                    if (url == null || url.isEmpty) return;
                    UmamiAnalyticsService().trackEvent(
                      'sponsor_placeholder_click',
                      eventData: {'source': source},
                    );
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text('sponsors_placeholder_cta'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeV2.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: TextButton.styleFrom(foregroundColor: textMuted),
                child: Text('close'.tr()),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showSponsorSheet(
  BuildContext context,
  Sponsor sponsor, {
  required String source,
}) {
  HapticFeedback.lightImpact();
  // Pozvánka „Miesto pre vás“ má vlastný, kratší sheet — nie je to sponzor.
  if (sponsor.isPlaceholder) {
    return _showPlaceholderSheet(context, sponsor, source);
  }
  UmamiAnalyticsService().trackEvent(
    'sponsor_open',
    eventData: {
      'sponsor': sponsor.name,
      'sponsor_id':
          sponsor.id, // stabilné naprieč jazykmi — admin ráta podľa ID
      'source': source,
    },
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final maxH = MediaQuery.of(sheetContext).size.height * 0.85;
      final textDark = HomeV2.textDark(sheetContext);
      final textMuted = HomeV2.textMuted(sheetContext);
      return Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: HomeV2.background(sheetContext),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(HomeV2.radius + 6),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SponsorLogoTile(sponsor: sponsor, width: 180, height: 104),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  sponsor.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                if (sponsor.amount != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${tr('sponsor_supported_with')} ${formatSponsorAmount(sheetContext, sponsor)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: HomeV2.gold,
                    ),
                  ),
                ],
                if (sponsor.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    sponsor.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: textDark,
                    ),
                  ),
                ],
                if (sponsor.websiteUrl != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                      ),
                    ),
                    onPressed: () async {
                      UmamiAnalyticsService().trackEvent(
                        'sponsor_link',
                        eventData: {
                          'sponsor': sponsor.name,
                          'sponsor_id': sponsor.id,
                          'source': source,
                        },
                      );
                      await launchUrl(
                        Uri.parse(sponsor.websiteUrl!),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(tr('sponsor_visit_website')),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Zaznamená `sponsors_view` (Umami), keď je aspoň polovica sekcie na obrazovke —
/// raz za život widgetu. Admin z toho vidí, koľkí ľudia sa pri sekcii zastavili.
void trackSponsorsView(String source, int count) {
  UmamiAnalyticsService().trackEvent(
    'sponsors_view',
    eventData: {'source': source, 'count': count},
  );
}

/// Sekcia „Podporili nás" pre O aplikácii — karta s logami vo Wrap-e.
/// Načítava sa sama; bez sponzorov sa nezobrazí.
class SponsorsAboutSection extends StatefulWidget {
  const SponsorsAboutSection({super.key});

  @override
  State<SponsorsAboutSection> createState() => _SponsorsAboutSectionState();
}

class _SponsorsAboutSectionState extends State<SponsorsAboutSection> {
  List<Sponsor> _sponsors = const [];
  String? _loadedLang;
  bool _viewed = false;

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
    setState(() => _sponsors = data);
  }

  @override
  Widget build(BuildContext context) {
    if (_sponsors.isEmpty) return const SizedBox.shrink();
    return VisibilityDetector(
      key: const Key('sponsors-about-section'),
      onVisibilityChanged: (info) {
        if (!_viewed && info.visibleFraction >= 0.5) {
          _viewed = true;
          trackSponsorsView('about', _sponsors.length);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radius),
          boxShadow: HomeV2.softShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('sponsors_title'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeV2.iconAccent(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('sponsors_about_description'),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: HomeV2.textDark(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Vodorovný posuv — pri desiatkach sponzorov by zoznam pod sebou
            // natiahol obrazovku donekonečna (Dušan 23. 9.).
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _sponsors.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => SponsorLogoTile(
                  sponsor: _sponsors[i],
                  onTap: () =>
                      showSponsorSheet(context, _sponsors[i], source: 'about'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

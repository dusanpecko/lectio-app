import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/support_campaign.dart';
import '../../services/support_campaign_service.dart';
import '../../shared/app_spacing.dart';
import '../home_v2/home_v2_tokens.dart';

/// Sekcia „Podporte" navrch obrazovky daru: príbeh projektu, progress bar voči
/// cieľu (reálna vyzbieraná suma), míľniky a počet podporovateľov.
/// Načíta sa sama; ak kampaň nie je aktívna/dostupná, nič nezobrazí.
class SupportCampaignCard extends StatefulWidget {
  /// `embedded` = vnorené do inej karty (napr. rozbaľovačky príbehu): bez
  /// vlastného chrómu (margin/padding/tieň) a bez interného titulu „Náš príbeh",
  /// lebo titul poskytuje nadradená rozbaľovacia karta.
  final bool embedded;

  const SupportCampaignCard({super.key, this.embedded = false});

  @override
  State<SupportCampaignCard> createState() => _SupportCampaignCardState();
}

class _SupportCampaignCardState extends State<SupportCampaignCard> {
  SupportCampaign? _campaign;
  bool _loaded = false;
  bool _storyExpanded = false;

  @override
  void initState() {
    super.initState();
    // Okamžité vykreslenie z cache (ak už bola kampaň načítaná) — bez blikania.
    final cached = SupportCampaignService.instance.cached;
    if (cached != null) {
      _campaign = cached;
      _loaded = true;
    }
    _load();
  }

  Future<void> _load() async {
    final c = await SupportCampaignService.instance.fetch();
    if (!mounted) return;
    setState(() {
      _campaign = c;
      _loaded = true;
    });
  }

  String _eur(double v, String locale) {
    final f = NumberFormat.currency(
      locale: locale == 'cz' ? 'cs' : locale,
      symbol: '€',
      decimalDigits: v % 1 == 0 ? 0 : 2,
    );
    return f.format(v);
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'translate':
        return Icons.translate_rounded;
      case 'headphones':
        return Icons.headphones_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'public':
        return Icons.public_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'favorite':
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    if (!_loaded || c == null) return const SizedBox.shrink();

    final locale = context.locale.languageCode;
    final story = c.storyFor(locale);
    final embedded = widget.embedded;

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Príbeh — titul vynechávame v embedded režime (poskytuje ho rozbaľovačka)
          if (story.isNotEmpty) ...[
            if (!embedded) ...[
              Text('support_campaign.our_story'.tr(),
                  style: HomeV2.serifTitle(context, size: 20)),
              const SizedBox(height: AppSpacing.sm),
            ],
            ..._buildStoryContent(context, story, c.images),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Progress bar voči cieľu
          if (c.hasGoal) _buildProgress(c, locale),

          // Míľniky
          if (c.milestones.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ...c.milestones.map((m) => _buildMilestone(c, m, locale)),
          ],

          // Počet podporovateľov
          if (c.showSupporters && c.supporters > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: HomeV2.gold),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${'support_campaign.supporters_title'.tr()}: ${c.supporters}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      );

    // Embedded: bez vlastného chrómu (rieši ho nadradená rozbaľovacia karta).
    if (embedded) return content;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: content,
    );
  }

  TextStyle _storyStyle(BuildContext context) => TextStyle(
        fontSize: 14.5,
        height: 1.6,
        color: HomeV2.textDark(context),
      );

  /// Rozdelí príbeh na text/obrázky podľa tokenov [[kod]]. Bez obrázkov →
  /// pôvodné správanie so „Čítať viac".
  List<Widget> _buildStoryContent(
      BuildContext context, String story, Map<String, String> images) {
    final re = RegExp(r'\[\[(\w+)\]\]');
    final hasImages = images.isNotEmpty && re.hasMatch(story);

    if (!hasImages) {
      final plain = story.replaceAll(re, '').trim();
      return [
        AnimatedCrossFade(
          duration: HomeV2.anim,
          crossFadeState: _storyExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(plain,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: _storyStyle(context)),
          secondChild: Text(plain, style: _storyStyle(context)),
        ),
        if (plain.length > 220)
          GestureDetector(
            onTap: () => setState(() => _storyExpanded = !_storyExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _storyExpanded
                    ? 'support_campaign.read_less'.tr()
                    : 'support_campaign.read_more'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.primary,
                ),
              ),
            ),
          ),
      ];
    }

    // Striedanie text / vycentrovaný obrázok podľa pozície tokenov.
    final out = <Widget>[];
    var last = 0;
    void addText(String t) {
      final s = t.trim();
      if (s.isEmpty) return;
      if (out.isNotEmpty) out.add(const SizedBox(height: AppSpacing.md));
      out.add(Text(s, style: _storyStyle(context)));
    }

    for (final m in re.allMatches(story)) {
      addText(story.substring(last, m.start));
      final url = images[m.group(1)];
      if (url != null && url.isNotEmpty) {
        if (out.isNotEmpty) out.add(const SizedBox(height: AppSpacing.md));
        out.add(_storyImage(url));
      }
      last = m.end;
    }
    addText(story.substring(last));
    return out;
  }

  Widget _storyImage(String url) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildProgress(SupportCampaign c, String locale) {
    final pct = (c.progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suma vyzbierané / cieľ
        if (c.showAmount)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _eur(c.currentAmount, locale),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: HomeV2.primary,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${'support_campaign.of'.tr()} ${_eur(c.goalAmount, locale)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$pct %',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.gold,
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: c.progress,
            minHeight: 10,
            backgroundColor: HomeV2.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(HomeV2.primary),
          ),
        ),
        if (!c.showAmount) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'support_campaign.raised_label'.tr(),
            style: TextStyle(fontSize: 12.5, color: HomeV2.textMuted(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildMilestone(
      SupportCampaign c, SupportMilestone m, String locale) {
    final reached = c.currentAmount >= m.amount;
    final title = m.titleFor(locale);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: reached
                  ? HomeV2.primary.withValues(alpha: 0.14)
                  : HomeV2.textMuted(context).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reached ? Icons.check_rounded : _iconFor(m.icon),
              size: 18,
              color: reached ? HomeV2.primary : HomeV2.textMuted(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                color: reached
                    ? HomeV2.textDark(context)
                    : HomeV2.textMuted(context),
                decoration: reached ? null : null,
              ),
            ),
          ),
          if (c.showAmount) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              _eur(m.amount, locale),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: reached ? HomeV2.gold : HomeV2.textMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

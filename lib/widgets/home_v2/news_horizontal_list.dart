import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Horizontálny zoznam aktualít — menšie moderné karty (obrázok vľavo, text
/// vpravo) + link „Zobraziť všetko".
class NewsHorizontalList extends StatelessWidget {
  final List<Map<String, dynamic>> articles;
  final bool isLoading;
  final ValueChanged<Map<String, dynamic>> onArticleTap;
  final VoidCallback onSeeAll;

  const NewsHorizontalList({
    super.key,
    required this.articles,
    required this.isLoading,
    required this.onArticleTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && articles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('news'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textDark(context),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        tr('show_all'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HomeV2.primary,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: HomeV2.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 104,
          child: isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: 3,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, _) => _NewsSkeleton(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: articles.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return _NewsCard(
                      article: article,
                      onTap: () => onArticleTap(article),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback onTap;

  const _NewsCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['image_url'] as String?;
    final title = (article['title'] as String?) ?? tr('untitled_article');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          boxShadow: HomeV2.softShadowSm(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 84,
                        height: 84,
                        color: HomeV2.primary.withValues(alpha: 0.12),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 84,
                        height: 84,
                        color: HomeV2.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.image_rounded,
                            color: HomeV2.primary, size: 28),
                      ),
                    )
                  : Container(
                      width: 84,
                      height: 84,
                      color: HomeV2.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.campaign_rounded,
                          color: HomeV2.primary, size: 28),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textDark(context),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = HomeV2.primary.withValues(alpha: 0.08);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, color: base),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: Container(height: 12, color: base),
                ),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(height: 12, color: base),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

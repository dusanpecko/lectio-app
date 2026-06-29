// lib/screens/rosary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../shared/rosary_constants.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'rosary_category_screen.dart';

class RosaryScreen extends StatefulWidget {
  const RosaryScreen({super.key});

  @override
  State<RosaryScreen> createState() => _RosaryScreenState();
}

class _RosaryScreenState extends State<RosaryScreen> {
  final RosaryService _rosaryService = RosaryService();
  List<RosaryCategoryStats> _categoryStats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lang = context.locale.languageCode;
      final stats = await _rosaryService.getCategoryStats(lang);
      if (mounted) {
        setState(() {
          _categoryStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCategory(RosaryCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RosaryCategoryScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: HomeV2.primary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              MediaQuery.of(context).viewPadding.bottom +
                                  AppSpacing.xxl,
                            ),
                            children: [
                              _buildHowToSection(),
                              const SizedBox(height: AppSpacing.xxl),
                              _buildCategoriesSection(),
                              const SizedBox(height: AppSpacing.xxl),
                              _buildBenefitsSection(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final bg = HomeV2.background(context);
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: isTablet ? 320 : 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Image.asset(
              'assets/images/rosary_backround.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: HomeV2.primary.withValues(alpha: 0.4)),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.10),
                    HomeV2.primary.withValues(alpha: 0.55),
                    bg,
                  ],
                  stops: const [0.0, 0.35, 0.85, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadData,
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('rosary_main_title'),
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 34 : 28,
                    color: Colors.white,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('rosary_main_subtitle'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: halo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Karta ───────────────────────────────────────────────────────────────────
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      );

  // ── Návod ───────────────────────────────────────────────────────────────────
  Widget _buildHowToSection() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.07),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [HomeV2.primary, Color(0xFF6B73A8)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    tr('how_to_pray_rosary'),
                    style: HomeV2.serifTitle(context, size: 19),
                  ),
                ),
              ],
            ),
          ),
          _expansion(
            emoji: '📿',
            title: tr('traditional_rosary'),
            children: [
              _bulletItem(tr('opening_prayers')),
              _bulletItem(tr('five_decades')),
              _bulletItem(tr('decade_structure')),
            ],
          ),
          Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            color: HomeV2.primary.withValues(alpha: 0.08),
          ),
          _expansion(
            emoji: '📖',
            title: tr('lectio_divina_steps'),
            children: RosaryConstants.lectioDivinaSteps
                .map((step) => _buildLectioDivinaStep(step))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _expansion({
    required String emoji,
    required String title,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        iconColor: HomeV2.primary,
        collapsedIconColor: HomeV2.iconAccent(context),
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
        children: children,
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: AppSpacing.md),
            decoration: BoxDecoration(
              color: HomeV2.iconAccent(context),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectioDivinaStep(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.md),
            decoration: BoxDecoration(
              color: RosaryConstants.hexToColor(step['color']),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${step['title']}: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                  TextSpan(
                    text: step['description'],
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: HomeV2.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Kategórie ─────────────────────────────────────────────────────────────
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
          child: Text(
            tr('select_mystery_category'),
            style: HomeV2.serifTitle(context, size: 21),
          ),
        ),
        ...RosaryCategory.values.map((category) {
          final categoryInfo = RosaryConstants.getCategoryInfo(category);
          final stats = _categoryStats.firstWhere(
            (s) => s.category == category,
            orElse: () => RosaryCategoryStats(
              category: category,
              totalCount: 0,
              withAudio: 0,
              withImages: 0,
            ),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildCategoryCard(category, categoryInfo, stats),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryCard(
    RosaryCategory category,
    RosaryCategoryInfo categoryInfo,
    RosaryCategoryStats stats,
  ) {
    final color = RosaryConstants.hexToColor(categoryInfo.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        onTap: () {
          HapticFeedback.lightImpact();
          _navigateToCategory(category);
        },
        child: Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(categoryInfo.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryInfo.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      categoryInfo.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: HomeV2.textMuted(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.book_rounded,
                            size: 14, color: HomeV2.textMuted(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${stats.totalCount}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                        if (stats.withAudio > 0) ...[
                          const SizedBox(width: AppSpacing.md),
                          Icon(Icons.headphones_rounded, size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.withAudio}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ── Prínosy ─────────────────────────────────────────────────────────────────
  Widget _buildBenefitsSection() {
    return Column(
      children: [
        _benefitCard(
          icon: Icons.favorite_rounded,
          iconColor: HomeV2.primary,
          title: tr('spiritual_benefits'),
          items: const [
            [Icons.auto_stories_rounded, 'deeper_understanding'],
            [Icons.visibility_rounded, 'peaceful_prayer'],
            [Icons.directions_walk_rounded, 'practical_application'],
            [Icons.trending_up_rounded, 'spiritual_growth'],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _benefitCard(
          icon: Icons.phone_android_rounded,
          iconColor: const Color(0xFFB8862F),
          title: tr('app_features'),
          items: const [
            [Icons.headphones_rounded, 'audio_recordings'],
            [Icons.schedule_rounded, 'time_guidance'],
            [Icons.book_rounded, 'complete_texts'],
            [Icons.navigation_rounded, 'step_by_step'],
          ],
        ),
      ],
    );
  }

  Widget _benefitCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<List<dynamic>> items,
  }) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: HomeV2.serifTitle(context, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...items.map((it) => _benefitItem(it[0] as IconData, tr(it[1] as String))),
        ],
      ),
    );
  }

  Widget _benefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: HomeV2.iconAccent(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: const Color(0xFFC0392B).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 52, color: Color(0xFFC0392B)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tr('error_loading_rosary'),
              style: HomeV2.serifTitle(context, size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? tr('unknown_error'),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
              label: Text(
                tr('try_again'),
                style: TextStyle(
                    color: HomeV2.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

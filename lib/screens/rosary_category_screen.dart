// lib/screens/rosary_category_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rosary_model.dart';
import '../services/rosary_service.dart';
import '../shared/rosary_constants.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'rosary_decade_screen.dart';
import 'intro_step_screen.dart';
import 'intro_screen.dart';

class RosaryCategoryScreen extends StatefulWidget {
  final RosaryCategory category;

  const RosaryCategoryScreen({super.key, required this.category});

  @override
  State<RosaryCategoryScreen> createState() => _RosaryCategoryScreenState();
}

class _RosaryCategoryScreenState extends State<RosaryCategoryScreen> {
  final RosaryService _rosaryService = RosaryService();
  List<RosaryDecade> _decades = [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDecades();
  }

  Future<void> _loadDecades() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lang = context.locale.languageCode;
      final decades = await _rosaryService.getDecadesForCategory(
        widget.category,
        lang,
      );
      if (mounted) {
        setState(() {
          _decades = decades;
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

  void _navigateToDecade(RosaryDecade decade) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RosaryDecadeScreen(
          category: widget.category,
          decadeOrder: decade.order,
        ),
      ),
    );
  }

  void _navigateToLectioDivinaStep(String step) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => IntroStepScreen(step: step)),
    );
  }

  void _navigateToLectioDivinaOverview() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => IntroScreen()));
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? get _firstDecadeImage {
    if (_decades.isNotEmpty && _decades.first.hasImage) {
      return _decades.first.illustrationImage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categoryInfo = RosaryConstants.getCategoryInfo(widget.category);
    final categoryColor = RosaryConstants.hexToColor(categoryInfo.color);

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
            _buildHero(categoryInfo, categoryColor),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadDecades,
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
                              _buildDecadesList(categoryColor),
                              const SizedBox(height: AppSpacing.xxl),
                              _buildSpiritualAdvice(categoryColor),
                              const SizedBox(height: AppSpacing.xxl),
                              _buildLectioDivinaInfo(),
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
  Widget _buildHero(RosaryCategoryInfo categoryInfo, Color categoryColor) {
    final topPad = MediaQuery.of(context).padding.top;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final bg = HomeV2.background(context);
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);
    final img = _firstDecadeImage;

    return SizedBox(
      height: isTablet ? 320 : 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: img != null
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: categoryColor),
                    errorWidget: (_, _, _) => ColoredBox(color: categoryColor),
                  )
                : ColoredBox(color: categoryColor),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    categoryColor.withValues(alpha: 0.45),
                    categoryColor.withValues(alpha: 0.85),
                    bg,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
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
                  onTap: _loadDecades,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(categoryInfo.icon,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        categoryInfo.name,
                        style: HomeV2.serifTitle(
                          context,
                          size: isTablet ? 32 : 26,
                          color: Colors.white,
                          height: 1.1,
                        ).copyWith(shadows: halo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  categoryInfo.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
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

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      );

  // ── Desiatky ────────────────────────────────────────────────────────────────
  Widget _buildDecadesList(Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tr('rosary_mysteries'),
                  style: HomeV2.serifTitle(context, size: 21),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: categoryColor),
                  const SizedBox(width: 4),
                  Text(
                    '${_decades.length}/5 ${tr('available')}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: HomeV2.textMuted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_decades.isEmpty)
          _buildEmptyState()
        else
          ...List.generate(_decades.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildDecadeCard(categoryColor, _decades[index], index + 1),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: HomeV2.textMuted(context)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('no_mysteries'),
            style: TextStyle(fontSize: 15, color: HomeV2.textMuted(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDecadeCard(
    Color categoryColor,
    RosaryDecade decade,
    int displayOrder,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        onTap: () {
          HapticFeedback.lightImpact();
          _navigateToDecade(decade);
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
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$displayOrder',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decade.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: HomeV2.textDark(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _stripHtml(decade.introduction),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: HomeV2.textMuted(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: categoryColor),
            ],
          ),
        ),
      ),
    );
  }

  // ── Duchovné rady ─────────────────────────────────────────────────────────
  Widget _buildSpiritualAdvice(Color categoryColor) {
    final advices = [
      'find_quiet_place',
      'prepare_heart',
      'pray_holy_spirit',
      'let_text_speak',
      'embrace_silence',
      'talk_jesus_mary',
    ];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  tr('spiritual_advice'),
                  style: HomeV2.serifTitle(context, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...advices.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7, right: AppSpacing.md),
                      decoration:
                          BoxDecoration(color: categoryColor, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(
                        tr(a),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Lectio Divina info ──────────────────────────────────────────────────────
  Widget _buildLectioDivinaInfo() {
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [HomeV2.primary, Color(0xFF6B73A8)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child:
                    const Icon(Icons.info_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  tr('lectio_divina_process'),
                  style: HomeV2.serifTitle(context, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('lectio_divina_description'),
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HomeV2.textMuted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  RosaryConstants.lectioDivinaSteps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepColor = RosaryConstants.hexToColor(step['color']);
                const stepSlugs = [
                  'silencio',
                  'lectio',
                  'meditatio',
                  'oratio',
                  'contemplatio',
                  'actio',
                ];
                final stepSlug =
                    index < stepSlugs.length ? stepSlugs[index] : 'lectio';

                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToLectioDivinaStep(stepSlug),
                      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: stepColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                          border: Border.all(
                            color: stepColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: stepColor,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                boxShadow: [
                                  BoxShadow(
                                    color: stepColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(step['icon'],
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              step['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HomeV2.textDark(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step['description'],
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: HomeV2.textMuted(context),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stepColor.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.touch_app_rounded,
                                      size: 12, color: stepColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('tap_to_start'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: stepColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigateToLectioDivinaOverview,
              icon: const Icon(Icons.auto_stories_rounded, size: 18),
              label: Text(tr('view_complete_guide')),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeV2.iconAccent(context),
                side: BorderSide(color: HomeV2.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
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
              tr('error_loading_mysteries'),
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
              onPressed: _loadDecades,
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

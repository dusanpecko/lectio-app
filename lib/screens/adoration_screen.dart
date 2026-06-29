// lib/screens/adoration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/adoration_model.dart';
import '../services/adoration_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'adoration_detail_screen.dart';

class AdorationScreen extends StatefulWidget {
  const AdorationScreen({super.key});

  @override
  State<AdorationScreen> createState() => _AdorationScreenState();
}

class _AdorationScreenState extends State<AdorationScreen> {
  final AdorationService _adorationService = AdorationService();
  List<Adoration> _adorations = [];
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
      final adorations = await _adorationService.getAdorations(lang);

      if (mounted) {
        setState(() {
          _adorations = adorations;
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

  void _navigateToAdoration(Adoration adoration) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdorationDetailScreen(
          adorationId: adoration.id,
          initialAdoration: adoration,
        ),
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
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              MediaQuery.of(context).viewPadding.bottom +
                                  AppSpacing.xxl,
                            ),
                            itemCount: _adorations.length,
                            itemBuilder: (context, index) =>
                                _buildAdorationCard(_adorations[index], index),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero (foto pozadie) ─────────────────────────────────────────────────────
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
              'assets/images/adoration-background.webp',
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
                  tr('adoration_main_title'),
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 34 : 28,
                    color: Colors.white,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('adoration_main_subtitle'),
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

  // ── Karta adorácie ──────────────────────────────────────────────────────────
  Widget _buildAdorationCard(Adoration adoration, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToAdoration(adoration);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [HomeV2.primary, Color(0xFF6B73A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
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
                        adoration.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: HomeV2.textDark(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (adoration.biblicalText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          adoration.biblicalText,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: HomeV2.iconAccent(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (adoration.author != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          adoration.author!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: HomeV2.textMuted(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (adoration.hasAudio || adoration.hasImage) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (adoration.hasAudio)
                              _chip(Icons.headphones_rounded, tr('audio'),
                                  HomeV2.primary),
                            if (adoration.hasImage) ...[
                              if (adoration.hasAudio)
                                const SizedBox(width: AppSpacing.sm),
                              _chip(Icons.image_rounded, tr('image'),
                                  const Color(0xFFB8862F)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
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
              tr('error_loading_adorations'),
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

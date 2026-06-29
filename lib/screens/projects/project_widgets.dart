import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/project_campaign_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';

const _purpleDark = Color(0xFF40467b);
const _accent = Color(0xFF686ea3);
const _navy = Color(0xFF0A0E1A);

/// Hero hlavička projektovej stránky (obrázok alebo gradient + overlay + späť).
class ProjectHero extends StatelessWidget {
  final String badge;
  final IconData badgeIcon;
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? imageAsset;

  const ProjectHero({
    super.key,
    required this.badge,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
    required this.chips,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned.fill(
          child: imageAsset != null
              ? Image.asset(imageAsset!, fit: BoxFit.cover, alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const ColoredBox(color: _purpleDark))
              : const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_navy, _purpleDark, _accent],
                    ),
                  ),
                ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE640467b), Color(0xCC0A0E1A)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.xl, topPad + 64, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HomeV2.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HomeV2.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 15, color: HomeV2.goldLight),
                    const SizedBox(width: 6),
                    Text(badge,
                        style: TextStyle(
                          color: HomeV2.goldLight,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title,
                  style: HomeV2.serifTitle(context, size: 34, color: Colors.white, height: 1.1)),
              const SizedBox(height: AppSpacing.md),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15.5,
                    height: 1.5,
                  )),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map((c) => Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Text(c,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              )),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        // Späť
        Positioned(
          top: topPad + 6,
          left: AppSpacing.md,
          child: Material(
            color: Colors.black.withValues(alpha: 0.25),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Karta „Podpora projektu" s progress barom (koľko sa vyzbieralo).
class ProjectFundingBar extends StatelessWidget {
  final double percent; // 0..1
  final String collected;
  final String goal;

  const ProjectFundingBar({
    super.key,
    required this.percent,
    required this.collected,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 16, color: HomeV2.primary),
              const SizedBox(width: 6),
              Text('projects.funding_label'.tr(),
                  style: TextStyle(
                    color: HomeV2.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
              const Spacer(),
              Text('$pct %',
                  style: TextStyle(
                    color: HomeV2.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: HomeV2.primary.withValues(alpha: 0.12),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [HomeV2.gold, HomeV2.primary],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(collected,
                  style: TextStyle(
                    color: HomeV2.textDark(context),
                    fontWeight: FontWeight.w700,
                  )),
              Text('  ${'projects.funding_of'.tr(args: [goal])}',
                  style: TextStyle(color: HomeV2.textMuted(context))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Funding bar napojený na reálny stav projektovej zbierky.
/// Počas načítania (a pri offline) zobrazí seed hodnoty (fallback).
class LiveProjectFundingBar extends StatefulWidget {
  final String slug;
  final double fallbackRaised; // seed (kým príde odpoveď zo servera)
  final double goal;

  const LiveProjectFundingBar({
    super.key,
    required this.slug,
    required this.fallbackRaised,
    required this.goal,
  });

  @override
  State<LiveProjectFundingBar> createState() => _LiveProjectFundingBarState();
}

class _LiveProjectFundingBarState extends State<LiveProjectFundingBar> {
  CampaignProgress? _data;

  @override
  void initState() {
    super.initState();
    ProjectCampaignService.instance.fetch(widget.slug).then((p) {
      if (mounted && p != null) setState(() => _data = p);
    });
  }

  static String _eur(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf €';
  }

  @override
  Widget build(BuildContext context) {
    final goal = _data?.goal ?? widget.goal;
    final raised = _data?.raised ?? widget.fallbackRaised;
    final percent = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    return ProjectFundingBar(
      percent: percent,
      collected: _eur(raised),
      goal: _eur(goal),
    );
  }
}

/// Sekcia: prehľadový label + serif nadpis + voliteľný text.
class ProjectSection extends StatelessWidget {
  final String label;
  final String title;
  final String? text;

  const ProjectSection({
    super.key,
    required this.label,
    required this.title,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: HomeV2.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
          const SizedBox(height: 6),
          Text(title, style: HomeV2.serifTitle(context, size: 24)),
          if (text != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(text!,
                style: TextStyle(
                  color: HomeV2.textMuted(context),
                  fontSize: 15.5,
                  height: 1.55,
                )),
          ],
        ],
      ),
    );
  }
}

/// Karta funkcie (ikona + nadpis + text).
class ProjectFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const ProjectFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeV2.primary, _purpleDark],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: HomeV2.textDark(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                      color: HomeV2.textMuted(context),
                      fontSize: 14.5,
                      height: 1.45,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Karta „pre koho" (zvýraznená alebo svetlá).
class ProjectAudienceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool highlight;

  const ProjectAudienceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : HomeV2.textDark(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeV2.primary, _purpleDark],
              )
            : null,
        color: highlight ? null : HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: highlight
                  ? Colors.white.withValues(alpha: 0.18)
                  : HomeV2.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: highlight ? Colors.white : HomeV2.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                      color: highlight
                          ? Colors.white.withValues(alpha: 0.88)
                          : HomeV2.textMuted(context),
                      fontSize: 14.5,
                      height: 1.45,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pätička — „súčasť platformy lectio.one".
class ProjectFooterNote extends StatelessWidget {
  const ProjectFooterNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(HomeV2.radius),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${'projects.footer_brand'.tr()} '),
                TextSpan(
                    text: 'lectio.one',
                    style: TextStyle(color: HomeV2.gold, fontWeight: FontWeight.w800)),
              ],
            ),
            textAlign: TextAlign.center,
            style: HomeV2.serifTitle(context, size: 20, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'projects.footer_note'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.5),
          ),
        ],
      ),
    );
  }
}

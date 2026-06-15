import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Hero sekcia home obrazovky — rotujúci obrázok na pozadí, profil (avatar +
/// rámik podľa podpory) a zvonček, logo v strede horného riadku. Voliteľný
/// plávajúci badge (dotazník/podpora) v strede cez obrázok.
class HomeHeroSection extends StatelessWidget {
  final String imageAsset;
  final String? avatarUrl;
  final bool isSupporter;
  final Widget? floatingBadge;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  const HomeHeroSection({
    super.key,
    required this.imageAsset,
    this.avatarUrl,
    this.isSupporter = false,
    this.floatingBadge,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final height = isTablet ? 430.0 : 330.0;
    final bg = HomeV2.background(context);
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Obrázok na pozadí
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => ColoredBox(
                color: HomeV2.primary.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Jemný svetlý gradient — hore wash pre čitateľnosť titulu,
          // dole splynutie s pozadím obrazovky.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.85),
                    bg.withValues(alpha: 0.50),
                    Colors.transparent,
                    bg.withValues(alpha: 0.55),
                    bg,
                  ],
                  stops: const [0.0, 0.28, 0.50, 0.82, 1.0],
                ),
              ),
            ),
          ),

          // Horný riadok: profil — logo (stred) — notifikácie
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Row(
              children: [
                _ProfileAvatar(
                  avatarUrl: avatarUrl,
                  isSupporter: isSupporter,
                  tooltip: tr('profile_title'),
                  onTap: onProfileTap,
                ),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      HomeV2.isDark(context)
                          ? 'assets/icon/lectio logo_w.png'
                          : 'assets/icon/lectio_logo_color.png',
                      height: isTablet ? 46 : 38,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                _CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: tr('notifications.title'),
                  onTap: onNotificationsTap,
                ),
              ],
            ),
          ),

          // Plávajúci badge — občasný nudge (dotazník/podpora), medzi logom
          // a playerom.
          if (floatingBadge != null)
            Positioned(
              top: topPad + 92,
              left: 0,
              right: 0,
              child: Center(child: floatingBadge),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: HomeV2.card(context).withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: HomeV2.primary, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Profilové tlačidlo — reálna fotka po prihlásení, fallback anonymný ikon,
/// a zlatý prémiový rámik pre podporovateľov (aktívne predplatné).
class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool isSupporter;
  final String tooltip;
  final VoidCallback onTap;

  const _ProfileAvatar({
    required this.avatarUrl,
    required this.isSupporter,
    required this.tooltip,
    required this.onTap,
  });

  Widget _fallbackIcon(BuildContext context) => Center(
        child: Icon(Icons.person_outline_rounded,
            color: HomeV2.primary, size: 24),
      );

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;

    // Vyplnenie kruhu — fotka alebo ikon.
    final Widget circle = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomeV2.card(context).withValues(alpha: 0.92),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => _fallbackIcon(context),
              errorWidget: (_, _, _) => _fallbackIcon(context),
            )
          : _fallbackIcon(context),
    );

    // Zlatý rámik pre podporovateľov.
    final Widget node = isSupporter
        ? Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeV2.gold, HomeV2.goldLight],
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeV2.card(context),
              ),
              padding: const EdgeInsets.all(1.5),
              clipBehavior: Clip.antiAlias,
              child: circle,
            ),
          )
        : circle;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(width: 48, height: 48, child: node),
      ),
    );
  }
}

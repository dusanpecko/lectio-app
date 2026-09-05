import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'privacy_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Otvorí Flutter [LicensePage] obalenú do v2 témy (lavender pozadie,
  /// fialový appbar, serif titul) — aby ladila so zvyškom appky.
  void _openLicenses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) {
          final base = Theme.of(ctx);
          return Theme(
            data: base.copyWith(
              scaffoldBackgroundColor: HomeV2.background(ctx),
              cardColor: HomeV2.card(ctx),
              colorScheme: base.colorScheme.copyWith(primary: HomeV2.primary),
              appBarTheme: base.appBarTheme.copyWith(
                backgroundColor: HomeV2.background(ctx),
                foregroundColor: HomeV2.iconAccent(ctx),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                titleTextStyle: HomeV2.serifTitle(ctx, size: 20),
              ),
            ),
            child: LicensePage(
              applicationName: 'Lectio Divina',
              applicationVersion: _version,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 64,
                  height: 64,
                ),
              ),
              applicationLegalese: '© 2022–2026 lectio.one',
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Ikony stavového riadka podľa témy, nie natvrdo: `Brightness.dark`
      // znamená ČIERNE ikony, takže v tmavom režime boli čierne na tmavom
      // pozadí a hodiny ani wifi nebolo vidieť.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
          ),
          children: [
            _buildHero(),
            const SizedBox(height: AppSpacing.lg),

            _section(
              'about.page_title'.tr(),
              Text('about.description'.tr(), style: _body(context)),
            ),
            _section(
              'about.version_title'.tr(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'about.version_label'.tr()} $_version',
                    style: _body(context),
                  ),
                  Text('about.copyright'.tr(), style: _body(context)),
                ],
              ),
            ),
            _section(
              'about.contact_title'.tr(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _link(
                    Icons.email_outlined,
                    'info@lectio.one',
                    () => _launchUrl('mailto:info@lectio.one'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _link(
                    Icons.language_outlined,
                    'https://lectio.one',
                    () => _launchUrl('https://lectio.one'),
                  ),
                ],
              ),
            ),
            _section(
              'about.operator_title'.tr(),
              Text(
                '${'about.operator_name'.tr()} ${'about.operator_name_value'.tr()}\n'
                '${'about.operator_legal_form'.tr()} ${'about.operator_legal_form_value'.tr()}\n'
                '${'about.operator_ico'.tr()} ${'about.operator_ico_value'.tr()}\n'
                '${'about.operator_dic'.tr()} ${'about.operator_dic_value'.tr()}\n'
                '${'about.operator_duns'.tr()} ${'about.operator_duns_value'.tr()}\n'
                '${'about.operator_address'.tr()} ${'about.operator_address_value'.tr()}\n'
                '${'about.operator_reg_number'.tr()} ${'about.operator_reg_number_value'.tr()}\n'
                '${'about.operator_reg_office'.tr()} ${'about.operator_reg_office_value'.tr()}',
                style: _body(context),
              ),
            ),
            _buildTeamSection(context),
            _section(
              'about.bible_title'.tr(),
              Text('about.bible_copyrights'.tr(), style: _body(context, small: true)),
            ),
            _section(
              'about.lectio_title'.tr(),
              Text('about.lectio_copyright'.tr(), style: _body(context)),
            ),
            _section(
              'about.translations_title'.tr(),
              Text('about.translations_copyright'.tr(), style: _body(context)),
            ),
            _section(
              'about.audio_title'.tr(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _launchUrl('https://elevenlabs.io'),
                    child: Text(
                      'about.audio_description'.tr(),
                      style: _body(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('about.audio_music'.tr(), style: _body(context)),
                ],
              ),
            ),
            _section(
              'about.illustrations_title'.tr(),
              InkWell(
                onTap: () => _launchUrl('https://www.magnific.com'),
                child: Text(
                  'about.illustrations_description'.tr(),
                  style: _body(context),
                ),
              ),
            ),
            _section(
              'about.supporters_title'.tr(),
              Text('about.supporters_list'.tr(), style: _body(context)),
            ),
            _section(
              'about.privacy_title'.tr(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('about.privacy_description'.tr(), style: _body(context)),
                  const SizedBox(height: AppSpacing.md),
                  _outlinedButton(
                    Icons.privacy_tip_outlined,
                    'about.privacy_button'.tr(),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                ],
              ),
            ),
            _section(
              'about.opensource_title'.tr(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('about.opensource_description'.tr(), style: _body(context)),
                  const SizedBox(height: AppSpacing.md),
                  _outlinedButton(
                    Icons.description_outlined,
                    'about.opensource_button'.tr(),
                    _openLicenses,
                  ),
                ],
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
      Shadow(color: bg, blurRadius: 14),
      Shadow(color: bg, blurRadius: 6),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: isTablet ? 320 : 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Image.asset(
              'assets/images/lectioabout.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: HomeV2.primary.withValues(alpha: 0.15)),
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
                    bg.withValues(alpha: 0.55),
                    Colors.transparent,
                    bg.withValues(alpha: 0.85),
                    bg,
                  ],
                  stops: const [0.0, 0.3, 0.8, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
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
                  'about.hero_title'.tr(),
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 34 : 28,
                    color: HomeV2.primary,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
                const SizedBox(height: 4),
                Text(
                  'about.hero_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
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

  // ── Sekcia (v2 karta) ──────────────────────────────────────────────────────
  Widget _section(String title, Widget content) {
    return Container(
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
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeV2.iconAccent(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          content,
        ],
      ),
    );
  }

  TextStyle _body(BuildContext context, {bool small = false}) => TextStyle(
        fontSize: small ? 13 : 15,
        height: 1.6,
        color: HomeV2.textDark(context),
      );

  // ── Tím ─────────────────────────────────────────────────────────────────────
  static const int _teamCount = 8;

  String _memberPhotoUrl(int index) =>
      'https://www.lectio.one/profile_$index.webp';

  Widget _buildTeamSection(BuildContext context) {
    return Container(
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
            'about.team_title'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeV2.iconAccent(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('about.team_description'.tr(), style: _body(context, small: true)),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 4;
              const spacing = AppSpacing.md;
              final itemW =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: AppSpacing.lg,
                children: List.generate(
                  _teamCount,
                  (i) => _teamAvatar(context, i + 1, itemW),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _teamAvatar(BuildContext context, int index, double itemWidth) {
    final name = 'about.team_m${index}_name'.tr();
    final avatar = itemWidth.clamp(56.0, 88.0);
    return SizedBox(
      width: itemWidth,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showMemberBio(context, index);
        },
        borderRadius: BorderRadius.circular(avatar),
        child: Column(
          children: [
            Container(
              width: avatar,
              height: avatar,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: HomeV2.softShadowSm(context),
                border: Border.all(
                  color: HomeV2.primary.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _memberPhotoUrl(index),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(
                    color: HomeV2.primary.withValues(alpha: 0.08),
                  ),
                  errorWidget: (_, _, _) => _avatarFallback(context, name),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: HomeV2.textDark(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String name) {
    final initials = name
        .replaceAll(RegExp(r'(o\.|P\.|Fr\.|Hna\.|sr\.|Sr\.)\s*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
    return ColoredBox(
      color: HomeV2.primary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: HomeV2.primary,
          ),
        ),
      ),
    );
  }

  void _showMemberBio(BuildContext context, int index) {
    final name = 'about.team_m${index}_name'.tr();
    final role = 'about.team_m${index}_role'.tr();
    final bio = 'about.team_m${index}_bio'.tr();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxH = MediaQuery.of(sheetContext).size.height * 0.85;
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
                      color: HomeV2.textMuted(sheetContext).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: HomeV2.softShadow(sheetContext),
                      border: Border.all(
                        color: HomeV2.primary.withValues(alpha: 0.2),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _memberPhotoUrl(index),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => ColoredBox(
                          color: HomeV2.primary.withValues(alpha: 0.08),
                        ),
                        errorWidget: (_, _, _) =>
                            _avatarFallback(sheetContext, name),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: HomeV2.serifTitle(
                      sheetContext,
                      size: 24,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    role,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: HomeV2.gold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: _body(sheetContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _link(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: HomeV2.iconAccent(context)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: HomeV2.iconAccent(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: HomeV2.primary,
        side: BorderSide(color: HomeV2.primary.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
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

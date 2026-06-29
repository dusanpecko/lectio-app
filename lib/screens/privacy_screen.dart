import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../shared/app_spacing.dart';
import '../shared/app_colors.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String _version = '';
  final Set<String> _expandedSections = {'intro'};

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  void _toggleSection(String sectionId) {
    setState(() {
      if (_expandedSections.contains(sectionId)) {
        _expandedSections.remove(sectionId);
      } else {
        _expandedSections.add(sectionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      decoration: BoxDecoration(
                        color: HomeV2.card(context),
                        borderRadius: BorderRadius.circular(HomeV2.radius),
                        boxShadow: HomeV2.softShadowSm(context),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            tr('privacy.header.app_name'),
                            style: theme.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      tr('privacy.last_updated'),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: AppColors.adaptiveCardSubtitle(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Sekcie
            _buildSection(
              id: 'intro',
              title: tr('privacy.intro.title'),
              icon: Icons.info_outline_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('privacy.intro.description'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.intro.purpose'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.intro.commitment'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            _buildSection(
              id: 'token',
              title: tr('privacy.token.title'),
              icon: Icons.key_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('privacy.token.description'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.isDark(context)
                          ? AppColors.darkCard
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.isDark(context)
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      tr('privacy.token.notice'),
                      style: const TextStyle(
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.token.generator'),
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),

            _buildSection(
              id: 'personal',
              title: tr('privacy.personal.title'),
              icon: Icons.person_outline_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('privacy.personal.intro'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(
                    (context.locale.languageCode == 'sk' ? 4 : 4),
                    (index) => Text(
                      '• ${tr('privacy.personal.items.$index')}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.personal.purpose'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    tr('privacy.personal.additional_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.personal.location_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.location_desc'),
                    style: theme.textTheme.bodySmall!.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr('privacy.personal.photos_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.photos_desc'),
                    style: theme.textTheme.bodySmall!.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr('privacy.personal.app_info_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.app_info_desc'),
                    style: theme.textTheme.bodySmall!.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr('privacy.personal.identifiers_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.identifiers_desc'),
                    style: theme.textTheme.bodySmall!.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),

            _buildSection(
              id: 'cookies',
              title: tr('privacy.cookies.title'),
              icon: Icons.cookie_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.isDark(context)
                          ? Colors.green.shade900.withValues(alpha: 0.3)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.isDark(context)
                            ? Colors.green.shade700
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            tr('privacy.cookies.notice'),
                            style: const TextStyle(
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.cookies.web_note'),
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),

            _buildSection(
              id: 'rights',
              title: tr('privacy.rights.title'),
              icon: Icons.gavel_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('privacy.rights.intro'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(
                    5,
                    (index) => Text(
                      '• ${tr('privacy.rights.items.$index')}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.rights.request'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            _buildSection(
              id: 'contact',
              title: tr('privacy.contact.title'),
              icon: Icons.contact_mail_rounded,
              theme: theme,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('privacy.contact.question'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('privacy.contact.organization'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('privacy.contact.address'),
                    style: const TextStyle(height: 1.5),
                  ),
                  Text(
                    tr('privacy.contact.ico'),
                    style: const TextStyle(height: 1.5),
                  ),
                  Text(
                    tr('privacy.contact.dic'),
                    style: const TextStyle(height: 1.5),
                  ),
                  Text(
                    tr('privacy.contact.duns'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr('privacy.contact.email'),
                    style: const TextStyle(height: 1.5),
                  ),
                  Text(
                    tr('privacy.contact.web'),
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Footer
            Center(
              child: Column(
                children: [
                  if (_version.isNotEmpty) ...[
                    Text(
                      '${tr('privacy.footer.version')} $_version',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.adaptiveCardSubtitle(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    tr('privacy.footer.copyright'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.adaptiveCardSubtitle(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tr('privacy.footer.rights'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.adaptiveCardSubtitle(context),
                    ),
                  ),
                ],
              ),
            ),
                    const SizedBox(height: AppSpacing.xxl),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('privacy.page_title'),
            style: HomeV2.serifTitle(context, size: 26, height: 1.15),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String id,
    required String title,
    required IconData icon,
    required ThemeData theme,
    required Widget content,
  }) {
    final isExpanded = _expandedSections.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(id),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(icon, color: HomeV2.iconAccent(context), size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: HomeV2.textMuted(context),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
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

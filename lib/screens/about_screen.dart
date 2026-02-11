import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            title: Text(
              'about.page_title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/lectioabout.webp',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.5),
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'about.hero_title'.tr(),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'about.hero_subtitle'.tr(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // O aplikácii
                  _buildSection(
                    theme: theme,
                    title: 'about.page_title'.tr(),
                    content: Text(
                      'about.description'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Verzia aplikácie
                  _buildSection(
                    theme: theme,
                    title: 'about.version_title'.tr(),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'about.version_label'.tr()} $_version',
                          style: const TextStyle(height: 1.6),
                        ),
                        Text(
                          'about.copyright'.tr(),
                          style: const TextStyle(height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  // Kontakt
                  _buildSection(
                    theme: theme,
                    title: 'about.contact_title'.tr(),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => _launchUrl('mailto:info@lectio.one'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'info@lectio.one',
                                  style: TextStyle(
                                    height: 1.6,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _launchUrl('https://lectio.one'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.language_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'https://lectio.one',
                                  style: TextStyle(
                                    height: 1.6,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prevádzkovateľ aplikácie
                  _buildSection(
                    theme: theme,
                    title: 'about.operator_title'.tr(),
                    content: Text(
                      '${'about.operator_name'.tr()} ${'about.operator_name_value'.tr()}\n'
                      '${'about.operator_legal_form'.tr()} ${'about.operator_legal_form_value'.tr()}\n'
                      '${'about.operator_ico'.tr()} ${'about.operator_ico_value'.tr()}\n'
                      '${'about.operator_address'.tr()} ${'about.operator_address_value'.tr()}\n'
                      '${'about.operator_reg_number'.tr()} ${'about.operator_reg_number_value'.tr()}\n'
                      '${'about.operator_reg_office'.tr()} ${'about.operator_reg_office_value'.tr()}',
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Spolupracovali
                  _buildSection(
                    theme: theme,
                    title: 'about.collaborators_title'.tr(),
                    content: Text(
                      'about.collaborators_names'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Texty Svätého písma
                  _buildSection(
                    theme: theme,
                    title: 'about.bible_title'.tr(),
                    content: Text(
                      'about.bible_copyrights'.tr(),
                      style: const TextStyle(height: 1.6, fontSize: 13),
                    ),
                  ),

                  // Texty Lectio Divina
                  _buildSection(
                    theme: theme,
                    title: 'about.lectio_title'.tr(),
                    content: Text(
                      'about.lectio_copyright'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Texty Lectio Divina – preklady
                  _buildSection(
                    theme: theme,
                    title: 'about.translations_title'.tr(),
                    content: Text(
                      'about.translations_copyright'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Texty zamyslení
                  _buildSection(
                    theme: theme,
                    title: 'about.reflections_title'.tr(),
                    content: Text(
                      'about.reflections_copyright'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Audio
                  _buildSection(
                    theme: theme,
                    title: 'about.audio_title'.tr(),
                    content: InkWell(
                      onTap: () => _launchUrl('https://elevenlabs.io'),
                      child: Text(
                        'about.audio_description'.tr(),
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ),

                  // Ilustrácie a grafické prvky
                  _buildSection(
                    theme: theme,
                    title: 'about.illustrations_title'.tr(),
                    content: InkWell(
                      onTap: () => _launchUrl('https://freepik.com'),
                      child: Text(
                        'about.illustrations_description'.tr(),
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ),

                  // Podporili nás
                  _buildSection(
                    theme: theme,
                    title: 'about.supporters_title'.tr(),
                    content: Text(
                      'about.supporters_list'.tr(),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),

                  // Ochrana osobných údajov
                  _buildSection(
                    theme: theme,
                    title: 'about.privacy_title'.tr(),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'about.privacy_description'.tr(),
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: Text('about.privacy_button'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open-source knižnice
                  _buildSection(
                    theme: theme,
                    title: 'about.opensource_title'.tr(),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'about.opensource_description'.tr(),
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            showLicensePage(
                              context: context,
                              applicationName: 'Lectio Divina',
                              applicationVersion: _version,
                              applicationIcon: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.asset(
                                  'assets/icon/icon.png',
                                  width: 64,
                                  height: 64,
                                ),
                              ),
                              applicationLegalese: '© 2022–2026 lectio.one',
                            );
                          },
                          icon: const Icon(Icons.description_outlined),
                          label: Text('about.opensource_button'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required Widget content,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

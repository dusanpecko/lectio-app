import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(tr('privacy.page_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('privacy.header.app_name'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('privacy.last_updated'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                  const SizedBox(height: 12),
                  Text(
                    tr('privacy.intro.purpose'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      tr('privacy.token.notice'),
                      style: const TextStyle(
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  ...List.generate(
                    (context.locale.languageCode == 'sk' ? 4 : 4),
                    (index) => Text(
                      '• ${tr('privacy.personal.items.$index')}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('privacy.personal.purpose'),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('privacy.personal.additional_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('privacy.personal.location_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.location_desc'),
                    style: const TextStyle(height: 1.5, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('privacy.personal.photos_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.photos_desc'),
                    style: const TextStyle(height: 1.5, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('privacy.personal.app_info_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.app_info_desc'),
                    style: const TextStyle(height: 1.5, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('privacy.personal.identifiers_title'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    tr('privacy.personal.identifiers_desc'),
                    style: const TextStyle(height: 1.5, fontSize: 13),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  ...List.generate(
                    5,
                    (index) => Text(
                      '• ${tr('privacy.rights.items.$index')}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  Text(
                    tr('privacy.contact.organization'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
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

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Column(
                children: [
                  if (_version.isNotEmpty) ...[
                    Text(
                      '${tr('privacy.footer.version')} $_version',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    tr('privacy.footer.copyright'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('privacy.footer.rights'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.primary,
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

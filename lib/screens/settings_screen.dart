// ignore_for_file: deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBible = 'biblia1';
  bool _isLoadingBible = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  // Výber biblie je teraz jednotný pre všetky jazyky - biblia1, biblia2, biblia3
  // Lokalizované názvy sa načítajú z príslušného JSON súboru

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    // Jeden kľúč pre výber biblie - rovnaký pre všetky jazyky
    final bible = prefs.getString('selectedBible') ?? 'biblia1';

    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _isLoadingBible = false;
    });
  }

  Future<void> _onBibleChanged(String? value) async {
    if (value == null) return;
    setState(() => _selectedBible = value);

    final prefs = await SharedPreferences.getInstance();
    // Jeden kľúč pre výber biblie - rovnaký pre všetky jazyky
    await prefs.setString('selectedBible', value);
  }

  Future<void> _onThemeModeChanged(ThemeMode? mode) async {
    if (mode == null) return;
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setThemeMode(mode);
  }

  Future<void> _onFontFamilyChanged(String? family) async {
    if (family == null) return;
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setFontFamily(family);
  }

  Future<void> _onFontSizeChanged(double size) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setFontSize(size);
  }

  Future<void> _onLanguageChanged(String? language) async {
    if (language == null) return;
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setLanguageCode(language, context);
  }

  /// Vráti správny TextStyle pre preview podľa zvoleného fontu
  TextStyle _getPreviewTextStyle(ThemeProvider themeProvider) {
    final fontSize = themeProvider.fontSize;

    switch (themeProvider.fontFamily) {
      case 'Default':
        return GoogleFonts.inter(fontSize: fontSize);
      case 'Serif':
        return GoogleFonts.merriweather(fontSize: fontSize);
      case 'Monospace':
        return GoogleFonts.robotoMono(fontSize: fontSize);
      default:
        return TextStyle(fontSize: fontSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final themeProvider = context.watch<ThemeProvider>();
    final userEmail = session?.user.email ?? tr('guest');

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profil / Prihlásenie
          _buildUserInfoCard(context, userEmail),
          const SizedBox(height: 16),

          // 2. Výber Biblie
          _buildBibleCard(),
          const SizedBox(height: 16),

          // 3. Jazyk
          _buildLanguageCard(themeProvider),
          const SizedBox(height: 16),

          // 4. Písmo a veľkosť písma
          _buildFontCard(themeProvider),
          const SizedBox(height: 16),

          // 5. Téma (systém/svetlá/tmavá)
          _buildThemeCard(themeProvider),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, String email) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (!isLoggedIn) {
      // Pre neprihlásených používateľov ukáž tlačidlo na prihlásenie
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.login, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                tr('not_logged_in'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr('login_to_sync'),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: Text(tr('sign_in')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pre prihlásených používateľov ukáž profil
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          tr('user'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
    );
  }

  Widget _buildThemeCard(ThemeProvider themeProvider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_6),
                const SizedBox(width: 8),
                Text(
                  tr('settings_screen.theme.title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Row(
                    children: [
                      const Icon(Icons.phone_android, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.theme.system')),
                    ],
                  ),
                  subtitle: Text(tr('settings_screen.theme.system_desc')),
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: _onThemeModeChanged,
                ),
                RadioListTile<ThemeMode>(
                  title: Row(
                    children: [
                      const Icon(Icons.light_mode, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.theme.light')),
                    ],
                  ),
                  subtitle: Text(tr('settings_screen.theme.light_desc')),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: _onThemeModeChanged,
                ),
                RadioListTile<ThemeMode>(
                  title: Row(
                    children: [
                      const Icon(Icons.dark_mode, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.theme.dark')),
                    ],
                  ),
                  subtitle: Text(tr('settings_screen.theme.dark_desc')),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: _onThemeModeChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard(ThemeProvider themeProvider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields),
                const SizedBox(width: 8),
                Text(
                  tr('settings_screen.font.title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Font Family
            Text(
              tr('settings_screen.font.family'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: themeProvider.fontFamily,
              onChanged: _onFontFamilyChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Default',
                  child: Text(
                    tr('settings_screen.font.default'),
                    style: const TextStyle(fontFamily: 'Inter'),
                  ),
                ),
                const DropdownMenuItem(
                  value: 'Serif',
                  child: Text('Serif', style: TextStyle(fontFamily: 'serif')),
                ),
                const DropdownMenuItem(
                  value: 'Monospace',
                  child: Text(
                    'Monospace',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Font Size
            Text(
              tr('settings_screen.font.size'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  tr('settings_screen.font.small'),
                  style: const TextStyle(fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: themeProvider.fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: themeProvider.fontSize.round().toString(),
                    onChanged: _onFontSizeChanged,
                  ),
                ),
                Text(
                  tr('settings_screen.font.large'),
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr('settings_screen.font.preview'),
                style: _getPreviewTextStyle(themeProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(ThemeProvider themeProvider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 8),
                Text(
                  tr('settings_screen.language.title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: themeProvider.languageCode,
              onChanged: _onLanguageChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.language.system')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'sk',
                  child: Row(
                    children: [
                      const Text('🇸🇰', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.language.slovak')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.language.english')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'es',
                  child: Row(
                    children: [
                      const Text('🇪🇸', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(tr('settings_screen.language.spanish')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Vytvorí dropdown items pre biblické preklady
  /// Vždy používa biblia1, biblia2, biblia3 - názvy sú lokalizované v JSON súboroch
  List<DropdownMenuItem<String>> _buildBibleDropdownItems() {
    return [
      DropdownMenuItem(
        value: 'biblia1',
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tr('bible_1'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: ' - ${tr('bible_1_desc')}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DropdownMenuItem(
        value: 'biblia2',
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tr('bible_2'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: ' - ${tr('bible_2_desc')}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DropdownMenuItem(
        value: 'biblia3',
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tr('bible_3'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: ' - ${tr('bible_3_desc')}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];
  }

  Widget _buildBibleCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: 8),
                Text(
                  tr('select_bible'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoadingBible
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedBible,
                    onChanged: _onBibleChanged,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    items: _buildBibleDropdownItems(),
                  ),
          ],
        ),
      ),
    );
  }
}

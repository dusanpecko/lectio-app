import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';
import 'package:lectio_divina/services/do_not_disturb_service.dart';
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

  // Do Not Disturb Service
  final DoNotDisturbService _dndService = DoNotDisturbService();
  bool _dndEnabled = false;
  bool _dndAutoActivate = true;
  int _dndActivationDelay = 30;
  bool _dndPermissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
    _initDoNotDisturbSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkBibleCompatibility();
  }

  /// Skontroluje kompatibilitu aktuálnej biblickej selekcie s jazykom
  void _checkBibleCompatibility() {
    final currentLang = context.locale.languageCode;
    bool needsUpdate = false;
    String newBible = _selectedBible;

    if (currentLang == 'sk') {
      // Ak sme v slovenčine ale máme anglickú bibliu, nastavíme default slovenskú
      if (_selectedBible.startsWith('bible_en_')) {
        newBible = 'biblia1';
        needsUpdate = true;
      }
    } else {
      // Ak sme v angličtine ale máme slovenskú bibliu, nastavíme default anglickú
      if (_selectedBible.startsWith('biblia')) {
        newBible = 'bible_en_1';
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() {
        _selectedBible = newBible;
      });

      // Uložíme novú hodnotu
      _saveBibleCompatibilityChange(newBible, currentLang);
    }
  }

  /// Uloží zmenu biblie kvôli kompatibilite s jazykom
  Future<void> _saveBibleCompatibilityChange(String bible, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    String bibleKey = lang == 'sk' ? 'selectedBible_sk' : 'selectedBible_en';
    await prefs.setString(bibleKey, bible);
  }

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final currentLang = context.locale.languageCode;

    // Bible - nastavenie závislé od jazyka
    String defaultBible;
    String bibleKey;

    if (currentLang == 'sk') {
      bibleKey = 'selectedBible_sk';
      defaultBible = 'biblia1';
    } else {
      bibleKey = 'selectedBible_en';
      defaultBible = 'bible_en_1';
    }

    final bible = prefs.getString(bibleKey) ?? defaultBible;

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

    if (!mounted) return;

    final currentLang = context.locale.languageCode;

    // Ulož do správneho kľúča podľa jazyka
    String bibleKey = currentLang == 'sk'
        ? 'selectedBible_sk'
        : 'selectedBible_en';
    await prefs.setString(bibleKey, value);
  }

  /// Inicializácia Do Not Disturb nastavení
  Future<void> _initDoNotDisturbSettings() async {
    await _dndService.initialize();
    if (!mounted) return;

    final permissionsGranted = await _dndService.checkPermissions();

    setState(() {
      _dndEnabled = _dndService.isEnabled;
      _dndAutoActivate = _dndService.autoActivate;
      _dndActivationDelay = _dndService.activationDelaySeconds;
      _dndPermissionsGranted = permissionsGranted;
    });
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
          _buildUserInfoCard(context, userEmail),
          const SizedBox(height: 16),

          // Theme Settings
          _buildThemeCard(themeProvider),
          const SizedBox(height: 16),

          // Font Settings
          _buildFontCard(themeProvider),
          const SizedBox(height: 16),

          // Language Settings
          _buildLanguageCard(themeProvider),
          const SizedBox(height: 16),

          // Prayer Focus Mode
          _buildPrayerFocusCard(),
          const SizedBox(height: 16),

          // Bible Selection (pre všetky jazyky)
          _buildBibleCard(),
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
              initialValue: themeProvider.fontFamily,
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
              initialValue: themeProvider.languageCode,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Vytvorí dropdown items pre biblické preklady podľa aktuálneho jazyka
  List<DropdownMenuItem<String>> _buildBibleDropdownItems() {
    final currentLang = context.locale.languageCode;

    if (currentLang == 'sk') {
      // Slovenské biblické preklady
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
    } else {
      // Pre angličtinu a ostatné jazyky - anglické biblické preklady
      return [
        DropdownMenuItem(
          value: 'bible_en_1',
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: tr('bible_en_1'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: ' - ${tr('bible_en_1_desc')}',
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
          value: 'bible_en_2',
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: tr('bible_en_2'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: ' - ${tr('bible_en_2_desc')}',
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
          value: 'bible_en_3',
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: tr('bible_en_3'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: ' - ${tr('bible_en_3_desc')}',
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
  }

  Widget _buildPrayerFocusCard() {
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
                const Icon(Icons.do_not_disturb),
                const SizedBox(width: 8),
                const Text(
                  'Režim Nerušiť',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Automatické stlmenie notifikácií počas čítania a modlitby',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Permissions check
            if (!_dndPermissionsGranted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Potrebné povolenia',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pre funkciu "Nerušiť" je potrebné povoliť prístup k notifikáciám a systémovým nastaveniam.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[700]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final granted = await _dndService.requestPermissions();
                        setState(() {
                          _dndPermissionsGranted = granted;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Povoliť prístup'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main toggle
            SwitchListTile(
              title: const Text('Zapnúť automaticky'),
              subtitle: Text(
                'Aktivuje sa po $_dndActivationDelay sekundách čítania',
              ),
              value: _dndEnabled,
              onChanged: _dndPermissionsGranted
                  ? (value) async {
                      await _dndService.setEnabled(value);
                      setState(() {
                        _dndEnabled = value;
                      });
                    }
                  : null,
              contentPadding: EdgeInsets.zero,
            ),

            // Nastavenia (len ak je enabled)
            if (_dndEnabled && _dndPermissionsGranted) ...[
              const Divider(),
              const Text(
                'Nastavenia aktivácie:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Auto activate toggle
              SwitchListTile(
                title: const Text('Automatická aktivácia'),
                subtitle: const Text('Aktivuje sa automaticky pri čítaní'),
                value: _dndAutoActivate,
                onChanged: (value) async {
                  await _dndService.setAutoActivate(value);
                  setState(() {
                    _dndAutoActivate = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              // Activation delay slider
              if (_dndAutoActivate) ...[
                const SizedBox(height: 8),
                Text(
                  'Oneskorenie aktivácie: $_dndActivationDelay sekúnd',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: _dndActivationDelay.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 11,
                  label: '$_dndActivationDelay s',
                  onChanged: (value) async {
                    final seconds = value.round();
                    await _dndService.setActivationDelay(seconds);
                    setState(() {
                      _dndActivationDelay = seconds;
                    });
                  },
                ),
              ],

              const SizedBox(height: 12),

              // Info boxes
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Urgentné hovory sú vždy povolené',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Platform-specific info
              if (Platform.isIOS) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shortcut_outlined,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'iOS Shortcuts pre DND',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pre najlepšiu skúsenosť si vytvorte iOS Shortcuts pre automatické zapínanie/vypínanie Focus režimu.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await _dndService.openIOSShortcutsApp();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Shortcuts app otvorená. Vytvorte si Shortcuts pre Lectio Divina DND.',
                                      ),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Chyba pri otváraní Shortcuts: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text(
                                'Shortcuts',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showIOSShortcutsInstructions(),
                              icon: const Icon(Icons.help_outline, size: 16),
                              label: const Text(
                                'Návod',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[100],
                                foregroundColor: Colors.blue[800],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Používa systémový "Nerušiť" režim pre automatické stlmenie notifikácií',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Manuálne ovládanie sekcia
            if (_dndPermissionsGranted) ...[
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.touch_app, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Manuálne ovládanie',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ovládanie v Lectio screen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'V Lectio obrazovke môžete režim "Nerušiť" zapnúť/vypnúť manuálne pomocou FAB menu (floating action button). Ikona "Nerušiť" sa zobrazí v navigation bare keď je aktívny.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<bool>(
                      stream: _dndService.dndStateStream,
                      initialData: _dndService.isDndActive,
                      builder: (context, snapshot) {
                        final isDndActive = snapshot.data ?? false;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDndActive
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDndActive
                                    ? Icons.do_not_disturb_on
                                    : Icons.do_not_disturb_off,
                                size: 14,
                                color: isDndActive
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDndActive
                                    ? 'Režim Nerušiť je AKTÍVNY'
                                    : 'Režim Nerušiť je neaktívny',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDndActive
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _dndService.toggleDnd();
                          if (!mounted) return;

                          final isDndActive = _dndService.isDndActive;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    isDndActive
                                        ? Icons.do_not_disturb_on
                                        : Icons.do_not_disturb_off,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isDndActive
                                        ? 'Režim Nerušiť aktivovaný'
                                        : 'Režim Nerušiť deaktivovaný',
                                  ),
                                ],
                              ),
                              backgroundColor: isDndActive
                                  ? Colors.green
                                  : Colors.grey[600],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Chyba pri prepínaní DND: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: StreamBuilder<bool>(
                        stream: _dndService.dndStateStream,
                        initialData: _dndService.isDndActive,
                        builder: (context, snapshot) {
                          final isDndActive = snapshot.data ?? false;
                          return Icon(
                            isDndActive
                                ? Icons.do_not_disturb_off
                                : Icons.do_not_disturb_on,
                            size: 18,
                          );
                        },
                      ),
                      label: StreamBuilder<bool>(
                        stream: _dndService.dndStateStream,
                        initialData: _dndService.isDndActive,
                        builder: (context, snapshot) {
                          final isDndActive = snapshot.data ?? false;
                          return Text(
                            isDndActive ? 'Vypnúť Nerušiť' : 'Zapnúť Nerušiť',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Background Play Settings
            _buildBackgroundPlayCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPlayCard() {
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
                const Icon(Icons.queue_music),
                const SizedBox(width: 8),
                const Text(
                  'Background Play',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pokračovanie prehrávania aj keď je aplikácia minimalizovaná',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Povoliť background play'),
              subtitle: const Text('Audio pokračuje aj v pozadí'),
              value: true, // TODO: Load from SharedPreferences
              onChanged: (value) async {
                // TODO: Save to SharedPreferences and update background audio service
                // await _backgroundAudioManager.setBackgroundPlayEnabled(value);
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Info note
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zobrazí sa notifikácia s ovládacími prvkami pre audio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                    initialValue: _selectedBible,
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

  /// Zobrazenie detailných inštrukcií pre iOS Shortcuts
  void _showIOSShortcutsInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shortcut_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('iOS Shortcuts pre Lectio Divina'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vytvorte si vlastné Shortcuts pre automatické ovládanie DND počas Lectio Divina:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // Krok 1
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Vytvorte nový Shortcut',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Otvorte Shortcuts app\n'
                      '• Kliknite na "+" pre nový shortcut\n'
                      '• Pomenujte ho "Lectio Divina DND On"',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Krok 2
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Pridajte akcie',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Vyhľadajte "Set Focus"\n'
                      '• Vyberte Focus režim (napr. "Do Not Disturb")\n'
                      '• Nastavte zapnutie Focus\n'
                      '• Uložte shortcut',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Krok 3
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Vytvorte druhý Shortcut',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Vytvorte "Lectio Divina DND Off"\n'
                      '• Pridajte "Set Focus" akciu\n'
                      '• Nastavte vypnutie Focus\n'
                      '• Uložte shortcut',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Po vytvorení sa Shortcuts automaticky spustia keď použijete DND tlačidlo v aplikácii.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavrieť'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _dndService.openIOSShortcutsApp();
              } catch (e) {
                if (!mounted) return;
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chyba pri otváraní Shortcuts: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Otvoriť Shortcuts'),
          ),
        ],
      ),
    );
  }
}

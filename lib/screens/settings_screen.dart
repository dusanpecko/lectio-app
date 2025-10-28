import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBible = 'biblia1';
  bool _isLoadingBible = true;

  // Theme settings
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoadingTheme = true;

  // Font settings
  String _fontFamily = 'Default';
  double _fontSize = 16.0;
  bool _isLoadingFont = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Bible
    final bible = prefs.getString('selectedBible') ?? 'biblia1';

    // Theme
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    final themeMode = _themeModeFromString(themeModeString);

    // Font
    final fontFamily = prefs.getString('fontFamily') ?? 'Default';
    final fontSize = prefs.getDouble('fontSize') ?? 16.0;

    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _themeMode = themeMode;
      _fontFamily = fontFamily;
      _fontSize = fontSize;
      _isLoadingBible = false;
      _isLoadingTheme = false;
      _isLoadingFont = false;
    });
  }

  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  Future<void> _onBibleChanged(String? value) async {
    if (value == null) return;
    setState(() => _selectedBible = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', value);
  }

  Future<void> _onThemeModeChanged(ThemeMode? mode) async {
    if (mode == null) return;
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeModeToString(mode));

    // Aplikuj zmenu témy okamžite
    if (mounted) {
      // TODO: Potrebuješ propagovať themeMode do MaterialApp
      // Bude potrebné refaktorovať main.dart aby používal provider alebo similar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_screen.theme_changed')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onFontFamilyChanged(String? family) async {
    if (family == null) return;
    setState(() => _fontFamily = family);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', family);
  }

  Future<void> _onFontSizeChanged(double size) async {
    setState(() => _fontSize = size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final userEmail = session?.user.email ?? tr('guest');
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserInfoCard(context, userEmail),
          const SizedBox(height: 16),

          // Theme Settings
          _buildThemeCard(),
          const SizedBox(height: 16),

          // Font Settings
          _buildFontCard(),
          const SizedBox(height: 16),

          // Bible Selection (len pre SK)
          if (locale == 'sk') ...[
            _buildBibleCard(),
            const SizedBox(height: 16),
          ],
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
              const Icon(Icons.login, size: 48, color: Color(0xFF4A5085)),
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
                  backgroundColor: const Color(0xFF4A5085),
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

  Widget _buildThemeCard() {
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
            _isLoadingTheme
                ? const Center(child: CircularProgressIndicator())
                : Column(
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
                        groupValue: _themeMode,
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
                        groupValue: _themeMode,
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
                        groupValue: _themeMode,
                        onChanged: _onThemeModeChanged,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard() {
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
            _isLoadingFont
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _fontFamily,
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
                          style: const TextStyle(fontFamily: 'Roboto'),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'Serif',
                        child: Text(
                          'Serif',
                          style: TextStyle(fontFamily: 'serif'),
                        ),
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
                    value: _fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: _fontSize.round().toString(),
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
                style: TextStyle(
                  fontFamily: _fontFamily == 'Default' ? null : _fontFamily,
                  fontSize: _fontSize,
                ),
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
                    value: _selectedBible,
                    onChanged: _onBibleChanged,
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
                        value: 'biblia1',
                        child: Text(tr('bible_1')),
                      ),
                      DropdownMenuItem(
                        value: 'biblia2',
                        child: Text(tr('bible_2')),
                      ),
                      DropdownMenuItem(
                        value: 'biblia3',
                        child: Text(tr('bible_3')),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

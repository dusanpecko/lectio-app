import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:lectio_divina/screens/about_screen.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/privacy_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBible = 'biblia_1';
  bool _isLoadingBible = true; // Začneme s loading stavom
  String? _lastLocale; // Sledovanie posledného jazyka

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale.languageCode;

    // Ak sa zmenil jazyk, skontroluj a resetuj bibliu ak treba
    if (_lastLocale != null && _lastLocale != currentLocale) {
      _handleLanguageChange(currentLocale);
    }
    _lastLocale = currentLocale;
  }

  /// Ošetrí zmenu jazyka - nastaví predvolenú bibliu pre daný jazyk
  Future<void> _handleLanguageChange(String newLocale) async {
    // Zisti, ktoré biblie sú dostupné pre nový jazyk a nastav prvú (defaultnú)
    final availableBibles = _getAvailableBiblesForLocale(newLocale);
    final defaultBible = availableBibles.first;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', defaultBible);

    // Synchronne updatneme state aby sa zabránilo flashu
    if (mounted) {
      _selectedBible = defaultBible;
      // Použijeme scheduleMicrotask aby sa state aktualizoval až po dokončení build cycle
      Future.microtask(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  /// Vráti zoznam dostupných biblií pre daný jazyk
  List<String> _getAvailableBiblesForLocale(String locale) {
    switch (locale) {
      case 'sk':
        return ['biblia_1', 'biblia_2', 'biblia_3'];
      case 'es':
        return ['biblia_3'];
      case 'en':
        return ['biblia_2'];
      default:
        return ['biblia_1'];
    }
  }

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    // Načítaj uloženú hodnotu
    String bible = prefs.getString('selectedBible') ?? 'biblia_1';

    // Komplexná migrácia starých hodnôt na nový formát
    bible = _migrateBibleValue(bible);

    // Kontrola: ak biblia nie je dostupná pre aktuálny jazyk, nastav na prvú dostupnú
    final currentLocale = context.locale.languageCode;
    final availableBibles = _getAvailableBiblesForLocale(currentLocale);
    if (!availableBibles.contains(bible)) {
      bible = availableBibles.first;
    }

    await prefs.setString('selectedBible', bible);

    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _isLoadingBible = false; // Ukončíme loading
    });
  }

  // Migruje starú hodnotu na nový formát (biblia_1, biblia_2, biblia_3)
  String _migrateBibleValue(String oldValue) {
    // Ak je už v správnom formáte, vráť ho
    if (oldValue == 'biblia_1' ||
        oldValue == 'biblia_2' ||
        oldValue == 'biblia_3') {
      return oldValue;
    }

    // Migrácia zo starých formátov
    switch (oldValue.toLowerCase()) {
      // Starý formát bez podčiarkovníka
      case 'biblia1':
      case 'bible_en_1':
        return 'biblia_1';

      case 'biblia2':
      case 'bible_en_2':
        return 'biblia_2';

      case 'biblia3':
      case 'bible_en_3':
        return 'biblia_3';

      // Databázové kódy
      case 'ssv':
      case 'standardny':
        return 'biblia_1';

      case 'jeruzalemsky':
      case 'jeruzalem':
        return 'biblia_2';

      case 'ekumenicky':
      case 'ekumen':
        return 'biblia_3';

      default:
        // Fallback na prvú bibliu
        return 'biblia_1';
    }
  }

  Future<void> _saveBibleSelection(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', value);
  }

  Future<void> _onBibleChanged(String? value) async {
    if (value == null) return;
    setState(() => _selectedBible = value);
    await _saveBibleSelection(value);
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

    // Biblia sa automaticky nastaví cez didChangeDependencies → _handleLanguageChange
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 1. Profil / Prihlásenie
          _buildUserInfoCard(context, userEmail),
          const SizedBox(height: AppSpacing.lg),

          // 2. Výber Biblie
          _buildBibleCard(),
          const SizedBox(height: AppSpacing.lg),

          // 3. Jazyk
          _buildLanguageCard(themeProvider),
          const SizedBox(height: AppSpacing.lg),

          // 4. Písmo a veľkosť písma
          _buildFontCard(themeProvider),
          const SizedBox(height: AppSpacing.lg),

          // 5. Téma (systém/svetlá/tmavá)
          _buildThemeCard(themeProvider),
          const SizedBox(height: AppSpacing.lg),

          // 6. O aplikácii a Ochrana osobných údajov
          _buildAboutAndPrivacyCard(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, String email) {
    final theme = Theme.of(context);
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (!isLoggedIn) {
      // Pre neprihlásených používateľov ukáž tlačidlo na prihlásenie
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: AppElevation.high,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Icon(Icons.login, size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('not_logged_in'),
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('login_to_sync'),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
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
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_6),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tr('settings_screen.theme.title'),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<ThemeMode>(
              groupValue: themeProvider.themeMode,
              onChanged: (value) => _onThemeModeChanged(value),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        const Icon(Icons.phone_android, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(tr('settings_screen.theme.system')),
                      ],
                    ),
                    subtitle: Text(tr('settings_screen.theme.system_desc')),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        const Icon(Icons.light_mode, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(tr('settings_screen.theme.light')),
                      ],
                    ),
                    subtitle: Text(tr('settings_screen.theme.light_desc')),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        const Icon(Icons.dark_mode, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(tr('settings_screen.theme.dark')),
                      ],
                    ),
                    subtitle: Text(tr('settings_screen.theme.dark_desc')),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard(ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tr('settings_screen.font.title'),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Font Family
            Text(
              tr('settings_screen.font.family'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: themeProvider.fontFamily,
              onChanged: _onFontFamilyChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
            const SizedBox(height: AppSpacing.lg),

            // Font Size
            Text(
              tr('settings_screen.font.size'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  tr('settings_screen.font.small'),
                  style: theme.textTheme.bodySmall,
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
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Preview
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.darkCard
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tr('settings_screen.language.title'),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: themeProvider.languageCode,
              onChanged: _onLanguageChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                      const SizedBox(width: AppSpacing.sm),
                      Text(tr('settings_screen.language.system')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'sk',
                  child: Row(
                    children: [
                      Text('🇸🇰', style: theme.textTheme.titleLarge),
                      const SizedBox(width: AppSpacing.sm),
                      Text(tr('settings_screen.language.slovak')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      Text('🇺🇸', style: theme.textTheme.titleLarge),
                      const SizedBox(width: AppSpacing.sm),
                      Text(tr('settings_screen.language.english')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'es',
                  child: Row(
                    children: [
                      Text('🇪🇸', style: theme.textTheme.titleLarge),
                      const SizedBox(width: AppSpacing.sm),
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

  /// Vytvorí dropdown items pre biblické preklady podľa jazyka
  List<DropdownMenuItem<String>> _buildBibleDropdownItems(String locale) {
    final availableBibles = _getAvailableBiblesForLocale(locale);

    final allItems = [
      DropdownMenuItem(
        value: 'biblia_1',
        child: Text(
          tr('bible_1'),
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DropdownMenuItem(
        value: 'biblia_2',
        child: Text(
          tr('bible_2'),
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DropdownMenuItem(
        value: 'biblia_3',
        child: Text(
          tr('bible_3'),
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    // Vráť len položky dostupné pre daný jazyk
    return allItems
        .where((item) => availableBibles.contains(item.value))
        .toList();
  }

  Widget _buildAboutAndPrivacyCard() {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tr('privacy.info_section'),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.primary),
              title: Text(tr('about_title')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
              ),
              title: Text(tr('privacy.page_title')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBibleCard() {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final availableBibles = _getAvailableBiblesForLocale(locale);
    final hasMultipleOptions = availableBibles.length > 1;
    final isDisabled = availableBibles.length == 1;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.high,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    tr('select_bible'),
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Badge pre jazyky s len jednou dostupnou bibliou
            if (isDisabled) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    tr('temporarily_disabled'),
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _isLoadingBible
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    initialValue: _selectedBible,
                    onChanged: hasMultipleOptions ? _onBibleChanged : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    items: _buildBibleDropdownItems(locale),
                  ),
            if (isDisabled) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('bible_selection_info'),
                style: theme.textTheme.bodySmall!.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

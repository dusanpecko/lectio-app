import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lectio_divina/providers/theme_provider.dart';
import 'package:lectio_divina/screens/about_screen.dart';
import 'package:lectio_divina/screens/auth_screen.dart';
import 'package:lectio_divina/screens/notification_settings_screen.dart';
import 'package:lectio_divina/screens/privacy_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBible = 'biblia_1';
  bool _isLoadingBible = true; // Začneme s loading stavom
  String? _lastLocale; // Sledovanie posledného jazyka
  bool _keepScreenOn = true; // Nezhasínať obrazovku počas Lectio

  /// Režim prehrávania Lectio audia: 'long' (celé s hudbou, default),
  /// 'short' (celé bez hudby) alebo 'steps' (po krokoch).
  String _lectioAudioMode = 'long';

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale.languageCode;

    if (_lastLocale != null && _lastLocale != currentLocale) {
      _handleLanguageChange(currentLocale);
    }
    _lastLocale = currentLocale;
  }

  /// Ošetrí zmenu jazyka - nastaví predvolenú bibliu pre daný jazyk
  Future<void> _handleLanguageChange(String newLocale) async {
    final availableBibles = _getAvailableBiblesForLocale(newLocale);
    final defaultBible = availableBibles.first;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', defaultBible);

    if (mounted) {
      _selectedBible = defaultBible;
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

    String bible = prefs.getString('selectedBible') ?? 'biblia_1';
    bible = _migrateBibleValue(bible);

    final currentLocale = context.locale.languageCode;
    final availableBibles = _getAvailableBiblesForLocale(currentLocale);
    if (!availableBibles.contains(bible)) {
      bible = availableBibles.first;
    }

    await prefs.setString('selectedBible', bible);

    final keepOn = prefs.getBool('keep_screen_on') ?? true;
    final savedAudioMode = prefs.getString('lectio_audio_mode');
    final audioMode = savedAudioMode == 'short' ? 'short' : 'long';

    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _keepScreenOn = keepOn;
      _lectioAudioMode = audioMode;
      _isLoadingBible = false;
    });
  }

  Future<void> _onLectioAudioModeChanged(String? mode) async {
    if (mode == null) return;
    setState(() => _lectioAudioMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lectio_audio_mode', mode);
  }

  Future<void> _setKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keep_screen_on', value);
  }

  // Migruje starú hodnotu na nový formát (biblia_1, biblia_2, biblia_3)
  String _migrateBibleValue(String oldValue) {
    if (oldValue == 'biblia_1' ||
        oldValue == 'biblia_2' ||
        oldValue == 'biblia_3') {
      return oldValue;
    }

    switch (oldValue.toLowerCase()) {
      case 'biblia1':
      case 'bible_en_1':
        return 'biblia_1';
      case 'biblia2':
      case 'bible_en_2':
        return 'biblia_2';
      case 'biblia3':
      case 'bible_en_3':
        return 'biblia_3';
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
    // Po zmene jazyka sa domovská obrazovka prestaví v novom jazyku (SessionHandler
    // je závislý od locale a kľúčuje Home). Vrátime sa na ňu a zahodíme prípadné
    // staršie pushnuté obrazovky, ktoré by inak ostali v starom jazyku.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context)
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                ),
                children: [
                  _buildUserInfoCard(context, userEmail),
                  const SizedBox(height: AppSpacing.md),
                  _buildNotificationsCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildBibleCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildLectioAudioCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildLanguageCard(themeProvider),
                  const SizedBox(height: AppSpacing.md),
                  _buildFontCard(themeProvider),
                  const SizedBox(height: AppSpacing.md),
                  _buildThemeCard(themeProvider),
                  const SizedBox(height: AppSpacing.md),
                  _buildKeepAwakeCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildAboutAndPrivacyCard(),
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
            HomeV2.primary.withValues(
              alpha: HomeV2.isDark(context) ? 0.32 : 0.14,
            ),
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
            tr('settings'),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Spoločné prvky ──────────────────────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HomeV2.iconAccent(context)),
        const SizedBox(width: AppSpacing.sm),
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
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      filled: true,
      fillColor: HomeV2.isDark(context)
          ? Colors.white.withValues(alpha: 0.04)
          : HomeV2.primary.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      focusedBorder: border(HomeV2.primary, 1.5),
    );
  }

  // ── Profil / Prihlásenie ────────────────────────────────────────────────────
  Widget _buildUserInfoCard(BuildContext context, String email) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (!isLoggedIn) {
      return _card(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.login_rounded,
                size: 32,
                color: HomeV2.iconAccent(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('not_logged_in'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: HomeV2.textDark(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('login_to_sync'),
              style: TextStyle(fontSize: 14, color: HomeV2.textMuted(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  tr('sign_in'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_rounded, color: HomeV2.iconAccent(context)),
        ),
        title: Text(
          tr('user'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
        subtitle: Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: HomeV2.textMuted(context)),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: HomeV2.textMuted(context),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
    );
  }

  // ── Téma ────────────────────────────────────────────────────────────────────
  Widget _buildThemeCard(ThemeProvider themeProvider) {
    Widget tile(IconData icon, String title, String desc, ThemeMode value) {
      return RadioListTile<ThemeMode>(
        contentPadding: EdgeInsets.zero,
        activeColor: HomeV2.primary,
        title: Row(
          children: [
            Icon(icon, size: 20, color: HomeV2.textMuted(context)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: HomeV2.textDark(context),
              ),
            ),
          ],
        ),
        subtitle: Text(
          desc,
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 12.5),
        ),
        value: value,
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.brightness_6_rounded,
            tr('settings_screen.theme.title'),
          ),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<ThemeMode>(
            groupValue: themeProvider.themeMode,
            onChanged: (value) => _onThemeModeChanged(value),
            child: Column(
              children: [
                tile(
                  Icons.phone_android_rounded,
                  tr('settings_screen.theme.system'),
                  tr('settings_screen.theme.system_desc'),
                  ThemeMode.system,
                ),
                tile(
                  Icons.light_mode_rounded,
                  tr('settings_screen.theme.light'),
                  tr('settings_screen.theme.light_desc'),
                  ThemeMode.light,
                ),
                tile(
                  Icons.dark_mode_rounded,
                  tr('settings_screen.theme.dark'),
                  tr('settings_screen.theme.dark_desc'),
                  ThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lectio audio ─────────────────────────────────────────────────────────
  Widget _buildLectioAudioCard() {
    Widget tile(IconData icon, String title, String desc, String value) {
      return RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        activeColor: HomeV2.primary,
        title: Row(
          children: [
            Icon(icon, size: 20, color: HomeV2.textMuted(context)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: HomeV2.textDark(context),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          desc,
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 12.5),
        ),
        value: value,
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.headphones_rounded,
            tr('settings_screen.lectio_audio.title'),
          ),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<String>(
            groupValue: _lectioAudioMode,
            onChanged: (value) => _onLectioAudioModeChanged(value),
            child: Column(
              children: [
                tile(
                  Icons.music_note_rounded,
                  tr('settings_screen.lectio_audio.long'),
                  tr('settings_screen.lectio_audio.long_desc'),
                  'long',
                ),
                tile(
                  Icons.graphic_eq_rounded,
                  tr('settings_screen.lectio_audio.short'),
                  tr('settings_screen.lectio_audio.short_desc'),
                  'short',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Písmo ─────────────────────────────────────────────────────────────────
  Widget _buildFontCard(ThemeProvider themeProvider) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.text_fields_rounded,
            tr('settings_screen.font.title'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('settings_screen.font.family'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: HomeV2.textDark(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: themeProvider.fontFamily,
            onChanged: _onFontFamilyChanged,
            decoration: _dropdownDecoration(),
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
          Text(
            tr('settings_screen.font.size'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: HomeV2.textDark(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                tr('settings_screen.font.small'),
                style: TextStyle(
                  fontSize: 13,
                  color: HomeV2.textMuted(context),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: HomeV2.primary,
                    inactiveTrackColor: HomeV2.primary.withValues(alpha: 0.18),
                    thumbColor: HomeV2.primary,
                  ),
                  child: Slider(
                    value: themeProvider.fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: themeProvider.fontSize.round().toString(),
                    onChanged: _onFontSizeChanged,
                  ),
                ),
              ),
              Text(
                tr('settings_screen.font.large'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              border: Border.all(color: HomeV2.primary.withValues(alpha: 0.12)),
            ),
            // Náhľad ukazuje presne zvolenú veľkosť (fontSize), preto vypneme
            // globálne textScaler škálovanie, nech sa veľkosť nezdvojnásobí.
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: Text(
                tr('settings_screen.font.preview'),
                style: _getPreviewTextStyle(
                  themeProvider,
                ).copyWith(color: HomeV2.textDark(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Jazyk ─────────────────────────────────────────────────────────────────
  Widget _buildLanguageCard(ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.language_rounded,
            tr('settings_screen.language.title'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: themeProvider.languageCode,
            onChanged: _onLanguageChanged,
            decoration: _dropdownDecoration(),
            items: [
              DropdownMenuItem(
                value: 'system',
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 20,
                      color: HomeV2.textMuted(context),
                    ),
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
              DropdownMenuItem(
                value: 'fr',
                child: Row(
                  children: [
                    Text('🇫🇷', style: theme.textTheme.titleLarge),
                    const SizedBox(width: AppSpacing.sm),
                    Text(tr('settings_screen.language.french')),
                  ],
                ),
              ),
            ],
          ),
        ],
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

    return allItems
        .where((item) => availableBibles.contains(item.value))
        .toList();
  }

  // ── Nezhasínať obrazovku ────────────────────────────────────────────────────
  // ── Notifikácie ───────────────────────────────────────────────────────────
  Widget _buildNotificationsCard() {
    return _card(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.notifications_rounded,
          color: HomeV2.iconAccent(context),
        ),
        title: Text(
          tr('profile.button.notification_settings'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
        subtitle: Text(
          tr('notifications.settings_subtitle'),
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 12.5),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: HomeV2.textMuted(context),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeepAwakeCard() {
    return _card(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        secondary: Icon(
          Icons.brightness_high_rounded,
          color: HomeV2.iconAccent(context),
        ),
        title: Text(
          tr('keep_screen_on_title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
        subtitle: Text(
          tr('keep_screen_on_desc'),
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 12.5),
        ),
        value: _keepScreenOn,
        activeThumbColor: Colors.white,
        activeTrackColor: HomeV2.primary,
        onChanged: _setKeepScreenOn,
      ),
    );
  }

  // ── O aplikácii a Súkromie ────────────────────────────────────────────────
  Widget _buildAboutAndPrivacyCard() {
    Widget row(IconData icon, String title, VoidCallback onTap) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: HomeV2.iconAccent(context)),
        title: Text(title, style: TextStyle(color: HomeV2.textDark(context))),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: HomeV2.textMuted(context),
        ),
        onTap: onTap,
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.info_outline_rounded,
            tr('privacy.info_section'),
          ),
          const SizedBox(height: AppSpacing.xs),
          row(Icons.info_outline_rounded, tr('about_title'), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          }),
          Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.08)),
          row(Icons.privacy_tip_outlined, tr('privacy.page_title'), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            );
          }),
          Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.08)),
          row(Icons.description_outlined, tr('shop.terms_title'), () {
            final locale = context.locale.languageCode;
            launchUrl(
              Uri.parse('https://www.lectio.one/$locale/terms'),
              mode: LaunchMode.externalApplication,
            );
          }),
        ],
      ),
    );
  }

  // ── Výber Biblie ────────────────────────────────────────────────────────────
  Widget _buildBibleCard() {
    final locale = context.locale.languageCode;
    final availableBibles = _getAvailableBiblesForLocale(locale);
    final hasMultipleOptions = availableBibles.length > 1;
    final isDisabled = availableBibles.length == 1;

    // Hodnota MUSÍ byť medzi položkami, inak Flutter vyhodí assertion
    // („There should be exactly one item with [DropdownButton]'s value").
    //
    // Pri zmene jazyka sa to stávalo: `build` prebehne hneď s novým jazykom
    // (napr. EN → ponuka len `biblia_2`), ale `_selectedBible` je ešte stará
    // hodnota z predošlého jazyka (`biblia_1`) — prestaví ju až asynchrónne
    // `_handleLanguageChange` z `didChangeDependencies`. V tej medzere svietila
    // pol sekundy červená obrazovka. Preto sa hodnota odvodí tu, pri kreslení,
    // a na časovaní už nezáleží.
    final bibleValue = availableBibles.contains(_selectedBible)
        ? _selectedBible
        : availableBibles.first;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.menu_book_rounded, tr('select_bible')),
          if (isDisabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HomeV2.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  tr('temporarily_disabled'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB8862F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _isLoadingBible
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                  initialValue: bibleValue,
                  onChanged: hasMultipleOptions ? _onBibleChanged : null,
                  isExpanded: true,
                  decoration: _dropdownDecoration(),
                  items: _buildBibleDropdownItems(locale),
                ),
          if (isDisabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('bible_selection_info'),
              style: TextStyle(
                fontSize: 12.5,
                color: HomeV2.textMuted(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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

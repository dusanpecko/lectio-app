import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import '../models/confession_mirror.dart';
import '../services/confession_vault_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/collapsible_hero_app_bar.dart';
import '../widgets/confession_privacy_sheet.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

const List<String> _kCanonicalLangs = ['sk', 'cs', 'en', 'es', 'fr', 'pt-br'];

/// Spovedné zrkadlo — obsah + šifrované odpovede (SPOVEDNÉ TAJOMSTVO).
///
/// · Otvára sa výhradne cez [ConfessionGateScreen] (PIN/biometria).
/// · Odpovede (zaškrtnutia + poznámky per sekcia) sa priebežne šifrovane
///   ukladajú cez [ConfessionVaultService]; kľúč = id jazykovej verzie.
/// · Pri odchode appky do pozadia sa trezor zamkne a obrazovka zavrie.
/// · ŽIADNA analytika na tejto obrazovke.
class ConfessionScreen extends StatefulWidget {
  const ConfessionScreen({super.key, required this.mirrors});

  /// Všetky aktívne zrkadlá (všetky jazyky aj varianty).
  final List<ConfessionMirror> mirrors;

  @override
  State<ConfessionScreen> createState() => _ConfessionScreenState();
}

class _ConfessionScreenState extends State<ConfessionScreen>
    with WidgetsBindingObserver {
  final _vault = ConfessionVaultService.instance;

  /// Jazykové verzie aktuálne zvoleného zrkadla (aktuálny jazyk prvý).
  late List<ConfessionMirror> _variants;
  int _variantIndex = 0;

  /// Ostatné zrkadlá (iné base kódy) — výber, ak ich je viac.
  late Map<String, List<ConfessionMirror>> _byBase;

  int _slideIndex = 0;
  late PageController _pageController;

  /// Odpovede aktuálnej jazykovej verzie.
  Set<String> _checked = {};
  Map<String, String> _notes = {};
  final Map<String, TextEditingController> _noteCtrls = {};
  Timer? _notesSaveDebounce;

  bool _loadingAnswers = true;

  /// Prekrytie obsahu hneď pri `inactive` (prepínač aplikácií / snapshot
  /// systému) — inak iOS na 1–2 s ukázal spovedný obsah pri návrate,
  /// kým prebehol pop na home.
  bool _obscured = false;

  /// Zvolené zrkadlo (base kód). `null` = zobrazuje sa výber (ak ich je viac).
  String? _selectedBase;

  ConfessionMirror get _mirror => _variants[_variantIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    final locale = 'sk'; // prepíše sa v didChangeDependencies (context.locale)
    _byBase = {};
    for (final m in widget.mirrors) {
      _byBase.putIfAbsent(m.baseCode, () => []).add(m);
    }
    // Jedno zrkadlo → rovno dnu; viac → najprv výber.
    if (_byBase.length == 1) _selectedBase = _byBase.keys.first;
    _variants = _orderVariants(_byBase.values.first, locale);
    if (_selectedBase != null) {
      _loadAnswers();
    } else {
      _loadingAnswers = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preusporiadaj varianty podľa jazyka appky (raz — pri prvom builde).
    final locale = context.locale.languageCode;
    final ordered = _orderVariants(_byBase[_mirror.baseCode]!, locale);
    if (ordered.first.id != _variants.first.id) {
      setState(() {
        _variants = ordered;
        _variantIndex = 0;
      });
      if (_selectedBase != null) _loadAnswers();
    }
  }

  /// Výber zrkadla (pri viacerých) / návrat na výber.
  Future<void> _selectBase(String base) async {
    final locale = context.locale.languageCode;
    setState(() {
      _selectedBase = base;
      _variants = _orderVariants(_byBase[base]!, locale);
      _variantIndex = 0;
      _slideIndex = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    await _loadAnswers();
  }

  Future<void> _backToPicker() async {
    await _saveAnswersNow();
    setState(() => _selectedBase = null);
  }

  static List<ConfessionMirror> _orderVariants(
    List<ConfessionMirror> variants,
    String locale,
  ) {
    final order = <String>[
      locale,
      ..._kCanonicalLangs.where((l) => l != locale),
    ];
    int rank(String lang) {
      final i = order.indexOf(lang);
      return i < 0 ? 999 : i;
    }

    final list = [...variants]
      ..sort((a, b) => rank(a.lang).compareTo(rank(b.lang)));
    return list;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesSaveDebounce?.cancel();
    for (final c in _noteCtrls.values) {
      c.dispose();
    }
    _pageController.dispose();
    // Zamkni a vypni ochranu obrazovky pri odchode.
    _vault.lock();
    ConfessionVaultService.setSecureScreen(false);
    super.dispose();
  }

  /// Odchod appky do pozadia → ulož, zamkni a zavri obrazovku (pri návrate
  /// sa vstupuje znova cez PIN bránu).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive && mounted) {
      // Prekry obsah SKÔR, než si systém spraví snapshot okna.
      setState(() => _obscured = true);
    } else if (state == AppLifecycleState.paused && _vault.isUnlocked) {
      _saveAnswersNow();
      _vault.lock();
      if (mounted) Navigator.of(context).pop();
    } else if (state == AppLifecycleState.resumed && mounted) {
      // Len prechodné inactive (ovládacie centrum, hovor…) — odkry.
      setState(() => _obscured = false);
    }
  }

  // ── Odpovede ────────────────────────────────────────────────────────────────

  Future<void> _loadAnswers() async {
    if (!_vault.isUnlocked) return;
    setState(() => _loadingAnswers = true);
    final data = await _vault.loadData();
    final entry = data[_mirror.id] as Map<String, dynamic>?;
    if (!mounted) return;
    setState(() {
      _checked = ((entry?['checked'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet();
      _notes = ((entry?['notes'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      // Zosynchronizuj controllery poznámok
      for (final s in _mirror.sections) {
        _noteCtrls
            .putIfAbsent(s.id, () => TextEditingController())
            .text = _notes[s.id] ?? '';
      }
      _loadingAnswers = false;
    });
  }

  Future<void> _saveAnswersNow() async {
    if (!_vault.isUnlocked) return;
    final data = await _vault.loadData();
    data[_mirror.id] = {
      'checked': _checked.toList()..sort(),
      'notes': _notes,
    };
    await _vault.saveData(data);
  }

  void _toggleQuestion(String questionId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_checked.remove(questionId)) _checked.add(questionId);
    });
    _saveAnswersNow();
  }

  void _onNoteChanged(String sectionId, String text) {
    _notes[sectionId] = text;
    _notesSaveDebounce?.cancel();
    _notesSaveDebounce = Timer(
      const Duration(milliseconds: 700),
      _saveAnswersNow,
    );
  }

  Future<void> _resetPreparation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confession.reset_title'.tr()),
        content: Text('confession.reset_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HomeV2.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confession.reset_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !_vault.isUnlocked) return;

    // Zmaž odpovede tejto jazykovej verzie (PIN aj ostatné zrkadlá ostávajú).
    final data = await _vault.loadData();
    data.remove(_mirror.id);
    await _vault.saveData(data);
    if (!mounted) return;
    setState(() {
      _checked = {};
      _notes = {};
      for (final c in _noteCtrls.values) {
        c.clear();
      }
      _slideIndex = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    // Pastoračný moment — popup namiesto snackbaru.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕊️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'confession.reset_done'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: HomeV2.textDark(ctx),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'confession.reset_done_button'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomeV2.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sprievodca spoveďou (bottom sheet) ─────────────────────────────────────

  void _openGuide() {
    final m = _mirror;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeV2.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewPadding.bottom + AppSpacing.xxl,
          ),
          children: [
            Text(
              'confession.guide_title'.tr(),
              style: HomeV2.serifTitle(ctx, size: 22, height: 1.2),
            ),
            if (m.guideConfessionFlow != null)
              _guideBlock(ctx, 'confession.guide_flow'.tr(), m.guideConfessionFlow!),
            if (m.guideInvocation != null)
              _guideBlock(ctx, 'confession.guide_invocation'.tr(), m.guideInvocation!),
            if (m.guideContrition != null)
              _guideBlock(ctx, 'confession.guide_contrition'.tr(), m.guideContrition!),
          ],
        ),
      ),
    );
  }

  Widget _guideBlock(BuildContext ctx, String title, String html) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: HomeV2.gold,
            ),
          ),
          Html(
            data: html,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(16),
                lineHeight: const LineHeight(1.65),
                color: HomeV2.textDark(ctx),
              ),
            },
          ),
        ],
      ),
    );
  }

  // ── Slidy ───────────────────────────────────────────────────────────────────

  int get _slideCount => 1 + _mirror.sections.length + 1;

  String _slideLabel(int i) {
    if (i == 0) return 'confession.slide_intro'.tr();
    if (i == _slideCount - 1) return 'confession.slide_closing'.tr();
    return _mirror.sections[i - 1].title;
  }

  @override
  Widget build(BuildContext context) {
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
        body: Stack(
          children: [
            _selectedBase == null
                ? _buildPickerView()
                : _loadingAnswers
                ? const Center(
                    child: CircularProgressIndicator(color: HomeV2.primary),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slideCount,
                          onPageChanged: (i) => setState(() => _slideIndex = i),
                          itemBuilder: (_, i) => CustomScrollView(
                            slivers: [
                              _heroSliver(),
                              SliverToBoxAdapter(child: _buildSlideBody(i)),
                            ],
                          ),
                        ),
                      ),
                      _buildSlideNav(),
                    ],
                  ),
            // Súkromný cover — nič zo spovede nesmie byť v systémovom snapshote.
            if (_obscured)
              Positioned.fill(
                child: ColoredBox(
                  color: HomeV2.background(context),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      size: 56,
                      color: HomeV2.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Výber spovedného zrkadla (ak ich admin vytvoril viac — dospelí, deti…).
  Widget _buildPickerView() {
    final locale = context.locale.languageCode;
    final entries = _byBase.entries.toList()
      ..sort((a, b) {
        final pa = _orderVariants(a.value, locale).first;
        final pb = _orderVariants(b.value, locale).first;
        return pa.displayOrder.compareTo(pb.displayOrder);
      });
    return CustomScrollView(
      slivers: [
        CollapsibleHeroAppBar(
          collapsedTitle: 'confession.title'.tr(),
          expandedContent: HeroCenteredContent(
            title: 'confession.title'.tr(),
            subtitle: 'confession.subtitle'.tr(),
            icon: Icons.favorite_border_rounded,
          ),
          actions: [
            IconButton(
              onPressed: () => showConfessionPrivacySheet(context),
              icon: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (final e in entries)
                  _mirrorCard(_orderVariants(e.value, locale).first),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mirrorCard(ConfessionMirror m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            HapticFeedback.lightImpact();
            _selectBase(m.baseCode);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeV2.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: HomeV2.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                      if (m.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroSliver() {
    return CollapsibleHeroAppBar(
      collapsedTitle: _mirror.title,
      imageUrl: _mirror.imageUrl,
      expandedContent: HeroCenteredContent(
        title: _mirror.title,
        subtitle: 'confession.subtitle'.tr(),
        icon: _mirror.imageUrl == null ? Icons.favorite_border_rounded : null,
      ),
      actions: [
        if (_byBase.length > 1)
          IconButton(
            onPressed: _backToPicker,
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
          ),
        IconButton(
          onPressed: () => showConfessionPrivacySheet(context),
          icon: const Icon(Icons.shield_rounded, color: Colors.white),
        ),
        if (_mirror.hasGuide)
          IconButton(
            onPressed: _openGuide,
            icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.lock_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSlideBody(int index) {
    final base = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _langChips(),
          if (index == 0) ..._introChildren(),
          if (index > 0 && index < _slideCount - 1)
            ..._sectionChildren(_mirror.sections[index - 1]),
          if (index == _slideCount - 1) ..._closingChildren(),
        ],
      ),
    );
    return base;
  }

  List<Widget> _introChildren() {
    final m = _mirror;
    return [
      if (m.introText != null) _html(m.introText!),
      if (m.introPrayer != null) ...[
        const SizedBox(height: AppSpacing.lg),
        _prayerCard('confession.intro_prayer'.tr(), m.introPrayer!),
      ],
      const SizedBox(height: AppSpacing.lg),
      // Appka nenahrádza sviatosť — dôležité mať na očiach od začiatku.
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: HomeV2.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: HomeV2.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: HomeV2.gold),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'confession.disclaimer'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: HomeV2.textDark(context),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _sectionChildren(ConfessionSection s) {
    return [
      Text(
        s.title,
        style: HomeV2.serifTitle(context, size: 20, height: 1.2),
      ),
      const SizedBox(height: AppSpacing.md),
      for (final q in s.questions)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _toggleQuestion(q.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      _checked.contains(q.id)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: _checked.contains(q.id)
                          ? HomeV2.primary
                          : HomeV2.textMuted(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      q.text,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.5,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      // Poznámka per sekcia (šifrovaná)
      Text(
        'confession.notes_label'.tr(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: HomeV2.gold,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _noteCtrls.putIfAbsent(s.id, () => TextEditingController()),
        onChanged: (v) => _onNoteChanged(s.id, v),
        maxLines: 4,
        minLines: 2,
        style: const TextStyle(fontSize: 15, height: 1.5),
        decoration: InputDecoration(
          hintText: 'confession.notes_hint'.tr(),
          filled: true,
          fillColor: HomeV2.card(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ];
  }

  List<Widget> _closingChildren() {
    final m = _mirror;
    return [
      if (m.closingPrayer != null)
        _prayerCard('confession.closing_prayer'.tr(), m.closingPrayer!),
      const SizedBox(height: AppSpacing.xl),
      if (m.hasGuide)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeV2.primary,
              side: const BorderSide(color: HomeV2.primary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: _openGuide,
            icon: const Icon(Icons.menu_book_rounded),
            label: Text('confession.guide_button'.tr()),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: HomeV2.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          onPressed: _resetPreparation,
          icon: const Icon(Icons.church_rounded),
          label: Text(
            'confession.reset_button'.tr(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'confession.reset_hint'.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
      ),
    ];
  }

  Widget _html(String html) => Html(
    data: html,
    style: {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(16.5),
        lineHeight: const LineHeight(1.65),
        color: HomeV2.textDark(context),
      ),
    },
  );

  Widget _prayerCard(String title, String html) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: HomeV2.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: HomeV2.gold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _html(html),
        ],
      ),
    );
  }

  Widget _langChips() {
    if (_variants.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _variants.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) {
            final active = i == _variantIndex;
            return GestureDetector(
              onTap: () async {
                await _saveAnswersNow();
                setState(() {
                  _variantIndex = i;
                  _slideIndex = 0;
                });
                if (_pageController.hasClients) _pageController.jumpToPage(0);
                _loadAnswers();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active ? HomeV2.primary : HomeV2.card(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _variants[i].langBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : HomeV2.textMuted(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlideNav() {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: HomeV2.primary,
                disabledColor: HomeV2.textMuted(context).withValues(alpha: 0.3),
                tooltip: 'a11y_previous_section'.tr(),
                onPressed: _slideIndex > 0
                    ? () => _pageController.animateToPage(
                        _slideIndex - 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  _slideLabel(_slideIndex.clamp(0, _slideCount - 1)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: HomeV2.primary,
                disabledColor: HomeV2.textMuted(context).withValues(alpha: 0.3),
                tooltip: 'a11y_next_section'.tr(),
                onPressed: _slideIndex < _slideCount - 1
                    ? () => _pageController.animateToPage(
                        _slideIndex + 1,
                        duration: HomeV2.anim,
                        curve: HomeV2.curve,
                      )
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slideCount, (i) {
              final active = i == _slideIndex;
              return AnimatedContainer(
                duration: HomeV2.anim,
                curve: HomeV2.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? HomeV2.primary
                      : HomeV2.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

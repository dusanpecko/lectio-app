import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/inbox_admin_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import 'inbox_admin_ui.dart';

/// Admin editor jednej inbox popup správy (Fáza 2). Dizajn v2.
/// `messageId == null` → nová správa.
class InboxAdminEditorScreen extends StatefulWidget {
  final String? messageId;
  const InboxAdminEditorScreen({super.key, this.messageId});

  @override
  State<InboxAdminEditorScreen> createState() => _InboxAdminEditorScreenState();
}

class _InboxAdminEditorScreenState extends State<InboxAdminEditorScreen> {
  final _service = InboxAdminService.instance;

  InboxAdminMessage _msg = InboxAdminMessage.empty();
  String _lang = 'sk';
  bool _loading = false;
  bool _saving = false;
  bool _uploading = false;

  /// Id získané po prvom uložení novej správy (aby ďalšie uloženia robili
  /// PATCH a nevytvárali duplikáty).
  String? _savedId;

  /// Bola vykonaná aspoň jedna úspešná zmena (signál pre obnovu zoznamu).
  bool _changed = false;

  bool get _isNew => widget.messageId == null && _savedId == null;
  String? get _effectiveId => widget.messageId ?? _savedId;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final m = await _service.getById(widget.messageId!);
      setState(() {
        _msg = m;
        _lang = m.defaultLang;
      });
    } catch (e) {
      _snack('Načítanie zlyhalo: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Obsah pre aktívny jazyk (vytvorí prázdny ak neexistuje).
  InboxLangContent get _lc =>
      _msg.content.putIfAbsent(_lang, () => InboxLangContent());

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _service.uploadImage(bytes);
      setState(() => _lc.imageUrl = url);
    } catch (e) {
      _snack('Nahranie obrázka zlyhalo: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate(bool from) async {
    final current = from ? _msg.activeFrom : _msg.activeUntil;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (ctx, child) => HomeV2.datePickerTheme(ctx, child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
      builder: (ctx, child) => HomeV2.datePickerTheme(ctx, child!),
    );
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    setState(() {
      if (from) {
        _msg.activeFrom = dt;
      } else {
        _msg.activeUntil = dt;
      }
    });
  }

  Future<void> _save() async {
    final hasContent = _msg.content.values.any((c) => !c.isEmpty);
    if (!hasContent) {
      _snack('Vyplň aspoň nadpis alebo text v jednom jazyku.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = _effectiveId == null
          ? await _service.create(_msg)
          : await _service.update(_effectiveId!, _msg);
      if (mounted) {
        _savedId = result.id; // nová správa → prepni do update režimu
        _changed = true;
        _snack('Uložené.');
      }
    } catch (e) {
      _snack('Uloženie zlyhalo: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
          bottomNavigationBar: _saveBar(),
          body: Column(
            children: [
              InboxHero(
                title: _isNew ? 'Nová správa' : 'Upraviť správu',
                subtitle: 'In-app popup správa',
                onBack: () => Navigator.of(context).pop(_changed),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        children: [
                          _previewCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _contentCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _deliveryCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _targetingCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _scheduleCard(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sticky save bar ────────────────────────────────────────────────────────
  Widget _saveBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: HomeV2.primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _isNew ? 'Vytvoriť správu' : 'Uložiť zmeny',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }

  // ── Náhľad ───────────────────────────────────────────────────────────────
  Widget _previewCard() {
    final c = _msg.content[_lang];
    final img = c?.imageUrl;
    final title = (c?.title ?? '').trim();
    final body = (c?.body ?? '').trim();
    final buttons = (c?.buttons ?? [])
        .where((b) => b.label.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InboxFieldLabel('Náhľad (${_lang.toUpperCase()})'),
        Container(
          decoration: BoxDecoration(
            color: HomeV2.card(context),
            borderRadius: BorderRadius.circular(HomeV2.radius),
            boxShadow: HomeV2.softShadow(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (img != null && img.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(img, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Nadpis správy' : title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: title.isEmpty
                            ? HomeV2.textMuted(context)
                            : HomeV2.iconAccent(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.isEmpty ? 'Text správy sa zobrazí tu.' : body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...(buttons.isEmpty
                            ? [InboxBtn(label: 'Zavrieť')]
                            : buttons)
                        .map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: HomeV2.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                b.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Obsah ──────────────────────────────────────────────────────────────────
  Widget _contentCard() {
    return InboxSectionCard(
      icon: Icons.edit_note_rounded,
      title: 'Obsah',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _langSelector(),
          const SizedBox(height: AppSpacing.lg),
          _imageField(),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: ValueKey('$_lang-title'),
            initialValue: _lc.title,
            onChanged: (v) => _lc.title = v,
            decoration: inboxInput(context, label: 'Nadpis'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: ValueKey('$_lang-body'),
            initialValue: _lc.body,
            onChanged: (v) => _lc.body = v,
            maxLines: 4,
            decoration: inboxInput(context, label: 'Text'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buttonsEditor(),
        ],
      ),
    );
  }

  Widget _langSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kInboxLangs.map((l) {
          final filled = !(_msg.content[l]?.isEmpty ?? true);
          final active = l == _lang;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(l.toUpperCase() + (filled ? ' ●' : '')),
              selected: active,
              onSelected: (_) => setState(() => _lang = l),
              selectedColor: HomeV2.primary,
              backgroundColor: HomeV2.isDark(context)
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF5F2FF),
              labelStyle: TextStyle(
                color: active ? Colors.white : HomeV2.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _imageField() {
    final url = _lc.imageUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InboxFieldLabel('Obrázok (voliteľný)'),
        if (_uploading)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (url != null && url.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(url, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => _lc.imageUrl = null),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: HomeV2.isDark(context)
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF5F2FF),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                border: Border.all(
                  color: HomeV2.primary.withValues(alpha: 0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: HomeV2.iconAccent(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pridať obrázok',
                    style: TextStyle(color: HomeV2.textMuted(context)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buttonsEditor() {
    final buttons = _lc.buttons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: InboxFieldLabel('Tlačidlá')),
            TextButton.icon(
              onPressed: () => setState(() => buttons.add(InboxBtn())),
              icon: Icon(Icons.add, size: 18, color: HomeV2.primary),
              label: Text(
                'Pridať',
                style: TextStyle(
                  color: HomeV2.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (buttons.isEmpty)
          Text(
            'Bez tlačidiel — používateľ len zavrie popup.',
            style: TextStyle(color: HomeV2.textMuted(context), fontSize: 13),
          ),
        ...buttons.map((b) {
          return Padding(
            key: ObjectKey(b),
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: const ValueKey('label'),
                    initialValue: b.label,
                    onChanged: (v) => b.label = v,
                    decoration: inboxInput(context, label: 'Text', dense: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: kInboxScreenKeys.containsKey(b.screenKey)
                        ? b.screenKey
                        : '',
                    isExpanded: true,
                    decoration: inboxInput(context, label: 'Cieľ', dense: true),
                    items: kInboxScreenKeys.entries
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.key,
                            child: Text(
                              s.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => b.screenKey = v ?? ''),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () => setState(() => buttons.remove(b)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Doručenie ───────────────────────────────────────────────────────────────
  Widget _deliveryCard() {
    return InboxSectionCard(
      icon: Icons.send_rounded,
      title: 'Doručenie',
      child: Column(
        children: [
          _dropdown(
            label: 'Stav',
            value: _msg.status,
            items: kInboxStatuses,
            labelOf: _statusLabel,
            onChanged: (v) => setState(() => _msg.status = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown(
            label: 'Frekvencia',
            value: _msg.frequency,
            items: kInboxFrequencies,
            labelOf: _frequencyLabel,
            onChanged: (v) => setState(() => _msg.frequency = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown(
            label: 'Predvolený jazyk (fallback)',
            value: _msg.defaultLang,
            items: kInboxLangs,
            labelOf: (l) => l.toUpperCase(),
            onChanged: (v) => setState(() => _msg.defaultLang = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('priority'),
            initialValue: _msg.priority.toString(),
            keyboardType: TextInputType.number,
            onChanged: (v) => _msg.priority = int.tryParse(v) ?? 0,
            decoration: inboxInput(
              context,
              label: 'Priorita (vyššia = prednosť)',
            ),
          ),
        ],
      ),
    );
  }

  // ── Cielenie ────────────────────────────────────────────────────────────────
  Widget _targetingCard() {
    return InboxSectionCard(
      icon: Icons.adjust_rounded,
      title: 'Cielenie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InboxFieldLabel('Platformy (prázdne = všetky)'),
          _multiChips(all: kInboxPlatforms, selected: _msg.platforms),
          const SizedBox(height: AppSpacing.lg),
          _dropdown(
            label: 'Publikum',
            value: _msg.audience,
            items: kInboxAudiences,
            labelOf: _audienceLabel,
            onChanged: (v) => setState(() => _msg.audience = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          InboxFieldLabel('Roly (len prihlásení; prázdne = všetci)'),
          _multiChips(all: kInboxRoles, selected: _msg.roles),
          const SizedBox(height: AppSpacing.lg),
          _dropdown(
            label: 'Darcovia',
            value: _msg.donorSegment,
            items: kInboxDonorSegments,
            labelOf: _donorLabel,
            onChanged: (v) => setState(() => _msg.donorSegment = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          InboxFieldLabel('Predplatné (len prihlásení; prázdne = všetci)'),
          _multiChips(all: kInboxTiers, selected: _msg.subscriptionTiers),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('minv'),
                  initialValue: _msg.minAppVersion,
                  onChanged: (v) => _msg.minAppVersion = v,
                  decoration: inboxInput(
                    context,
                    label: 'Min. verzia',
                    hint: '11.2.0',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('maxv'),
                  initialValue: _msg.maxAppVersion,
                  onChanged: (v) => _msg.maxAppVersion = v,
                  decoration: inboxInput(
                    context,
                    label: 'Max. verzia',
                    hint: '12.0.0',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Plán ────────────────────────────────────────────────────────────────────
  Widget _scheduleCard() {
    return InboxSectionCard(
      icon: Icons.schedule_rounded,
      title: 'Plán (voliteľné)',
      child: Column(
        children: [
          _dateRow(
            'Od',
            _msg.activeFrom,
            () => _pickDate(true),
            () => setState(() => _msg.activeFrom = null),
          ),
          const SizedBox(height: AppSpacing.sm),
          _dateRow(
            'Do',
            _msg.activeUntil,
            () => _pickDate(false),
            () => setState(() => _msg.activeUntil = null),
          ),
        ],
      ),
    );
  }

  // ── Zdieľané polia ──────────────────────────────────────────────────────────
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelOf,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: inboxInput(context, label: label),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(labelOf(i))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _multiChips({
    required List<String> all,
    required List<String> selected,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: all.map((item) {
        final sel = selected.contains(item);
        return FilterChip(
          label: Text(item),
          selected: sel,
          onSelected: (on) => setState(() {
            if (on) {
              selected.add(item);
            } else {
              selected.remove(item);
            }
          }),
          selectedColor: HomeV2.primary.withValues(alpha: 0.15),
          checkmarkColor: HomeV2.primary,
          backgroundColor: HomeV2.isDark(context)
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF5F2FF),
          labelStyle: TextStyle(
            color: sel ? HomeV2.primary : HomeV2.textMuted(context),
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateRow(
    String label,
    DateTime? value,
    VoidCallback onPick,
    VoidCallback onClear,
  ) {
    final text = value == null
        ? 'nenastavené'
        : '${value.day.toString().padLeft(2, '0')}.'
              '${value.month.toString().padLeft(2, '0')}.${value.year} '
              '${value.hour.toString().padLeft(2, '0')}:'
              '${value.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              color: HomeV2.textMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onPick();
            },
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: HomeV2.isDark(context)
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF5F2FF),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 18,
                    color: HomeV2.iconAccent(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(text, style: TextStyle(color: HomeV2.textDark(context))),
                ],
              ),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            color: HomeV2.textMuted(context),
            onPressed: onClear,
          ),
      ],
    );
  }

  // ── Štítky ──────────────────────────────────────────────────────────────────
  String _statusLabel(String s) => switch (s) {
    'active' => 'Aktívna',
    'archived' => 'Archív',
    _ => 'Koncept',
  };

  String _frequencyLabel(String f) => switch (f) {
    'until_dismissed' => 'Kým nezavrie',
    'every_open' => 'Každé otvorenie',
    _ => 'Iba raz',
  };

  String _audienceLabel(String a) => switch (a) {
    'registered' => 'Registrovaní',
    'unregistered' => 'Neregistrovaní',
    _ => 'Všetci',
  };

  String _donorLabel(String d) => switch (d) {
    'one_time' => 'Jednorazoví darcovia',
    'recurring' => 'Pravidelní darcovia',
    'none' => 'Nedarcovia',
    _ => 'Ľubovoľní',
  };
}

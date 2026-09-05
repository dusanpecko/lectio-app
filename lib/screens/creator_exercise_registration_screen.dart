import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../models/creator.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// In-app prihláška na duchovné cvičenie tvorcu — rešpektuje `form_config`
/// (viditeľnosť/povinnosť), spôsoby platby a vlastné podmienky organizátora.
/// Bez Mollie (platba na účet / na mieste). POST /api/dc/[id]/register.
class CreatorExerciseRegistrationScreen extends StatefulWidget {
  const CreatorExerciseRegistrationScreen({super.key, required this.exercise, required this.accent});
  final CreatorExerciseDetail exercise;
  final Color accent;

  @override
  State<CreatorExerciseRegistrationScreen> createState() => _CreatorExerciseRegistrationScreenState();
}

// Poradie konfigurovateľných polí (email/meno/priezvisko sú vždy, mimo configu).
const List<String> _kFields = [
  'phone', 'birth_date', 'id_card_number', 'street', 'city', 'postal_code',
  'parish', 'diocese', 'room_type', 'dietary_restrictions', 'notes',
];

class _CreatorExerciseRegistrationScreenState extends State<CreatorExerciseRegistrationScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final Map<String, String> _values = {}; // konfigurovateľné polia
  late String _method;
  bool _gdpr = false, _resp = false, _news = false;
  bool _busy = false, _done = false, _already = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _method = ex.paymentBank ? 'bank' : (ex.paymentOnsite ? 'onsite' : '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  String _label(String f) {
    switch (f) {
      case 'room_type': return tr('cse_room_type');
      default: return tr(f); // phone/birth_date/id_card_number/street/city/postal_code/parish/diocese/dietary_restrictions/notes
    }
  }

  bool _visible(String f) => (widget.exercise.formConfig[f]?.visible ?? true);
  bool _required(String f) => (widget.exercise.formConfig[f]?.required ?? false);

  Future<void> _submit() async {
    setState(() => _error = null);
    final first = _first.text.trim(), last = _last.text.trim(), email = _email.text.trim();
    if (first.isEmpty || last.isEmpty || !RegExp(r'.+@.+\..+').hasMatch(email)) {
      setState(() => _error = tr('cse_error'));
      return;
    }
    if (_method.isEmpty) { setState(() => _error = tr('cse_error')); return; }
    // Povinné konfigurovateľné polia
    for (final f in _kFields) {
      if (_visible(f) && _required(f) && (_values[f] ?? '').trim().isEmpty) {
        setState(() => _error = '${tr('field_required')}: ${_label(f)}');
        return;
      }
    }
    if (!_gdpr || !_resp) { setState(() => _error = tr('cse_consents_required')); return; }

    setState(() => _busy = true);
    final body = <String, dynamic>{
      'first_name': first, 'last_name': last, 'email': email,
      'website': '', // honeypot
      'payment_method': _method,
      'gdpr_consent': true, 'responsibility_consent': true, 'newsletter_consent': _news,
    };
    for (final f in _kFields) {
      if (_visible(f) && (_values[f] ?? '').trim().isNotEmpty) body[f] = _values[f]!.trim();
    }
    final res = await CreatorsService.instance.registerExercise('${widget.exercise.id}', body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      setState(() {
        _done = true;
        _already = res.already;
      });
      return;
    }
    setState(() {
      _error = res.error == 'full'
          ? tr('cse_full_msg')
          : res.error == 'field_required'
              ? '${tr('field_required')}: ${res.field != null ? _label(res.field!) : ''}'
              : tr('cse_error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      appBar: AppBar(
        backgroundColor: HomeV2.background(context),
        foregroundColor: HomeV2.textDark(context),
        title: Text(tr('cse_registration_title'), style: HomeV2.serifTitle(context, size: 20)),
      ),
      body: _done ? _success(ex) : _form(ex),
    );
  }

  Widget _success(CreatorExerciseDetail ex) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(_already ? Icons.info_rounded : Icons.check_circle_rounded, size: 64, color: widget.accent),
            const SizedBox(height: AppSpacing.lg),
            Text(_already ? tr('cse_already_title') : tr('cse_submitted_title'),
                style: HomeV2.serifTitle(context, size: 22), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
                _already
                    ? tr('cse_already_body', namedArgs: {'name': ex.organizerName})
                    : tr('cse_submitted_body', namedArgs: {'name': ex.organizerName}),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: HomeV2.textMuted(context))),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              child: Text(tr('close')),
            ),
          ]),
        ),
      );

  Widget _form(CreatorExerciseDetail ex) {
    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl),
      children: [
        Row(children: [
          Expanded(child: _text(_first, '${tr('first_name')} *')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _text(_last, '${tr('last_name')} *')),
        ]),
        const SizedBox(height: AppSpacing.md),
        _text(_email, '${tr('email')} *', keyboard: TextInputType.emailAddress),

        // Konfigurovateľné polia
        for (final f in _kFields)
          if (_visible(f)) ...[
            const SizedBox(height: AppSpacing.md),
            _configField(ex, f),
          ],

        const SizedBox(height: AppSpacing.lg),
        // Spôsob platby
        Text('${tr('cse_payment_method')} *', style: TextStyle(fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
        RadioGroup<String>(
          groupValue: _method.isEmpty ? null : _method,
          onChanged: (v) => setState(() => _method = v ?? ''),
          child: Column(children: [
            if (ex.paymentBank)
              RadioListTile<String>(
                value: 'bank', activeColor: widget.accent,
                contentPadding: EdgeInsets.zero, title: Text(tr('cse_pay_bank')),
              ),
            if (ex.paymentOnsite)
              RadioListTile<String>(
                value: 'onsite', activeColor: widget.accent,
                contentPadding: EdgeInsets.zero, title: Text(tr('cse_pay_onsite')),
              ),
          ]),
        ),
        if (_method == 'bank' && ex.bankDetails != null && ex.bankDetails!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: HomeV2.card(context), borderRadius: BorderRadius.circular(HomeV2.radiusSm)),
            child: Text(ex.bankDetails!, style: TextStyle(fontSize: 13, height: 1.5, color: HomeV2.textDark(context))),
          ),

        // Podmienky organizátora
        if (ex.termsText != null && ex.termsText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Html(data: ex.termsText, style: {
            'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero, fontSize: FontSize(13), lineHeight: const LineHeight(1.5), color: HomeV2.textMuted(context)),
          }),
        ],

        const SizedBox(height: AppSpacing.md),
        _consent(_gdpr, tr('cse_consent_gdpr'), (v) => setState(() => _gdpr = v)),
        _consent(_resp, tr('cse_consent_responsibility', namedArgs: {'name': ex.organizerName}), (v) => setState(() => _resp = v)),
        _consent(_news, tr('cse_consent_newsletter'), (v) => setState(() => _news = v)),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(HomeV2.radiusSm), border: Border.all(color: Colors.red.shade200)),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: (_busy || _method.isEmpty) ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: widget.accent,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(tr('submit_registration'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _configField(CreatorExerciseDetail ex, String f) {
    final label = '${_label(f)}${_required(f) ? ' *' : ''}';
    // Typ izby → dropdown z cenníka (ak sú položky)
    if (f == 'room_type' && ex.pricing.isNotEmpty) {
      return InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: (_values['room_type']?.isNotEmpty ?? false) ? _values['room_type'] : null,
            hint: Text(tr('select_option')),
            items: ex.pricing
                .map((p) => DropdownMenuItem(
                      value: p.roomType,
                      child: Text('${p.roomType} — ${p.price.toStringAsFixed(0)} €', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _values['room_type'] = v ?? ''),
          ),
        ),
      );
    }
    // Dátum narodenia → date picker
    if (f == 'birth_date') {
      final val = _values['birth_date'] ?? '';
      return InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 30),
            firstDate: DateTime(1920),
            lastDate: now,
          );
          if (picked != null) {
            setState(() => _values['birth_date'] =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
          }
        },
        child: InputDecorator(
          decoration: _dec(label),
          child: Text(val.isEmpty ? tr('select_date') : val,
              style: TextStyle(color: val.isEmpty ? HomeV2.textMuted(context) : HomeV2.textDark(context))),
        ),
      );
    }
    // Viacriadkové
    final multiline = f == 'dietary_restrictions' || f == 'notes';
    return TextField(
      decoration: _dec(label),
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      maxLines: multiline ? 3 : 1,
      onChanged: (v) => _values[f] = v,
    );
  }

  Widget _text(TextEditingController c, String label, {TextInputType? keyboard}) =>
      TextField(controller: c, decoration: _dec(label), keyboardType: keyboard);

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: HomeV2.card(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      );

  Widget _consent(bool value, String text, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 34, height: 34,
            child: Checkbox(value: value, activeColor: widget.accent, onChanged: (v) => onChanged(v ?? false)),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: HomeV2.textDark(context))),
          )),
        ]),
      );
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/error_report_service.dart';
import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// Červený akcent „chyba“ — rovnaký ako vlajočka na karte kroku.
const Color kReportRed = Color(0xFFC0392B);

class ErrorReportInput {
  final ErrorReportKind kind;
  final String? notes;
  final String? corrected;
  const ErrorReportInput({required this.kind, this.notes, this.corrected});
}

/// Sheet „Nahlásiť chybu“ pre jeden krok lectia (dizajn v2: pilulky typu ako
/// vo Feedbacku, polia s jemným okrajom, pill tlačidlo). Vráti vstup, alebo null.
Future<ErrorReportInput?> showErrorReportSheet(
  BuildContext context, {
  required String stepTitle,
  bool hasAudio = true,
}) {
  return showModalBottomSheet<ErrorReportInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ErrorReportSheet(stepTitle: stepTitle, hasAudio: hasAudio),
  );
}

class _KindStyle {
  final IconData icon;
  final Color accent;
  const _KindStyle(this.icon, this.accent);
}

const Map<ErrorReportKind, _KindStyle> _kindStyles = {
  ErrorReportKind.typo: _KindStyle(Icons.spellcheck_rounded, HomeV2.primary),
  ErrorReportKind.grammar: _KindStyle(Icons.text_fields_rounded, HomeV2.gold),
  ErrorReportKind.meaning: _KindStyle(Icons.translate_rounded, kReportRed),
  ErrorReportKind.audio: _KindStyle(Icons.graphic_eq_rounded, Color(0xFF7C3AED)),
};

class _ErrorReportSheet extends StatefulWidget {
  const _ErrorReportSheet({required this.stepTitle, required this.hasAudio});
  final String stepTitle;
  final bool hasAudio;

  @override
  State<_ErrorReportSheet> createState() => _ErrorReportSheetState();
}

class _ErrorReportSheetState extends State<_ErrorReportSheet> {
  ErrorReportKind _kind = ErrorReportKind.typo;
  final _notes = TextEditingController();
  final _corrected = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _corrected.dispose();
    super.dispose();
  }

  void _submit() {
    final notes = _notes.text.trim();
    final corrected = _corrected.text.trim();
    if (_kind != ErrorReportKind.audio && notes.isEmpty && corrected.isEmpty) {
      setState(() => _error = 'error_report.need_text'.tr());
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      ErrorReportInput(
        kind: _kind,
        notes: notes.isEmpty ? null : notes,
        corrected: corrected.isEmpty ? null : corrected,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String? hint, {String? errorText}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      labelStyle: TextStyle(color: HomeV2.textMuted(context)),
      hintStyle: TextStyle(color: HomeV2.textMuted(context), height: 1.5),
      filled: true,
      fillColor: HomeV2.background(context),
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: border(HomeV2.primary.withValues(alpha: 0.15)),
      enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15)),
      focusedBorder: border(HomeV2.primary, 2),
      errorBorder: border(kReportRed),
      focusedErrorBorder: border(kReportRed, 2),
      errorText: errorText,
      errorStyle: const TextStyle(color: kReportRed),
    );
  }

  Widget _kindPill(ErrorReportKind k) {
    final st = _kindStyles[k]!;
    final selected = _kind == k;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _kind = k;
          _error = null;
        });
      },
      child: AnimatedContainer(
        duration: HomeV2.anim,
        curve: HomeV2.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? HomeV2.primary : HomeV2.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? HomeV2.primary : st.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: selected ? HomeV2.softShadowSm(context) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(st.icon, size: 16, color: selected ? Colors.white : st.accent),
            const SizedBox(width: 6),
            Text(
              k.trKey.tr(),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : HomeV2.textDark(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kinds = [
      ErrorReportKind.typo,
      ErrorReportKind.grammar,
      ErrorReportKind.meaning,
      if (widget.hasAudio) ErrorReportKind.audio,
    ];
    final isAudio = _kind == ErrorReportKind.audio;
    final textStyle = TextStyle(fontSize: 15, height: 1.5, color: HomeV2.textDark(context));
    return SafeArea(
      child: Padding(
        // nech sheet vyskočí nad klávesnicu
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: HomeV2.card(context),
            borderRadius: BorderRadius.circular(HomeV2.radius),
            // červený okraj = „chyba“ (Dušan 23. 9.)
            border: Border.all(color: kReportRed.withValues(alpha: 0.55), width: 1.5),
            boxShadow: HomeV2.softShadow(context),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HomeV2.textMuted(context).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kReportRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                      ),
                      child: const Icon(Icons.flag_rounded, color: kReportRed),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'error_report.title'.tr(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: HomeV2.textDark(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.stepTitle,
                            style: TextStyle(fontSize: 13, color: HomeV2.textMuted(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Typy chyby v jednom rade, posúvateľné do strany (Dušan 23. 9.)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (var i = 0; i < kinds.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        _kindPill(kinds[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  style: textStyle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    isAudio ? 'error_report.notes_label_audio'.tr() : 'error_report.notes_label'.tr(),
                    isAudio ? 'error_report.notes_hint_audio'.tr() : 'error_report.notes_hint'.tr(),
                    errorText: _error,
                  ),
                  onChanged: (_) => _error == null ? null : setState(() => _error = null),
                ),
                if (!isAudio) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _corrected,
                    minLines: 1,
                    maxLines: 3,
                    style: textStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _fieldDecoration('error_report.corrected_label'.tr(), null),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'error_report.send'.tr(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(foregroundColor: HomeV2.textMuted(context)),
                  child: Text('cancel'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

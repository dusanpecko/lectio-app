import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/error_report_service.dart';
import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

class ErrorReportInput {
  final ErrorReportKind kind;
  final String? notes;
  final String? corrected;
  const ErrorReportInput({required this.kind, this.notes, this.corrected});
}

/// Sheet „Nahlásiť chybu“ pre jeden krok lectia. Vráti vstup, alebo null.
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
    Navigator.of(context).pop(
      ErrorReportInput(
        kind: _kind,
        notes: notes.isEmpty ? null : notes,
        corrected: corrected.isEmpty ? null : corrected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kinds = [
      ErrorReportKind.typo,
      ErrorReportKind.grammar,
      ErrorReportKind.meaning,
      if (widget.hasAudio) ErrorReportKind.audio,
    ];
    final isAudio = _kind == ErrorReportKind.audio;
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
            boxShadow: HomeV2.softShadowSm(context),
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
                      color: theme.dividerColor,
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                      ),
                      child: Icon(Icons.flag_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'error_report.title'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            widget.stepTitle,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final k in kinds)
                      ChoiceChip(
                        label: Text(k.trKey.tr()),
                        selected: _kind == k,
                        onSelected: (_) => setState(() {
                          _kind = k;
                          _error = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: isAudio
                        ? 'error_report.notes_label_audio'.tr()
                        : 'error_report.notes_label'.tr(),
                    hintText: isAudio
                        ? 'error_report.notes_hint_audio'.tr()
                        : 'error_report.notes_hint'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(HomeV2.radiusSm)),
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
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'error_report.corrected_label'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HomeV2.radiusSm)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text('error_report.send'.tr()),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
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

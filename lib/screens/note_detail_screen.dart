import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class NoteDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? note;
  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _bibleReferenceCtrl;
  late TextEditingController _bibleQuoteCtrl;

  static const Color _scriptureGold = Color(0xFFB8862F);
  static const Color _danger = Color(0xFFC0392B);

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.note?['content'] ?? '');
    _bibleReferenceCtrl = TextEditingController(
      text: widget.note?['bible_reference'] ?? '',
    );
    _bibleQuoteCtrl = TextEditingController(
      text: widget.note?['bible_quote'] ?? '',
    );

    _titleCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
    _bibleReferenceCtrl.addListener(_onTextChanged);
    _bibleQuoteCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _bibleReferenceCtrl.dispose();
    _bibleQuoteCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.note != null && widget.note?['id'] != null;

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : const Color(0xFF2E9E5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(tr('note_unsaved_title'))),
          ],
        ),
        content: Text(tr('note_unsaved_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('note_stay'),
              style: TextStyle(color: HomeV2.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('note_leave')),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  Future<void> saveNote() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) _showSnack(tr('note_not_logged_in'), isError: true);
      setState(() => _isSaving = false);
      return;
    }

    final note = {
      'title': _titleCtrl.text.trim(),
      'content': _contentCtrl.text.trim(),
      'bible_reference': _bibleReferenceCtrl.text.trim(),
      'bible_quote': _bibleQuoteCtrl.text.trim(),
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final isInsert = widget.note == null || widget.note?['id'] == null;

      if (isInsert) {
        await Supabase.instance.client.from('notes').insert(note);
      } else {
        await Supabase.instance.client
            .from('notes')
            .update(note)
            .eq('id', widget.note!['id']);
      }

      setState(() => _hasChanges = false);

      if (mounted) {
        _showSnack(
          isInsert ? tr('note_created_msg') : tr('note_saved_msg'),
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('${tr('note_save_error')}: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> deleteNote() async {
    if (widget.note != null && widget.note?['id'] != null) {
      setState(() => _isDeleting = true);
      try {
        await Supabase.instance.client
            .from('notes')
            .delete()
            .eq('id', widget.note!['id']);

        if (mounted) {
          _showSnack(tr('note_deleted'), isError: false);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          _showSnack('${tr('note_delete_error')}: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    } else {
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(tr('delete_note'))),
          ],
        ),
        content: Text(tr('delete_note_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: HomeV2.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await deleteNote();
            },
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
  }

  void _trySave() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      HapticFeedback.mediumImpact();
      saveNote();
    }
  }

  Future<void> _openContentEditor() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NoteContentEditor(
          initialText: _contentCtrl.text,
          title: tr('note_content_label'),
          hint: tr('note_content_hint'),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null && result != _contentCtrl.text) {
      _contentCtrl.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!mounted) return;
        final shouldPop = await _onWillPop();
        if (!mounted) return;
        if (shouldPop) navigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: HomeV2.background(context),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHero(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(
                        label: tr('note_title_label'),
                        icon: Icons.title_rounded,
                        controller: _titleCtrl,
                        hint: tr('note_title_hint'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? tr('note_title_required')
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: tr('note_bible_ref_label'),
                        icon: Icons.menu_book_rounded,
                        iconColor: _scriptureGold,
                        controller: _bibleReferenceCtrl,
                        hint: tr('note_bible_ref_hint'),
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: tr('note_bible_quote_label'),
                        icon: Icons.format_quote_rounded,
                        iconColor: _scriptureGold,
                        controller: _bibleQuoteCtrl,
                        hint: tr('note_bible_quote_hint'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: tr('note_content_label'),
                        icon: Icons.edit_note_rounded,
                        controller: _contentCtrl,
                        hint: tr('note_content_hint'),
                        minLines: 4,
                        maxLines: 10,
                        readOnly: true,
                        onTap: _openContentEditor,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? tr('note_content_required')
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (_isEditing)
                _CircleButton(
                  icon: Icons.delete_outline_rounded,
                  iconColor: _danger,
                  onTap: _isDeleting ? null : _showDeleteDialog,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _isEditing ? tr('edit_note') : tr('new_note'),
            style: HomeV2.serifTitle(context, size: 28, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Pole vo v2 karte ──────────────────────────────────────────────────────
  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    Color? iconColor,
    int maxLines = 1,
    int? minLines,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final accent = iconColor ?? HomeV2.iconAccent(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              if (onTap != null) ...[
                const Spacer(),
                Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            readOnly: readOnly,
            onTap: onTap,
            textCapitalization: capitalization,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: HomeV2.textDark(context),
            ),
            validator: validator,
            decoration: _inputDecoration(hint),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: HomeV2.textMuted(context), fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: HomeV2.isDark(context)
          ? Colors.white.withValues(alpha: 0.04)
          : HomeV2.primary.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      focusedBorder: border(HomeV2.primary, 1.5),
      errorBorder: border(_danger, 1),
      focusedErrorBorder: border(_danger, 1.5),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _trySave,
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.save_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _isEditing ? tr('note_save_changes') : tr('note_create'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Celoobrazovkový editor obsahu poznámky ──────────────────────────────────
InputDecoration _editorDecoration(BuildContext context, String hint) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: HomeV2.textMuted(context), fontSize: 15),
    filled: true,
    fillColor: HomeV2.card(context),
    contentPadding: const EdgeInsets.all(AppSpacing.lg),
    border: border(HomeV2.primary.withValues(alpha: 0.15), 1),
    enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15), 1),
    focusedBorder: border(HomeV2.primary, 1.5),
  );
}

class _NoteContentEditor extends StatefulWidget {
  final String initialText;
  final String title;
  final String hint;
  const _NoteContentEditor({
    required this.initialText,
    required this.title,
    required this.hint,
  });

  @override
  State<_NoteContentEditor> createState() => _NoteContentEditorState();
}

class _NoteContentEditorState extends State<_NoteContentEditor> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    // Scaffold sám zmenší telo nad klávesnicu (resizeToAvoidBottomInset),
    // preto pri otvorenej klávesnici pridávame len malú medzeru; pri zatvorenej
    // rešpektujeme bezpečnú zónu (home indikátor), nech karta nejde k okraju.
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final bottomGap =
        AppSpacing.lg + (keyboardOpen ? 0.0 : mq.viewPadding.bottom);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _done();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: HomeV2.background(context),
          body: Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  topPad + AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: HomeV2.background(context),
                  boxShadow: HomeV2.softShadowSm(context),
                ),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.close_rounded,
                      onTap: _done,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: HomeV2.serifTitle(context, size: 20),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _done();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(
                        tr('note_save_short'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    bottomGap,
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: HomeV2.textDark(context),
                    ),
                    decoration: _editorDecoration(context, widget.hint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  const _CircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor ?? HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}

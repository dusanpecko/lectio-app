import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/app_spacing.dart';

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

    // Sledovanie zmien
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

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Neuložené zmeny'),
          ],
        ),
        content: const Text(
          'Máte neuložené zmeny. Naozaj chcete opustiť túto stránku?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zostať'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Opustiť'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: AppSpacing.sm),
                Text('Nie ste prihlásený'),
              ],
            ),
          ),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isInsert
                      ? 'Poznámka bola vytvorená'
                      : 'Poznámka bola uložená',
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text('Chyba pri ukladaní: ${e.toString()}'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: AppSpacing.sm),
                  Text('Poznámka bola zmazaná'),
                ],
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Chyba pri mazaní: ${e.toString()}'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Zmazať poznámku'),
          ],
        ),
        content: const Text(
          'Naozaj chcete túto poznámku zmazať? Táto akcia je nezvratná.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await deleteNote();
            },
            child: _isDeleting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Zmazať'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null && widget.note?['id'] != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);
        
        if (!mounted) return;
        final shouldPop = await _onWillPop();

        if (!mounted) return;
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Upraviť poznámku' : 'Nová poznámka'),
          elevation: AppElevation.none,
          actions: [
            if (_hasChanges && !_isSaving)
              TextButton.icon(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    saveNote();
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Uložiť'),
              ),
            if (isEditing)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteDialog();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Zmazať poznámku'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputCard(
                  title: 'Názov poznámky',
                  icon: Icons.title_rounded,
                  child: TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Zadajte názov poznámky...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Zadajte názov'
                        : null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildInputCard(
                  title: 'Biblická citácia',
                  icon: Icons.menu_book_rounded,
                  iconColor: Colors.green[700],
                  child: TextFormField(
                    controller: _bibleReferenceCtrl,
                    decoration: const InputDecoration(
                      hintText: 'napr. Jn 3,16 alebo Matúš 5:3-12',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildInputCard(
                  title: 'Biblický verš',
                  icon: Icons.format_quote_rounded,
                  iconColor: Colors.green[600],
                  child: TextFormField(
                    controller: _bibleQuoteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Citát z Biblie...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildInputCard(
                  title: 'Poznámka',
                  icon: Icons.note_alt_rounded,
                  child: TextFormField(
                    controller: _contentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Vaše myšlienky a úvahy...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      isDense: true,
                    ),
                    maxLines: 8,
                    minLines: 4,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Zadajte obsah poznámky'
                        : null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                Row(
                  children: [
                    if (isEditing) ...[
                      IconButton(
                        onPressed: _isDeleting ? null : _showDeleteDialog,
                        icon: _isDeleting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.1),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                        ),
                        tooltip: 'Zmazať poznámku',
                      ),
                      const SizedBox(width: AppSpacing.lg),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  saveNote();
                                }
                              },
                        icon: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          isEditing ? 'Uložiť zmeny' : 'Vytvoriť poznámku',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

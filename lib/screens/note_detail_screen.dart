import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _bibleReferenceCtrl.dispose();
    _bibleQuoteCtrl.dispose();
    super.dispose();
  }

  Future<void> saveNote() async {
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final note = {
      'title': _titleCtrl.text,
      'content': _contentCtrl.text,
      'bible_reference': _bibleReferenceCtrl.text,
      'bible_quote': _bibleQuoteCtrl.text,
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      // Tu je kľúčová podmienka:
      final isInsert =
          widget.note == null ||
          widget.note?['id'] == null; // ak nie je id, robí sa insert
      if (isInsert) {
        await Supabase.instance.client.from('notes').insert(note);
      } else {
        await Supabase.instance.client
            .from('notes')
            .update(note)
            .eq('id', widget.note!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nepodarilo sa uložiť poznámku.')),
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
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nepodarilo sa zmazať poznámku.')),
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
        title: const Text('Zmazať poznámku?'),
        content: const Text(
          'Naozaj chcete túto poznámku zmazať? Táto akcia je nezvratná.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await deleteNote();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: _isDeleting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Zmazať'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null && widget.note?['id'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upraviť poznámku' : 'Nová poznámka'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _showDeleteDialog,
              tooltip: 'Zmazať poznámku',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Názov'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte názov' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bibleReferenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Biblická citácia (napr. Jn 3,16)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bibleQuoteCtrl,
                decoration: const InputDecoration(labelText: 'Biblický verš'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextFormField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(labelText: 'Poznámka'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Zadajte poznámku'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            saveNote();
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Uložiť'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

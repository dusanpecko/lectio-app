import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'note_detail_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> filteredNotes = [];
  bool isLoading = true;
  String searchQuery = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchNotes();
  }

  Future<void> fetchNotes() async {
    setState(() => isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        notes = [];
        filteredNotes = [];
        isLoading = false;
      });
      return;
    }
    final response = await Supabase.instance.client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    setState(() {
      notes = List<Map<String, dynamic>>.from(response);
      filteredNotes = notes;
      isLoading = false;
    });
  }

  Future<void> deleteNote(dynamic noteId) async {
    await Supabase.instance.client.from('notes').delete().eq('id', noteId);
    await fetchNotes();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('note_deleted'))));
  }

  String formatDate(String? iso) {
    if (iso == null) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return DateFormat('d.M.yyyy').format(date);
  }

  void filterNotes(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredNotes = notes;
        searchQuery = "";
      });
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      filteredNotes = notes.where((note) {
        final title = (note['title'] ?? '').toString().toLowerCase();
        final content = (note['content'] ?? '').toString().toLowerCase();
        final bibleReference = (note['bible_reference'] ?? '')
            .toString()
            .toLowerCase();
        final bibleQuote = (note['bible_quote'] ?? '').toString().toLowerCase();
        return title.contains(q) ||
            content.contains(q) ||
            bibleReference.contains(q) ||
            bibleQuote.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('notes_title'))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: tr('search_notes'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: filterNotes,
                  ),
                ),
                Expanded(
                  child: filteredNotes.isEmpty
                      ? Center(child: Text(tr('no_notes')))
                      : ListView.separated(
                          itemCount: filteredNotes.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            final content = (note['content'] ?? '').toString();
                            final createdAt = note['created_at']?.toString();
                            final bibleReference = note['bible_reference']
                                ?.toString();
                            return ListTile(
                              title: Text(note['title']?.toString() ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content.length > 40
                                        ? '${content.substring(0, 40)}...'
                                        : content,
                                  ),
                                  if (bibleReference != null &&
                                      bibleReference.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        bibleReference,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.green[800],
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  if (createdAt != null)
                                    Text(
                                      "${tr('created_at')}: ${formatDate(createdAt)}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        NoteDetailScreen(note: note),
                                  ),
                                );
                                fetchNotes();
                              },
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: tr('delete_note'),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(tr('delete_note')),
                                      content: Text(tr('delete_note_confirm')),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(tr('cancel')),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(tr('delete')),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await deleteNote(note['id']);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteDetailScreen()),
          );
          fetchNotes();
        },
        tooltip: tr('add_note'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

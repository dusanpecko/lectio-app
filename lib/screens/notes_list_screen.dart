import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'note_detail_screen.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

    try {
      final response = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      setState(() {
        notes = List<Map<String, dynamic>>.from(response);
        filteredNotes = _applyQuery(notes, searchQuery);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        _showSnack('${tr('note_load_error')}: $e', isError: true);
      }
    }
  }

  Future<void> deleteNote(dynamic noteId) async {
    try {
      await Supabase.instance.client.from('notes').delete().eq('id', noteId);
      await fetchNotes();
      if (mounted) {
        _showSnack(tr('note_deleted'), isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('${tr('note_delete_error')}: $e', isError: true);
      }
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFC0392B) : const Color(0xFF2E9E5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  String formatDate(String? iso) {
    if (iso == null) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return DateFormat('d.M.yyyy').format(date);
  }

  List<Map<String, dynamic>> _applyQuery(
    List<Map<String, dynamic>> source,
    String query,
  ) {
    if (query.isEmpty) return source;
    final q = query.toLowerCase();
    return source.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final content = (note['content'] ?? '').toString().toLowerCase();
      final ref = (note['bible_reference'] ?? '').toString().toLowerCase();
      final quote = (note['bible_quote'] ?? '').toString().toLowerCase();
      return title.contains(q) ||
          content.contains(q) ||
          ref.contains(q) ||
          quote.contains(q);
    }).toList();
  }

  void filterNotes(String query) {
    setState(() {
      searchQuery = query;
      filteredNotes = _applyQuery(notes, query);
    });
  }

  Future<void> _openNote([Map<String, dynamic>? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            note == null ? const NoteDetailScreen() : NoteDetailScreen(note: note),
        settings: RouteSettings(
          name: note == null ? '/note-detail/new' : '/note-detail/edit',
        ),
      ),
    );
    fetchNotes();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
            _buildHero(),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchNotes,
                color: HomeV2.primary,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredNotes.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: AppSpacing.xs,
                              bottom: MediaQuery.of(context).viewPadding.bottom +
                                  96,
                            ),
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, index) =>
                                _buildNoteCard(filteredNotes[index]),
                          ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openNote(),
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            tr('add_note'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          shape: const StadiumBorder(),
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
              if (Navigator.canPop(context))
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              const Spacer(),
              _CircleButton(
                icon: Icons.refresh_rounded,
                onTap: fetchNotes,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('notes_title'),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
          if (!isLoading) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 15,
                  color: HomeV2.textMuted(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  searchQuery.isEmpty
                      ? '${notes.length}'
                      : '${filteredNotes.length} / ${notes.length}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Vyhľadávanie ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: filterNotes,
        style: TextStyle(fontSize: 15, color: HomeV2.textDark(context)),
        decoration: InputDecoration(
          hintText: tr('search_notes'),
          hintStyle: TextStyle(color: HomeV2.textMuted(context)),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: HomeV2.iconAccent(context),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: HomeV2.textMuted(context),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    filterNotes('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            borderSide: BorderSide(color: HomeV2.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ── Prázdny stav ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.note_alt_outlined,
                      size: 60,
                      color: HomeV2.iconAccent(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    searchQuery.isEmpty
                        ? tr('no_notes')
                        : tr('note_no_results'),
                    style: HomeV2.serifTitle(context, size: 22),
                    textAlign: TextAlign.center,
                  ),
                  if (searchQuery.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      tr('note_empty_hint'),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: HomeV2.textMuted(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Karta poznámky ──────────────────────────────────────────────────────────
  Widget _buildNoteCard(Map<String, dynamic> note) {
    final content = (note['content'] ?? '').toString();
    final createdAt = note['created_at']?.toString();
    final bibleReference = note['bible_reference']?.toString();
    final title = note['title']?.toString().trim();
    final hasTitle = title != null && title.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          onTap: () => _openNote(note),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hasTitle ? title : tr('note_untitled'),
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: hasTitle
                              ? HomeV2.textDark(context)
                              : HomeV2.textMuted(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildMenu(note),
                  ],
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: HomeV2.textMuted(context),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (bibleReference != null && bibleReference.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: HomeV2.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: HomeV2.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          size: 15,
                          color: Color(0xFFB8862F),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            bibleReference,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB8862F),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: HomeV2.textMuted(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        "${tr('created_at')}: ${formatDate(createdAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Map<String, dynamic> note) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: HomeV2.textMuted(context),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
      onSelected: (value) async {
        if (value == 'delete') {
          final confirm = await _confirmDelete();
          if (confirm == true) {
            await deleteNote(note['id']);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Color(0xFFC0392B)),
              const SizedBox(width: AppSpacing.sm),
              Text(tr('delete_note')),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HomeV2.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(tr('delete_note'))),
          ],
        ),
        content: Text(tr('delete_note_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: HomeV2.textMuted(context)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
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

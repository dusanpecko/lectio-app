import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_logger.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const NewsDetailScreen({super.key, required this.newsData});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late int likes;
  bool liked = false;
  bool loading = false;

  List<Map<String, dynamic>> comments = [];
  final TextEditingController commentController = TextEditingController();
  bool sendingComment = false;

  String? currentUserRole;
  String? _formUrl;

  @override
  void initState() {
    super.initState();
    likes = widget.newsData['likes'] is int
        ? widget.newsData['likes']
        : int.tryParse(widget.newsData['likes']?.toString() ?? '0') ?? 0;

    checkIfLiked();
    loadComments();
    fetchCurrentUserRole();
    _extractFormUrl();
  }

  void _extractFormUrl() {
    final formEmbedCode = widget.newsData['form_embed_code'];
    if (formEmbedCode != null && formEmbedCode.isNotEmpty) {
      // Extrahuj URL z href="https://dpforms.sk/app/form?id=XXXXX"
      final hrefRegex = RegExp(
        r'href="(https://dpforms\.sk/app/form\?id=[^"]+)"',
      );
      final match = hrefRegex.firstMatch(formEmbedCode);

      if (match != null) {
        setState(() {
          _formUrl = match.group(1);
        });
        appLogger.d('Extracted form URL: $_formUrl');
      }
    }
  }

  Future<void> _openForm() async {
    if (_formUrl == null) return;

    final uri = Uri.parse(_formUrl!);
    try {
      // Pokúsi sa otvoriť URL - najprv inAppBrowserView, potom externalApplication
      bool launched = false;

      // Skús najprv inAppBrowserView (funguje na iOS, niektorých Android)
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
      } catch (e) {
        appLogger.d('inAppBrowserView failed: $e');
      }

      // Ak nefungovalo, skús externalApplication (otvorí Chrome/Safari)
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          appLogger.d('externalApplication failed: $e');
        }
      }

      if (!launched) {
        appLogger.d('Cannot launch URL: $_formUrl');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('error'))));
        }
      }
    } catch (e) {
      appLogger.e('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('error'))));
      }
    }
  }

  Future<void> fetchCurrentUserRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      setState(() {
        currentUserRole = response['role'];
      });
    }
  }

  Future<void> checkIfLiked() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final newsId = widget.newsData['id'];

    if (userId == null) return;

    final response = await supabase
        .from('news_likes')
        .select('id')
        .eq('user_id', userId)
        .eq('news_id', newsId)
        .maybeSingle();

    if (response != null) {
      setState(() {
        liked = true;
      });
    }
  }

  Future<void> handleLike() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final newsId = widget.newsData['id'];

    if (userId == null) {
      _showLoginPrompt();
      return;
    }

    if (liked) return;

    setState(() {
      liked = true;
      likes += 1;
      loading = true;
    });

    try {
      await supabase.from('news_likes').insert({
        'user_id': userId,
        'news_id': newsId,
      });

      await supabase.from('news').update({'likes': likes}).eq('id', newsId);
    } catch (e) {
      setState(() {
        liked = false;
        likes -= 1;
      });
      appLogger.e('Error liking news: $e');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('login_required_title')),
        content: Text(tr('login_required_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(tr('login')),
          ),
        ],
      ),
    );
  }

  Future<void> loadComments() async {
    final supabase = Supabase.instance.client;
    final newsId = widget.newsData['id'];

    final response = await supabase
        .from('news_comments')
        .select(
          'id, content, created_at, user_id, users(full_name, role, avatar_url)',
        )
        .eq('news_id', newsId)
        .order('created_at', ascending: false);

    setState(() {
      comments = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> sendComment() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final newsId = widget.newsData['id'];
    final text = commentController.text.trim();

    if (user == null) {
      _showLoginPrompt();
      return;
    }

    if (text.isEmpty) return;

    setState(() => sendingComment = true);

    try {
      await supabase.from('news_comments').insert({
        'news_id': newsId,
        'user_id': user.id,
        'content': text,
      });

      commentController.clear();
      await loadComments();
    } catch (e) {
      appLogger.e('Error sending comment: $e');
    } finally {
      setState(() => sendingComment = false);
    }
  }

  /// Bezpečné formátovanie dátumu komentára
  String _formatCommentDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('d.M.y H:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  bool _canDeleteComment(Map comment) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    final isOwner = currentUser.id == comment['user_id'];
    final isAdmin = currentUserRole == 'admin';

    return isOwner || isAdmin;
  }

  Future<void> _confirmDeleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm')),
        content: Text(tr('delete_comment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteComment(commentId);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('news_comments').delete().eq('id', commentId);
      await loadComments();
    } catch (e) {
      appLogger.e('Error deleting comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.newsData;
    final imageUrl = data['image_url'] ?? '';
    final title = data['title'] ?? '';
    final htmlContent = data['content'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(tr('news_detail'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Html(
                      data: htmlContent,
                      style: {"body": Style(fontSize: FontSize(16))},
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: liked || loading ? null : handleLike,
                          icon: const Icon(
                            Icons.thumb_up_alt_rounded,
                            size: 18,
                          ),
                          label: Text(
                            tr('likes', namedArgs: {'count': likes.toString()}),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: liked
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(128)
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // EasyForms Button
            if (_formUrl != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.assignment,
                            color: Color(0xFF40467b),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('interactive_form'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF40467b),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('fill_form_below'),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openForm,
                          icon: const Icon(Icons.open_in_browser, size: 20),
                          label: Text(
                            tr('open_form'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF40467b),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              tr('comments'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            for (final comment in comments)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                color: comment['users']?['role'] == 'admin'
                    ? Colors.orange.withValues(alpha: 0.08)
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: comment['users']?['avatar_url'] != null
                            ? NetworkImage(comment['users']!['avatar_url'])
                            : null,
                        child: comment['users']?['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment['users']?['full_name'] ??
                                      'Používateľ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (comment['users']?['role'] == 'admin')
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text(
                                      '(admin)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment['content'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCommentDate(comment['created_at']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canDeleteComment(comment))
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _confirmDeleteComment(comment['id']),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: tr('write_comment'),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: sendingComment
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(tr('send_comment')),
              onPressed: sendingComment ? null : sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

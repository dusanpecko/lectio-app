import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void initState() {
    super.initState();
    likes = widget.newsData['likes'] is int
        ? widget.newsData['likes']
        : int.tryParse(widget.newsData['likes']?.toString() ?? '0') ?? 0;

    checkIfLiked();
    loadComments();
    fetchCurrentUserRole();
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
      debugPrint('Error liking news: $e');
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
              // TODO: navigate to login screen
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
      debugPrint('Error sending comment: $e');
    } finally {
      setState(() => sendingComment = false);
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
      debugPrint('Error deleting comment: $e');
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
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
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
                    ? Colors.orange.withOpacity(0.08)
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
                              DateFormat(
                                'd.M.y H:mm',
                              ).format(DateTime.parse(comment['created_at'])),
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

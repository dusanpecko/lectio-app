import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/media_player_bus.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const NewsDetailScreen({super.key, required this.newsData});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  static const Color _danger = Color(0xFFC0392B);
  static const Color _scriptureGold = Color(0xFFB8862F);

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

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void _extractFormUrl() {
    final formEmbedCode = widget.newsData['form_embed_code'];
    if (formEmbedCode != null && formEmbedCode.isNotEmpty) {
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
      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
      } catch (e) {
        appLogger.d('inAppBrowserView failed: $e');
      }

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          appLogger.d('externalApplication failed: $e');
        }
      }

      if (!launched) {
        appLogger.d('Cannot launch URL: $_formUrl');
        if (mounted) _snack(tr('error'), isError: true);
      }
    } catch (e) {
      appLogger.e('Error launching URL: $e');
      if (mounted) _snack(tr('error'), isError: true);
    }
  }

  void _snack(String message, {required bool isError}) {
    if (!mounted) return;
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

  Future<void> fetchCurrentUserRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null && mounted) {
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

    if (response != null && mounted) {
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

    HapticFeedback.lightImpact();
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
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Text(tr('login_required_title')),
        content: Text(tr('login_required_message')),
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
              backgroundColor: HomeV2.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
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

    if (mounted) {
      setState(() {
        comments = List<Map<String, dynamic>>.from(response);
      });
    }
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

    FocusScope.of(context).unfocus();
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
      if (mounted) setState(() => sendingComment = false);
    }
  }

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
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Text(tr('confirm')),
        content: Text(tr('delete_comment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = widget.newsData;
    final imageUrl = data['image_url'] ?? '';
    final title = data['title'] ?? '';
    final htmlContent = data['content'] ?? '';

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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildArticleCard(imageUrl, title, htmlContent),
                    if (_formUrl != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildFormCard(),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      tr('comments'),
                      style: HomeV2.serifTitle(context, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final comment in comments) _buildCommentCard(comment),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCommentInput(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
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
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tr('news_detail'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v2Card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: child,
    );
  }

  Widget _buildArticleCard(String imageUrl, String title, String htmlContent) {
    return _v2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
                placeholder: (_, _) => Container(
                  height: 220,
                  color: HomeV2.primary.withValues(alpha: 0.06),
                ),
                errorWidget: (_, _, _) => Container(
                  height: 220,
                  color: HomeV2.primary.withValues(alpha: 0.06),
                  child: Icon(Icons.broken_image_rounded,
                      color: HomeV2.textMuted(context)),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: HomeV2.serifTitle(context, size: 24, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          if (((widget.newsData['audio_url'] as String?) ?? '').isNotEmpty) ...[
            _ArticleAudio(
              audioUrl: widget.newsData['audio_url'] as String,
              title: title.isNotEmpty ? title : tr('news_listen'),
              artUri: widget.newsData['image_url'] as String?,
              newsId: widget.newsData['id']?.toString(),
              lang: widget.newsData['lang'] as String?,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Html(
            data: htmlContent,
            style: {
              "body": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(15.5),
                lineHeight: const LineHeight(1.6),
                color: HomeV2.textDark(context),
              ),
              "p": Style(
                lineHeight: const LineHeight(1.6),
                margin: Margins.only(top: 0, bottom: 4),
              ),
              "div": Style(
                lineHeight: const LineHeight(1.6),
                margin: Margins.zero,
              ),
              "a": Style(color: HomeV2.primary),
              "hr": Style(
                margin: Margins.only(top: 8, bottom: 8),
                border: Border(
                  bottom: BorderSide(
                    color: HomeV2.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              FilledButton.icon(
                onPressed: liked || loading ? null : handleLike,
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(
                  tr('likes', namedArgs: {'count': likes.toString()}),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      liked ? HomeV2.primary.withValues(alpha: 0.5) : HomeV2.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.md),
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
    );
  }

  Widget _buildFormCard() {
    return _v2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded,
                  color: HomeV2.iconAccent(context), size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr('interactive_form'),
                  style: HomeV2.serifTitle(context, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('fill_form_below'),
            style: TextStyle(fontSize: 14, color: HomeV2.textMuted(context)),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              label: Text(
                tr('open_form'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeV2.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isAdmin = comment['users']?['role'] == 'admin';
    final avatarUrl = comment['users']?['avatar_url'];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isAdmin
            ? HomeV2.gold.withValues(alpha: 0.08)
            : HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
        border: isAdmin
            ? Border.all(color: HomeV2.gold.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: HomeV2.primary.withValues(alpha: 0.12),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.person_rounded, color: HomeV2.iconAccent(context))
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment['users']?['full_name'] ?? tr('user'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          '(admin)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _scriptureGold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comment['content'] ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatCommentDate(comment['created_at']),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          if (_canDeleteComment(comment))
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: HomeV2.textMuted(context)),
              onPressed: () => _confirmDeleteComment(comment['id']),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      children: [
        TextField(
          controller: commentController,
          maxLines: null,
          minLines: 2,
          style: TextStyle(color: HomeV2.textDark(context)),
          decoration: InputDecoration(
            hintText: tr('write_comment'),
            hintStyle: TextStyle(color: HomeV2.textMuted(context)),
            filled: true,
            fillColor: HomeV2.card(context),
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: border(HomeV2.primary.withValues(alpha: 0.15), 1),
            enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15), 1),
            focusedBorder: border(HomeV2.primary, 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: sendingComment ? null : sendComment,
            icon: sendingComment
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              tr('send_comment'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeV2.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
      ],
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

/// Inline „Prečítať článok" prehrávač — pustí audio_url článku cez zdieľaný
/// [MediaPlayerBus] (jediný povolený background player), nie cez vlastný player.
class _ArticleAudio extends StatelessWidget {
  final String audioUrl;
  final String title;
  final String? artUri;
  final String? newsId;
  final String? lang;

  const _ArticleAudio({
    required this.audioUrl,
    required this.title,
    this.artUri,
    this.newsId,
    this.lang,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bus = MediaPlayerBus.instance;
    final mediaId = 'news_${newsId ?? audioUrl}';
    void toggle() {
      HapticFeedback.lightImpact();
      bus.toggle(
        id: mediaId,
        url: audioUrl,
        title: title,
        artUri: artUri,
        contentType: 'news',
        contentId: newsId,
        language: lang,
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
      child: ListenableBuilder(
        listenable: bus,
        builder: (context, _) {
          final isCurrent = bus.isCurrent(mediaId);
          return StreamBuilder<bool>(
            stream: bus.playingStream,
            initialData: bus.isPlaying,
            builder: (context, playSnap) {
              final isPlaying = isCurrent && (playSnap.data ?? false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: toggle,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: HomeV2.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          tr('news_listen'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: HomeV2.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.headphones_rounded,
                          size: 18, color: HomeV2.primary),
                    ],
                  ),
                  if (isCurrent)
                    StreamBuilder<Duration>(
                      stream: bus.positionStream,
                      initialData: bus.position,
                      builder: (context, posSnap) {
                        return StreamBuilder<Duration?>(
                          stream: bus.durationStream,
                          initialData: bus.duration,
                          builder: (context, durSnap) {
                            final pos = posSnap.data ?? Duration.zero;
                            final total = durSnap.data ?? Duration.zero;
                            final maxMs = total.inMilliseconds <= 0
                                ? 1
                                : total.inMilliseconds;
                            final value =
                                pos.inMilliseconds.clamp(0, maxMs).toDouble();
                            return Column(
                              children: [
                                SizedBox(
                                  height: 22,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      activeTrackColor: HomeV2.primary,
                                      inactiveTrackColor: HomeV2.primary
                                          .withValues(alpha: 0.15),
                                      thumbColor: HomeV2.primary,
                                      overlayShape:
                                          SliderComponentShape.noOverlay,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5),
                                    ),
                                    child: Slider(
                                      value: value,
                                      min: 0,
                                      max: maxMs.toDouble(),
                                      onChanged: (v) => bus.seek(
                                          Duration(milliseconds: v.toInt())),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_fmt(pos),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: HomeV2.textMuted(context))),
                                    Text(total > Duration.zero ? _fmt(total) : '--:--',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: HomeV2.textMuted(context))),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

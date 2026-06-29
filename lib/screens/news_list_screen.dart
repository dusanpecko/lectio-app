import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'news_detail_screen.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  List<Map<String, dynamic>> news = [];
  bool isLoading = true;
  String? errorMessage;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      fetchNews();
      _initialized = true;
    }
  }

  Future<void> fetchNews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final locale = context.locale.languageCode;
      final now = DateTime.now().toIso8601String();

      final response = await supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false);

      setState(() {
        news = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e, stacktrace) {
      debugPrint('ERROR: fetchNews exception: $e');
      debugPrint('ERROR: Stacktrace: $stacktrace');
      setState(() {
        isLoading = false;
        errorMessage = tr('news_load_failed');
      });
    }
  }

  Future<void> _onRefresh() async {
    await fetchNews();
  }

  Future<void> _openArticle(Map<String, dynamic> article) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(newsData: article),
        settings: const RouteSettings(name: '/news-detail'),
      ),
    );
    if (result == true) fetchNews();
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
            Expanded(child: _buildBody()),
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
              if (news.isNotEmpty)
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: _onRefresh,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('news_title'),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return _buildMessage(
        Icons.cloud_off_rounded,
        errorMessage!,
        action: TextButton.icon(
          onPressed: fetchNews,
          icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
          label: Text(
            tr('common.try_again'),
            style: TextStyle(color: HomeV2.primary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (news.isEmpty) {
      return _buildMessage(Icons.campaign_outlined, tr('news_empty'));
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        itemCount: news.length,
        itemBuilder: (context, index) => _buildCard(news[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> article) {
    final imageUrl = article['image_url'] as String?;
    final title = article['title'] as String? ?? '';
    final summary = article['summary'] as String? ?? '';
    final likes = article['likes'] is int
        ? article['likes']
        : int.tryParse(article['likes']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openArticle(article),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 200,
                    color: HomeV2.primary.withValues(alpha: 0.06),
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 200,
                    color: HomeV2.primary.withValues(alpha: 0.06),
                    child: Icon(Icons.broken_image_rounded,
                        size: 44, color: HomeV2.textMuted(context)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HomeV2.serifTitle(context, size: 19, height: 1.2),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      summary.length > 250
                          ? '${summary.substring(0, 247)}...'
                          : summary,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_rounded,
                                color: HomeV2.gold, size: 18),
                            const SizedBox(width: 5),
                            Text(
                              likes.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HomeV2.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                        FilledButton(
                          onPressed: () => _openArticle(article),
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
                            tr('more'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ],
        ),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'news_detail_screen.dart';
import '../shared/app_spacing.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  List<Map<String, dynamic>> news = [];
  bool isLoading = true;
  String? errorMessage;
  bool _initialized = false; // na ochranu pred opakovaným fetchom

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

      debugPrint('DEBUG: Fetching news for lang=$locale, published_at <= $now');

      final response = await supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false);

      debugPrint('DEBUG: Supabase response: $response');

      setState(() {
        news = List<Map<String, dynamic>>.from(response);
        debugPrint('DEBUG: Parsed news length: ${news.length}');
        if (news.isEmpty) debugPrint('DEBUG: No articles found for filter!');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('news_title'))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : news.isEmpty
          ? Center(child: Text(tr('news_empty')))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.separated(
                itemCount: news.length,
                padding: const EdgeInsets.all(AppSpacing.lg),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final theme = Theme.of(context);
                  final article = news[index];
                  final imageUrl = article['image_url'] as String?;
                  final title = article['title'] as String? ?? '';
                  final summary = article['summary'] as String? ?? '';
                  final likes = article['likes'] is int
                      ? article['likes']
                      : int.tryParse(article['likes']?.toString() ?? '0') ?? 0;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: AppElevation.medium,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NewsDetailScreen(newsData: article),
                            settings: const RouteSettings(name: '/news-detail'),
                          ),
                        );
                        if (result == true) {
                          fetchNews();
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(AppRadius.lg),
                                topRight: Radius.circular(AppRadius.lg),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                height: 230,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) {
                                  return Container(
                                    height: 230,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorWidget: (context, url, error) {
                                  return Container(
                                    height: 230,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  summary.length > 250
                                      ? '${summary.substring(0, 247)}...'
                                      : summary,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.favorite,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          likes.toString(),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                NewsDetailScreen(
                                                  newsData: article,
                                                ),
                                            settings: const RouteSettings(
                                              name: '/news-detail',
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          fetchNews();
                                        }
                                      },
                                      child: Text(tr('more')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

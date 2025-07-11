import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'news_detail_screen.dart';

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

      print('DEBUG: Fetching news for lang=$locale, published_at <= $now');

      final response = await supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false);

      print('DEBUG: Supabase response: $response');

      setState(() {
        news = List<Map<String, dynamic>>.from(response);
        print('DEBUG: Parsed news length: ${news.length}');
        if (news.isEmpty) print('DEBUG: No articles found for filter!');
        isLoading = false;
      });
    } catch (e, stacktrace) {
      print('ERROR: fetchNews exception: $e');
      print('ERROR: Stacktrace: $stacktrace');
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
                padding: const EdgeInsets.all(16),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final article = news[index];
                  final imageUrl = article['image_url'] as String?;
                  final title = article['title'] as String? ?? '';
                  final summary = article['summary'] as String? ?? '';
                  final likes = article['likes'] is int
                      ? article['likes']
                      : int.tryParse(article['likes']?.toString() ?? '0') ?? 0;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NewsDetailScreen(newsData: article),
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
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: Image.network(
                                imageUrl,
                                height: 230,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 230,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
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
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summary.length > 250
                                      ? '${summary.substring(0, 247)}...'
                                      : summary,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 12),
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
                                          style: const TextStyle(fontSize: 14),
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

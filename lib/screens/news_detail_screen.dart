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

  @override
  void initState() {
    super.initState();
    likes = widget.newsData['likes'] is int
        ? widget.newsData['likes']
        : int.tryParse(widget.newsData['likes']?.toString() ?? '0') ?? 0;
  }

  Future<void> handleLike() async {
    if (liked) return;

    setState(() {
      liked = true;
      likes += 1;
      loading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('news')
          .update({'likes': likes})
          .eq('id', widget.newsData['id']);
    } catch (e) {
      setState(() {
        likes -= 1;
        liked = false;
      });
    } finally {
      setState(() {
        loading = false;
      });
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
                errorBuilder: (context, error, stack) => Container(
                  height: 220,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
                icon: const Icon(Icons.thumb_up_alt_rounded, size: 18),
                label: Text(tr('likes', args: [likes.toString()])),
                style: ElevatedButton.styleFrom(
                  backgroundColor: liked
                      ? Theme.of(context).colorScheme.primary.withAlpha(128)
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
    );
  }
}

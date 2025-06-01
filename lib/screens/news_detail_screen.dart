import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const NewsDetailScreen({super.key, required this.newsData});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late int likes;
  bool liked = false; // Lokálna info, backend nepotvrdzuje
  bool loading = false;

  @override
  void initState() {
    super.initState();
    likes = widget.newsData['likes'] ?? 0;
  }

  Future<void> handleLike() async {
    if (liked) return; // Neumožni viackrát

    setState(() {
      liked = true;
      likes += 1;
      loading = true;
    });
    // Update v Supabase (aj pre neregistrovaného používateľa)
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('news')
          .update({'likes': likes})
          .eq('id', widget.newsData['id']);
    } catch (e) {
      // Ak by nastala chyba, môžeš vrátiť späť
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
      appBar: AppBar(
        title: const Text('Aktualita'),
        backgroundColor: Colors.deepPurple,
      ),
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
              ),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 12),
          // HTML obsah
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
                label: Text('Páči sa mi ($likes)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: liked
                      ? Colors.deepPurple.withOpacity(0.5)
                      : Colors.deepPurple,
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

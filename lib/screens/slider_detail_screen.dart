import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:easy_localization/easy_localization.dart';

class SliderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const SliderDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['image_url_2'] ?? data['image_url'];
    final descriptions =
        List.generate(6, (index) => data['description_${index + 1}'])
            .where(
              (element) =>
                  element != null && element.toString().trim().isNotEmpty,
            )
            .toList();

    final visibleFrom =
        DateTime.tryParse(data['visible_from'] ?? '') ?? DateTime(2000);
    final visibleTo =
        DateTime.tryParse(data['visible_to'] ?? '') ?? DateTime(2100);
    final now = DateTime.now();

    if (now.isBefore(visibleFrom) || now.isAfter(visibleTo)) {
      return Scaffold(body: Center(child: Text(tr('content_not_available'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('detail'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null && imageUrl.toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
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
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            for (final desc in descriptions)
              if (desc != null && desc.toString().trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Html(
                    data: _convertImageLinks(desc.toString()),
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: FontSize(16),
                      ),
                    },
                    extensions: [
                      TagExtension(
                        tagsToExtend: {"img"},
                        builder: (context) {
                          final src = context.attributes['src'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Image.network(src),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            if (data['published_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    '${tr('published')}: ${data['published_at'].toString().split('T').first}',
                    style: TextStyle(
                      color:
                          Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withAlpha(179) ??
                          Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _convertImageLinks(String html) {
    final imageLinkRegex = RegExp(r'(https?:\/\/.+?\.(jpg|jpeg|png|gif))');
    return html.replaceAllMapped(imageLinkRegex, (match) {
      final url = match.group(0);
      return '<img src="$url" />';
    });
  }
}

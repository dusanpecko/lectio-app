import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/app_spacing.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';

class NewsletterDetailScreen extends StatelessWidget {
  final Map<String, dynamic> newsletterData;

  const NewsletterDetailScreen({super.key, required this.newsletterData});

  String _formatDate(String? dateStr, BuildContext context) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(
        'd. MMMM yyyy, HH:mm',
        context.locale.toString(),
      ).format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = newsletterData['subject'] as String? ?? '';
    final htmlContent = newsletterData['html_content'] as String? ?? '';
    final senderName =
        newsletterData['sender_name'] as String? ?? 'Lectio Divina';
    final sentAt = _formatDate(newsletterData['sent_at'] as String?, context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('newsletter_detail')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Strip HTML tags for share text
              final plainText = htmlContent
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
              final shareText = plainText.length > 300
                  ? '${plainText.substring(0, 297)}...'
                  : plainText;
              SharePlus.instance.share(
                ShareParams(text: '$subject\n\n$shareText'),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              elevation: AppElevation.high,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject / title
                    Text(
                      subject,
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Sender + date
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 16,
                          color: AppColors.adaptiveCardSubtitle(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          senderName,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: AppColors.adaptiveCardSubtitle(context),
                          ),
                        ),
                        if (sentAt.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: AppColors.adaptiveCardSubtitle(context),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              sentAt,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: AppColors.adaptiveCardSubtitle(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // HTML content
                    Html(
                      data: htmlContent,
                      onLinkTap: (url, _, _) {
                        if (url != null) {
                          _launchUrl(url);
                        }
                      },
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(16),
                        ),
                        "p": Style(
                          lineHeight: const LineHeight(1.6),
                          margin: Margins.only(top: 0, bottom: 8),
                        ),
                        "div": Style(
                          lineHeight: const LineHeight(1.6),
                          margin: Margins.zero,
                        ),
                        "h1": Style(
                          fontSize: FontSize(22),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 16, bottom: 8),
                        ),
                        "h2": Style(
                          fontSize: FontSize(20),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 14, bottom: 6),
                        ),
                        "h3": Style(
                          fontSize: FontSize(18),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 12, bottom: 4),
                        ),
                        "a": Style(
                          color: AppColors.primary,
                          textDecoration: TextDecoration.underline,
                        ),
                        "img": Style(margin: Margins.only(top: 8, bottom: 8)),
                        "hr": Style(
                          margin: Margins.only(top: 8, bottom: 8),
                          border: const Border(
                            bottom: BorderSide(color: Colors.grey, width: 1),
                          ),
                        ),
                        "ul": Style(
                          margin: Margins.only(left: 16, top: 4, bottom: 4),
                        ),
                        "ol": Style(
                          margin: Margins.only(left: 16, top: 4, bottom: 4),
                        ),
                        "blockquote": Style(
                          margin: Margins.only(left: 16, top: 8, bottom: 8),
                          padding: HtmlPaddings.only(left: 12),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                          fontStyle: FontStyle.italic,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      appLogger.e('Error launching URL: $e');
    }
  }
}

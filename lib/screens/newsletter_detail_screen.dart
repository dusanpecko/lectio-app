import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
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

  /// Detect if content is a full HTML document (email template)
  bool _isFullHtmlDocument(String html) {
    final lower = html.trimLeft().toLowerCase();
    return lower.startsWith('<!doctype') ||
        lower.startsWith('<html') ||
        lower.contains('<head');
  }

  /// Extract body content from a full HTML document
  String _extractBodyContent(String html) {
    // Try to extract content between <body> tags
    final bodyStart = html.indexOf(
      RegExp(r'<body[^>]*>', caseSensitive: false),
    );
    if (bodyStart == -1) return html;

    final bodyTagEnd = html.indexOf('>', bodyStart);
    if (bodyTagEnd == -1) return html;

    final bodyClose = html.lastIndexOf(
      RegExp(r'</body>', caseSensitive: false),
    );
    if (bodyClose == -1) return html.substring(bodyTagEnd + 1);

    return html.substring(bodyTagEnd + 1, bodyClose);
  }

  /// Remove Brevo template variables and auto-appended unsubscribe footer
  String _cleanContent(String html) {
    // Remove the auto-appended unsubscribe footer block
    // Pattern: <hr style="..."><p style="...">...<a href="{{ unsubscribe }}">...</a>...</p>
    var cleaned = html.replaceAll(
      RegExp(
        r'<hr[^>]*>\s*<p[^>]*>[^<]*<a[^>]*\{\{\s*unsubscribe\s*\}\}[^<]*</a>[^<]*</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    // Also remove standalone {{ unsubscribe }} text/links
    cleaned = cleaned.replaceAll(
      RegExp(
        r'<[^>]*\{\{\s*unsubscribe\s*\}\}[^>]*>[^<]*</[^>]*>',
        caseSensitive: false,
      ),
      '',
    );
    // Remove any remaining {{ unsubscribe }} plain text
    cleaned = cleaned.replaceAll(
      RegExp(r'\{\{\s*unsubscribe\s*\}\}'),
      '',
    );
    // Remove trailing empty paragraphs and hrs
    cleaned = cleaned.replaceAll(
      RegExp(r'(<hr[^>]*>\s*|<p>\s*</p>\s*)*$', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = newsletterData['subject'] as String? ?? '';
    final htmlContent = newsletterData['html_content'] as String? ?? '';
    final senderName =
        newsletterData['sender_name'] as String? ?? 'Lectio Divina';
    final sentAt = _formatDate(newsletterData['sent_at'] as String?, context);
    final isFullDocument = _isFullHtmlDocument(htmlContent);

    // Clean content: extract body if full doc, then strip unsubscribe
    final displayContent = _cleanContent(
      isFullDocument ? _extractBodyContent(htmlContent) : htmlContent,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('newsletter_detail')),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: subject, sender, date
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: theme.textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                ],
              ),
            ),

            // Show empty state if content was stripped
            if (displayContent.isEmpty ||
                displayContent.replaceAll(RegExp(r'<[^>]*>'), '').trim().isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    tr('newsletter_empty'),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: AppColors.adaptiveCardSubtitle(context),
                    ),
                  ),
                ),
              )
            else
            // HTML content — rendered without Card wrapper for full documents
            Html(
              data: displayContent,
              onLinkTap: (url, _, _) {
                if (url != null) {
                  _launchUrl(url);
                }
              },
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(15),
                ),
                "p": Style(
                  lineHeight: const LineHeight(1.6),
                  margin: Margins.only(top: 0, bottom: 8),
                ),
                "div": Style(
                  lineHeight: const LineHeight(1.6),
                  margin: Margins.zero,
                ),
                "table": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
                "td": Style(padding: HtmlPaddings.zero),
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
                "ul": Style(margin: Margins.only(left: 16, top: 4, bottom: 4)),
                "ol": Style(margin: Margins.only(left: 16, top: 4, bottom: 4)),
                "blockquote": Style(
                  margin: Margins.only(left: 16, top: 8, bottom: 8),
                  padding: HtmlPaddings.only(left: 12),
                  border: const Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  ),
                  fontStyle: FontStyle.italic,
                ),
              },
            ),
            const SizedBox(height: AppSpacing.xl),
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

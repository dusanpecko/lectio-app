import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class NewsletterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> newsletterData;

  const NewsletterDetailScreen({super.key, required this.newsletterData});

  @override
  State<NewsletterDetailScreen> createState() => _NewsletterDetailScreenState();
}

class _NewsletterDetailScreenState extends State<NewsletterDetailScreen> {
  WebViewController? _webViewController;
  double _webViewHeight = 400; // Initial estimate, will be updated
  bool _webViewReady = false;
  late final bool _isFullDocument;
  late final String _cleanedHtml;

  @override
  void initState() {
    super.initState();
    final htmlContent = widget.newsletterData['html_content'] as String? ?? '';
    _isFullDocument = _isFullHtmlDocument(htmlContent);

    if (_isFullDocument) {
      _cleanedHtml = _cleanFullHtml(htmlContent);
      _initWebView(_cleanedHtml);
    } else {
      _cleanedHtml = _cleanSimpleHtml(htmlContent);
    }
  }

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

  /// Remove Brevo template variables and auto-appended unsubscribe footer
  String _cleanFullHtml(String html) {
    final htmlCloseIdx = html.lastIndexOf(
      RegExp(r'</html>', caseSensitive: false),
    );
    var cleaned = htmlCloseIdx != -1
        ? html.substring(0, htmlCloseIdx + 7) // Keep </html>
        : html;

    cleaned = cleaned.replaceAll(RegExp(r'\{\{\s*unsubscribe\s*\}\}'), '');

    cleaned = cleaned.replaceAll(
      RegExp(
        r'<a[^>]*href\s*=\s*"[^"]*\{\{\s*unsubscribe\s*\}\}[^"]*"[^>]*>.*?</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    if (!cleaned.toLowerCase().contains('name="viewport"') &&
        !cleaned.toLowerCase().contains("name='viewport'")) {
      final headIdx = cleaned.indexOf(
        RegExp(r'<head[^>]*>', caseSensitive: false),
      );
      if (headIdx != -1) {
        final headEnd = cleaned.indexOf('>', headIdx) + 1;
        cleaned =
            '${cleaned.substring(0, headEnd)}'
            '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">'
            '${cleaned.substring(headEnd)}';
      }
    }

    final headCloseIdx = cleaned.indexOf(
      RegExp(r'</head>', caseSensitive: false),
    );
    if (headCloseIdx != -1) {
      cleaned =
          '${cleaned.substring(0, headCloseIdx)}'
          '<style>body, table { max-width: 100% !important; width: 100% !important; } '
          'img { max-width: 100% !important; height: auto !important; } '
          'td { word-break: break-word; }</style>'
          '${cleaned.substring(headCloseIdx)}';
    }

    return cleaned;
  }

  /// Remove Brevo variables from simple HTML (visual editor output)
  String _cleanSimpleHtml(String html) {
    var cleaned = html;
    cleaned = cleaned.replaceAll(
      RegExp(
        r'<br\s*/?>?\s*<hr[^>]*>\s*<p[^>]*>.*?\{\{\s*unsubscribe\s*\}\}.*?</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\{\{\s*unsubscribe\s*\}\}'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'(<hr[^>]*>\s*|<p>\s*</p>\s*|<br\s*/?>)*$', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  void _initWebView(String htmlContent) {
    try {
      final controller = WebViewController();
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) async {
              try {
                final height = await controller.runJavaScriptReturningResult(
                  'document.documentElement.scrollHeight',
                );
                final h = double.tryParse(height.toString()) ?? 400;
                if (mounted && h > 0) {
                  setState(() {
                    _webViewHeight = h + 16;
                    _webViewReady = true;
                  });
                }
              } catch (e) {
                appLogger.e('WebView height error: $e');
                if (mounted) {
                  setState(() {
                    _webViewReady = true;
                  });
                }
              }
            },
            onNavigationRequest: (request) {
              if (request.url.startsWith('http')) {
                _launchUrl(request.url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadHtmlString(htmlContent);

      _webViewController = controller;
    } catch (e) {
      appLogger.e('WebView init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.newsletterData['subject'] as String? ?? '';
    final htmlContent = widget.newsletterData['html_content'] as String? ?? '';
    final senderName =
        widget.newsletterData['sender_name'] as String? ?? 'Lectio Divina';
    final sentAt = _formatDate(
      widget.newsletterData['sent_at'] as String?,
      context,
    );

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
              child: _isFullDocument
                  ? _buildWebViewBody(subject, senderName, sentAt)
                  : _buildSimpleBody(subject, senderName, sentAt, htmlContent),
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
              tr('newsletter_detail'),
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

  /// Full HTML email — rendered in WebView
  Widget _buildWebViewBody(String subject, String senderName, String sentAt) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(subject, senderName, sentAt),
          if (_webViewController != null)
            SizedBox(
              height: _webViewHeight,
              child: Stack(
                children: [
                  WebViewWidget(controller: _webViewController!),
                  if (!_webViewReady)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// Simple HTML (visual editor) — rendered with flutter_html
  Widget _buildSimpleBody(
    String subject,
    String senderName,
    String sentAt,
    String htmlContent,
  ) {
    final displayContent = _cleanSimpleHtml(htmlContent);
    final hasContent =
        displayContent.isNotEmpty &&
        displayContent.replaceAll(RegExp(r'<[^>]*>'), '').trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(subject, senderName, sentAt),
          if (!hasContent)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  tr('newsletter_empty'),
                  style: TextStyle(color: HomeV2.textMuted(context)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Html(
                data: displayContent,
                onLinkTap: (url, _, _) {
                  if (url != null) _launchUrl(url);
                },
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
                    margin: Margins.only(top: 0, bottom: 8),
                  ),
                  "h1": Style(
                    fontSize: FontSize(22),
                    fontWeight: FontWeight.bold,
                  ),
                  "h2": Style(
                    fontSize: FontSize(20),
                    fontWeight: FontWeight.bold,
                  ),
                  "a": Style(
                    color: HomeV2.primary,
                    textDecoration: TextDecoration.underline,
                  ),
                  "blockquote": Style(
                    padding: HtmlPaddings.only(left: 12),
                    border: const Border(
                      left: BorderSide(color: HomeV2.primary, width: 3),
                    ),
                    fontStyle: FontStyle.italic,
                  ),
                },
              ),
            ),
          SizedBox(
            height: MediaQuery.of(context).viewPadding.bottom + AppSpacing.xl,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String subject, String senderName, String sentAt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject,
            style: HomeV2.serifTitle(context, size: 25, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 15,
                color: HomeV2.textMuted(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  sentAt.isNotEmpty ? '$senderName · $sentAt' : senderName,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: HomeV2.textMuted(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.10)),
        ],
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

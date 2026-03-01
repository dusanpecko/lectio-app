import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_spacing.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import 'newsletter_detail_screen.dart';

class NewsletterListScreen extends StatefulWidget {
  const NewsletterListScreen({super.key});

  @override
  State<NewsletterListScreen> createState() => _NewsletterListScreenState();
}

class _NewsletterListScreenState extends State<NewsletterListScreen> {
  List<Map<String, dynamic>> newsletters = [];
  bool isLoading = true;
  String? errorMessage;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _fetchNewsletters();
      _initialized = true;
    }
  }

  Future<void> _fetchNewsletters() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final locale = context.locale.languageCode;

      appLogger.d('Fetching newsletters for lang=$locale');

      final response = await supabase
          .from('newsletter_campaigns')
          .select(
            'id, name, subject, html_content, sender_name, sent_at, created_at, language',
          )
          .eq('status', 'sent')
          .eq('language', locale)
          .order('sent_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        newsletters = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e, stacktrace) {
      appLogger.e('fetchNewsletters error: $e');
      appLogger.d('Stacktrace: $stacktrace');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = tr('newsletter_load_failed');
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d. MMMM yyyy', context.locale.toString()).format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('newsletter_title'))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red.shade400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _fetchNewsletters,
                    icon: const Icon(Icons.refresh),
                    label: Text(tr('common.try_again')),
                  ),
                ],
              ),
            )
          : newsletters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: AppColors.adaptiveCardSubtitle(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    tr('newsletter_empty'),
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: AppColors.adaptiveCardSubtitle(context),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNewsletters,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: newsletters.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final newsletter = newsletters[index];
                  final subject = newsletter['subject'] as String? ?? '';
                  final sentAt = _formatDate(newsletter['sent_at'] as String?);
                  final senderName =
                      newsletter['sender_name'] as String? ?? 'Lectio Divina';

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: AppElevation.medium,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewsletterDetailScreen(
                              newsletterData: newsletter,
                            ),
                            settings: const RouteSettings(
                              name: '/newsletter-detail',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            // Mail icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Icon(
                                Icons.mail_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: theme.textTheme.titleSmall!.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        senderName,
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(
                                              color:
                                                  AppColors.adaptiveCardSubtitle(
                                                    context,
                                                  ),
                                            ),
                                      ),
                                      if (sentAt.isNotEmpty) ...[
                                        Text(
                                          ' · ',
                                          style: theme.textTheme.bodySmall!
                                              .copyWith(
                                                color:
                                                    AppColors.adaptiveCardSubtitle(
                                                      context,
                                                    ),
                                              ),
                                        ),
                                        Text(
                                          sentAt,
                                          style: theme.textTheme.bodySmall!
                                              .copyWith(
                                                color:
                                                    AppColors.adaptiveCardSubtitle(
                                                      context,
                                                    ),
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Arrow
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.adaptiveCardSubtitle(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

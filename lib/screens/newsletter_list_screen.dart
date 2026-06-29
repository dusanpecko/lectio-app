import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
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
              if (newsletters.isNotEmpty)
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: _fetchNewsletters,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('newsletter_title'),
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
          onPressed: _fetchNewsletters,
          icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
          label: Text(
            tr('common.try_again'),
            style: TextStyle(color: HomeV2.primary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (newsletters.isEmpty) {
      return _buildMessage(Icons.mail_outline_rounded, tr('newsletter_empty'));
    }
    return RefreshIndicator(
      onRefresh: _fetchNewsletters,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        itemCount: newsletters.length,
        itemBuilder: (context, index) => _buildCard(newsletters[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> newsletter) {
    final subject = newsletter['subject'] as String? ?? '';
    final sentAt = _formatDate(newsletter['sent_at'] as String?);
    final senderName = newsletter['sender_name'] as String? ?? 'Lectio Divina';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NewsletterDetailScreen(newsletterData: newsletter),
                settings: const RouteSettings(name: '/newsletter-detail'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: HomeV2.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.mail_rounded,
                    color: HomeV2.iconAccent(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: HomeV2.textDark(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sentAt.isNotEmpty ? '$senderName · $sentAt' : senderName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: HomeV2.textMuted(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
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

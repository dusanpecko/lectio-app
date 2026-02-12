import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';

/// Model pre notifikáciu z databázy
class NotificationLog {
  final String id;
  final String title;
  final String body;
  final String topic;
  final DateTime sentAt;
  final String? imageUrl;
  final int subscriberCount;

  NotificationLog({
    required this.id,
    required this.title,
    required this.body,
    required this.topic,
    required this.sentAt,
    this.imageUrl,
    this.subscriberCount = 0,
  });

  factory NotificationLog.fromJson(Map<String, dynamic> json) {
    return NotificationLog(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      topic: json['topic'] as String? ?? '',
      sentAt: DateTime.parse(json['sent_at'] as String),
      imageUrl: json['image_url'] as String?,
      subscriberCount: json['subscriber_count'] as int? ?? 0,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationLog> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _fetchNotifications();
      _initialized = true;
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final locale = context.locale.languageCode;

      // Mapovanie jazyka na locale_id (hardcoded pre výkon a bez RLS problémov)
      // sk = 1, en = 2, es = 3
      final localeIdMap = {'sk': 1, 'en': 2, 'es': 3};
      final localeId = localeIdMap[locale] ?? 1; // Default: slovenčina

      // Načítaj notifikácie pre daný jazyk, zoradené od najnovších
      final response = await supabase
          .from('notification_logs')
          .select(
            'id, title, body, topic, sent_at, image_url, subscriber_count',
          )
          .eq('locale_id', localeId)
          .order('sent_at', ascending: false)
          .limit(50);

      final notifications = (response as List)
          .map((json) => NotificationLog.fromJson(json))
          .toList();

      appLogger.i(
        'Loaded ${notifications.length} notifications for locale $locale',
      );

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      appLogger.e('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = tr('notifications.load_error');
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchNotifications();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Dnes - zobraz čas
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return tr('notifications.yesterday');
    } else if (difference.inDays < 7) {
      // Tento týždeň - zobraz deň
      return DateFormat('EEEE', context.locale.languageCode).format(date);
    } else {
      // Staršie - zobraz dátum
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  IconData _getTopicIcon(String topic) {
    if (topic.contains('lectio')) return Icons.book;
    if (topic.contains('prayer')) return Icons.favorite;
    if (topic.contains('news')) return Icons.newspaper;
    if (topic.contains('exercise')) return Icons.self_improvement;
    if (topic.contains('rosary')) return Icons.circle_outlined;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('notifications.title')),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
              tooltip: tr('common.refresh'),
            ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _fetchNotifications,
              icon: const Icon(Icons.refresh),
              label: Text(tr('common.try_again')),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tr('notifications.empty'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('notifications.empty_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 72,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationTile(notification, theme, isDark);
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    NotificationLog notification,
    ThemeData theme,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: _buildLeadingWidget(notification, isDark),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(
            notification.body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _formatDate(notification.sentAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _showNotificationDetail(notification),
    );
  }

  Widget _buildLeadingWidget(NotificationLog notification, bool isDark) {
    if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: CachedNetworkImage(
            imageUrl: notification.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Icon(
                _getTopicIcon(notification.topic),
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(_getTopicIcon(notification.topic), color: AppColors.primary),
    );
  }

  void _showNotificationDetail(NotificationLog notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _NotificationDetailSheet(notification: notification),
    );
  }
}

/// Bottom sheet pre detail notifikácie
class _NotificationDetailSheet extends StatelessWidget {
  final NotificationLog notification;

  const _NotificationDetailSheet({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Obrázok ak existuje
                if (notification.imageUrl != null &&
                    notification.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CachedNetworkImage(
                      imageUrl: notification.imageUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Titulok
                Text(
                  notification.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Dátum
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(notification.sentAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Telo notifikácie
                Text(
                  notification.body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Zatvoriť tlačidlo
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('common.close')),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}

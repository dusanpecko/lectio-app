import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/notification_controller.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

/// Model pre notifikáciu z databázy
class NotificationLog {
  final String id;
  final String title;
  final String body;
  final String topic;
  final DateTime sentAt;
  final String? imageUrl;
  final int subscriberCount;
  /// Deep link (rovnaké kľúče ako push) — z histórie sa dá otvoriť cieľ.
  final String? screen;
  final String? screenParams;

  NotificationLog({
    required this.id,
    required this.title,
    required this.body,
    required this.topic,
    required this.sentAt,
    this.imageUrl,
    this.subscriberCount = 0,
    this.screen,
    this.screenParams,
  });

  bool get hasTarget => screen != null && screen!.isNotEmpty;

  factory NotificationLog.fromJson(Map<String, dynamic> json) {
    return NotificationLog(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      topic: json['topic'] as String? ?? '',
      sentAt: DateTime.parse(json['sent_at'] as String),
      imageUrl: json['image_url'] as String?,
      subscriberCount: json['subscriber_count'] as int? ?? 0,
      screen: json['screen'] as String?,
      screenParams: json['screen_params'] as String?,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _readIdsKey = 'notifications_read_ids';
  static const _readBaselineKey = 'notifications_read_baseline';
  static const _fallbackLocaleIds = {'sk': 1, 'en': 2, 'es': 4, 'fr': 7};
  static Map<String, int>? _localeIdCache;

  List<NotificationLog> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialized = false;

  // Stav „prečítané" je lokálny (SharedPreferences): ID otvorených + baseline —
  // všetko odoslané pred prvým otvorením tejto verzie sa berie ako prečítané,
  // nech používateľ po update nevidí 50 „nových".
  Set<String> _readIds = {};
  DateTime? _readBaseline;

  bool _isRead(NotificationLog n) {
    if (_readIds.contains(n.id)) return true;
    final baseline = _readBaseline;
    return baseline != null && !n.sentAt.isAfter(baseline);
  }

  int get _unreadCount => _notifications.where((n) => !_isRead(n)).length;

  Future<void> _loadReadState() async {
    final prefs = await SharedPreferences.getInstance();
    var baselineStr = prefs.getString(_readBaselineKey);
    if (baselineStr == null) {
      baselineStr = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_readBaselineKey, baselineStr);
    }
    _readIds = (prefs.getStringList(_readIdsKey) ?? const []).toSet();
    _readBaseline = DateTime.tryParse(baselineStr);
  }

  Future<void> _markRead(NotificationLog n) async {
    if (_isRead(n)) return;
    setState(() => _readIds.add(n.id));
    final prefs = await SharedPreferences.getInstance();
    final list = _readIds.toList();
    // Strop — staršie položky aj tak padnú pod baseline.
    await prefs.setStringList(
      _readIdsKey,
      list.length > 200 ? list.sublist(list.length - 200) : list,
    );
  }

  Future<void> _markAllRead() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now().toUtc();
    setState(() {
      _readBaseline = now;
      _readIds = {};
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readBaselineKey, now.toIso8601String());
    await prefs.setStringList(_readIdsKey, const []);
  }

  /// code → locale_id z tabuľky `locales` (cache na dobu behu); pri zlyhaní
  /// pôvodná pevná mapa. Predtým bola mapa natvrdo a nový jazyk by potichu
  /// spadol na slovenčinu.
  Future<Map<String, int>> _loadLocaleIds(SupabaseClient supabase) async {
    final cached = _localeIdCache;
    if (cached != null) return cached;
    try {
      final rows = await supabase.from('locales').select('id, code');
      final map = <String, int>{};
      for (final row in rows as List) {
        final code = row['code'] as String?;
        final id = row['id'];
        if (code != null && id is int) map[code] = id;
      }
      if (map.isNotEmpty) {
        _localeIdCache = map;
        return map;
      }
    } catch (e) {
      appLogger.w('locales fetch failed, using fallback map: $e');
    }
    return _fallbackLocaleIds;
  }

  /// Otvorí cieľ notifikácie (deep link) cez spoločný register obrazoviek.
  void _openTarget(NotificationLog n) {
    if (!n.hasTarget) return;
    NotificationController.instance.navigateToScreen(
      n.screen!,
      screenParams: n.screenParams,
    );
  }

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
      final userId = supabase.auth.currentUser?.id;

      await _loadReadState();

      final localeIdMap = await _loadLocaleIds(supabase);
      // Appka používa 'cs', DB kód je 'cz'.
      final localeId =
          localeIdMap[locale] ?? localeIdMap[locale == 'cs' ? 'cz' : locale] ?? 1;

      // Načítaj broadcast notifikácie pre daný jazyk
      final broadcastResponse = await supabase
          .from('notification_logs')
          .select(
            'id, title, body, topic, sent_at, image_url, subscriber_count, screen, screen_params',
          )
          .eq('locale_id', localeId)
          .eq('is_targeted', false)
          .order('sent_at', ascending: false)
          .limit(50);

      final broadcastNotifications = (broadcastResponse as List)
          .map((json) => NotificationLog.fromJson(json))
          .toList();

      // Načítaj targeted notifikácie pre aktuálneho usera (cez RLS)
      List<NotificationLog> targetedNotifications = [];
      if (userId != null) {
        final targetedResponse = await supabase
            .from('notification_logs')
            .select(
              'id, title, body, topic, sent_at, image_url, subscriber_count, screen, screen_params',
            )
            .eq('is_targeted', true)
            .order('sent_at', ascending: false)
            .limit(20);

        targetedNotifications = (targetedResponse as List)
            .map((json) => NotificationLog.fromJson(json))
            .toList();
      }

      // Zlúčiť a zoradiť podľa dátumu
      final allNotifications = [
        ...broadcastNotifications,
        ...targetedNotifications,
      ];
      allNotifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      final notifications = allNotifications.take(50).toList();

      appLogger.i(
        'Loaded ${notifications.length} notifications (${broadcastNotifications.length} broadcast, ${targetedNotifications.length} targeted) for locale $locale',
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
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return tr('notifications.yesterday');
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', context.locale.languageCode).format(date);
    } else {
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  IconData _getTopicIcon(String topic) {
    if (topic.contains('lectio')) return Icons.menu_book_rounded;
    if (topic.contains('prayer')) return Icons.favorite_rounded;
    if (topic.contains('news')) return Icons.campaign_rounded;
    if (topic.contains('exercise')) return Icons.auto_awesome_rounded;
    if (topic.contains('rosary')) return Icons.brightness_7_rounded;
    return Icons.notifications_rounded;
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

  // ── Hero ──────────────────────────────────────────────────────────────────
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
              if (_unreadCount > 0) ...[
                Tooltip(
                  message: tr('notifications.mark_all_read'),
                  child: _CircleButton(
                    icon: Icons.done_all_rounded,
                    onTap: _markAllRead,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (_notifications.isNotEmpty)
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: _onRefresh,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('notifications.title'),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildMessage(
        Icons.cloud_off_rounded,
        _errorMessage!,
        action: TextButton.icon(
          onPressed: _fetchNotifications,
          icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
          label: Text(
            tr('common.try_again'),
            style: TextStyle(color: HomeV2.primary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return _buildMessage(
        Icons.notifications_none_rounded,
        tr('notifications.empty_hint'),
        title: tr('notifications.empty'),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        itemCount: _notifications.length,
        itemBuilder: (context, index) =>
            _buildNotificationCard(_notifications[index]),
      ),
    );
  }

  // ── Karta notifikácie ─────────────────────────────────────────────────────
  Widget _buildNotificationCard(NotificationLog n) {
    final unread = !_isRead(n);
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
            _markRead(n);
            _showNotificationDetail(n);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeading(n),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unread)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, right: 6),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: HomeV2.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: HomeV2.textDark(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: HomeV2.textMuted(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: HomeV2.textMuted(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(n.sentAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HomeV2.textMuted(context),
                            ),
                          ),
                          if (n.hasTarget) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 13,
                              color: HomeV2.iconAccent(context),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(NotificationLog n) {
    const size = 52.0;
    Widget iconFallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(_getTopicIcon(n.topic), color: HomeV2.iconAccent(context)),
        );

    if (n.imageUrl != null && n.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CachedNetworkImage(
          imageUrl: n.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => iconFallback(),
          errorWidget: (_, _, _) => iconFallback(),
        ),
      );
    }
    return iconFallback();
  }

  // ── Stavy ─────────────────────────────────────────────────────────────────
  Widget _buildMessage(
    IconData icon,
    String message, {
    String? title,
    Widget? action,
  }) {
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
            if (title != null) ...[
              Text(
                title,
                style: HomeV2.serifTitle(context, size: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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

  void _showNotificationDetail(NotificationLog notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationDetailSheet(
        notification: notification,
        onOpen: notification.hasTarget ? () => _openTarget(notification) : null,
      ),
    );
  }
}

/// Bottom sheet pre detail notifikácie
class _NotificationDetailSheet extends StatelessWidget {
  final NotificationLog notification;
  /// Otvorí cieľ deep linku (null = notifikácia cieľ nemá).
  final VoidCallback? onOpen;

  const _NotificationDetailSheet({required this.notification, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeV2.background(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HomeV2.radius + 6),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HomeV2.textMuted(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (notification.imageUrl != null &&
                    notification.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                    child: CachedNetworkImage(
                      imageUrl: notification.imageUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 180,
                        color: HomeV2.primary.withValues(alpha: 0.08),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 180,
                        color: HomeV2.primary.withValues(alpha: 0.08),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  notification.title,
                  style: HomeV2.serifTitle(context, size: 24, height: 1.2),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: HomeV2.textMuted(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(notification.sentAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  notification.body,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.65,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (onOpen != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Najprv zavri sheet, potom naviguj cez root navigator.
                        Navigator.of(context).pop();
                        onOpen!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        tr('notifications.open_target'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(
                  width: double.infinity,
                  child: onOpen != null
                      ? TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: HomeV2.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                          ),
                          child: Text(
                            tr('common.close'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HomeV2.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                          child: Text(
                            tr('common.close'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/notification_models.dart';
import '../services/fcm_service.dart';
import '../services/local_notifications_service.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  final _logger = appLogger;
  final FcmService _fcmService = FcmService.instance;
  final LocalNotificationsService _localNotifications =
      LocalNotificationsService.instance;

  static const Color _danger = Color(0xFFC0392B);
  static const Color _success = Color(0xFF2E9E5B);

  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  NotificationPreferencesResponse? _preferencesData;
  final Map<String, bool> _pendingChanges = {};

  // Lokálne notifikácie state
  bool _dailyLectioEnabled = false;
  bool _prayerReminderEnabled = false;
  TimeOfDay? _prayerReminderTime;
  TimeOfDay? _dailyLectioTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotificationSettings(forceRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Po návrate zo systémových nastavení (kde mohol povolenie zapnúť) znova
    // over stav — len ak doteraz povolené nebolo, nech zbytočne nereloadujeme.
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _initializeNotificationSettings(forceRefresh: true);
    }
  }

  void _snack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  Future<void> _initializeNotificationSettings({
    bool forceRefresh = false,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasPermission = await _fcmService.hasNotificationPermissions();
      setState(() => _hasPermission = hasPermission);

      if (!hasPermission) {
        setState(() => _isLoading = false);
        return;
      }

      await _localNotifications.initialize();

      if (forceRefresh) {
        _logger.i('🔄 Force refreshing notification preferences from database');
      }

      final preferencesData = await _fcmService.getNotificationPreferences(
        forceRefresh: forceRefresh,
      );

      final localSettings = await _localNotifications.getSettings();

      final preferredLectioTime = await _fcmService.getPreferredLectioTime();

      setState(() {
        _preferencesData = preferencesData;
        _dailyLectioEnabled = _isDailyReadingsTopicEnabled(preferencesData);
        _prayerReminderEnabled =
            localSettings['prayer_reminder_enabled'] ?? false;
        _prayerReminderTime = localSettings['prayer_reminder_time'];
        _dailyLectioTime = preferredLectioTime;
        _isLoading = false;
      });

      if (preferencesData == null) {
        setState(() {
          _errorMessage = 'notifications.error.failed_to_load'.tr();
        });
      }
    } catch (e) {
      _logger.e('Error initializing notification settings: $e');
      setState(() {
        _errorMessage = 'notifications.error.initialization_failed'.tr();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await _fcmService.requestNotificationPermissions();

      if (!mounted) return;

      if (granted) {
        setState(() => _hasPermission = true);
        _initializeNotificationSettings();
      } else {
        // Po predošlom zamietnutí OS dialóg už nezobrazí — pošli usera do
        // systémových nastavení, nech povolenie zapne ručne.
        final blocked = await _fcmService.isNotificationPermissionBlocked();
        if (!mounted) return;
        if (blocked) {
          _showOpenSettingsDialog();
        } else {
          _snack('notifications.error.permission_denied'.tr(), isError: true);
        }
      }
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      _snack('notifications.error.permission_request_failed'.tr(),
          isError: true);
    }
  }

  Future<void> _showOpenSettingsDialog() async {
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        title: Text('notifications.permission.blocked_title'.tr()),
        content: Text('notifications.permission.blocked_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('notifications.permission.open_settings'.tr()),
          ),
        ],
      ),
    );
    if (open == true) {
      await _fcmService.openSystemNotificationSettings();
    }
  }

  void _onTopicChanged(String topicId, bool isEnabled) {
    setState(() {
      _pendingChanges[topicId] = isEnabled;
    });
  }

  Future<void> _saveChanges() async {
    if (_pendingChanges.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      final success = await _fcmService.updateMultipleTopicPreferences(
        _pendingChanges,
      );

      if (success) {
        setState(() {
          _pendingChanges.clear();
        });

        await _initializeNotificationSettings(forceRefresh: true);

        if (mounted) {
          _snack('notifications.success.preferences_saved'.tr(),
              isError: false);
        }
      } else {
        throw Exception('Failed to save preferences');
      }
    } catch (e) {
      _logger.e('Error saving notification preferences: $e');
      if (mounted) {
        _snack('notifications.error.save_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Lokálne notifikácie handlers

  bool _isDailyReadingsTopicEnabled(NotificationPreferencesResponse? prefs) {
    if (prefs == null) return true;
    final topicId = _getDailyReadingsTopicId(prefs);
    if (topicId == null) return true;
    return prefs.isTopicEnabled(topicId);
  }

  String? _getDailyReadingsTopicId(NotificationPreferencesResponse? prefs) {
    if (prefs == null) return null;
    try {
      final topic = prefs.topics.firstWhere((t) => t.slug == 'daily-readings');
      return topic.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onDailyLectioChanged(bool enabled) async {
    try {
      final topicId = _getDailyReadingsTopicId(_preferencesData);
      if (topicId == null) {
        _logger.w('⚠️ daily-readings topic not found');
        return;
      }

      final success = await _fcmService.updateTopicPreference(topicId, enabled);
      if (!success) throw Exception('Failed to update topic preference');

      setState(() => _dailyLectioEnabled = enabled);

      if (!mounted) return;
      _snack(
        enabled
            ? 'notifications.local.daily_lectio_enabled'.tr()
            : 'notifications.local.daily_lectio_disabled'.tr(),
        isError: false,
      );
    } catch (e) {
      _logger.e('Error toggling daily lectio: $e');
      if (!mounted) return;
      _snack('notifications.local.daily_lectio_error'.tr(), isError: true);
    }
  }

  Future<void> _onDailyLectioTimeChanged() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dailyLectioTime ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      final roundedTime = TimeOfDay(hour: picked.hour, minute: 0);

      try {
        final success = await _fcmService.updatePreferredLectioTime(
          roundedTime,
        );
        if (!success) throw Exception('Failed to update preferred lectio time');

        setState(() {
          _dailyLectioTime = roundedTime;
        });

        if (!mounted) return;
        _snack(
          'notifications.local.daily_lectio_time_set'
              .tr(args: ['${roundedTime.hour}:00']),
          isError: false,
        );
      } catch (e) {
        _logger.e('Error setting daily lectio time: $e');
        if (!mounted) return;
        _snack('notifications.local.daily_lectio_error'.tr(), isError: true);
      }
    }
  }

  Future<void> _onPrayerReminderTimeChanged() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _prayerReminderTime ?? const TimeOfDay(hour: 18, minute: 0),
    );

    if (picked != null) {
      try {
        if (!_prayerReminderEnabled) {
          _logger.i('🔔 Requesting battery optimization exemption...');
          await _localNotifications.requestIgnoreBatteryOptimizations();

          _logger.i('🔔 Requesting exact alarm permission...');
          await _localNotifications.requestExactAlarmPermission();
        }

        await _localNotifications.setPrayerReminderTime(picked);
        setState(() {
          _prayerReminderTime = picked;
          _prayerReminderEnabled = true;
        });

        if (!mounted) return;
        _snack(
          'notifications.local.prayer_enabled'.tr(args: [
            '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}',
          ]),
          isError: false,
        );
      } catch (e) {
        _logger.e('Error setting prayer reminder: $e');
        if (!mounted) return;
        _snack('notifications.local.prayer_error'.tr(), isError: true);
      }
    }
  }

  Future<void> _onPrayerReminderDisabled() async {
    try {
      await _localNotifications.setPrayerReminderTime(null);
      setState(() {
        _prayerReminderEnabled = false;
        _prayerReminderTime = null;
      });

      if (!mounted) return;
      _snack('notifications.local.prayer_disabled'.tr(), isError: false);
    } catch (e) {
      _logger.e('Error disabling prayer reminder: $e');
    }
  }

  /// Konvertuje názov Lucide ikony na emoji
  String _getIconEmoji(String? icon) {
    if (icon == null) return '🔔';
    if (icon.runes.any((rune) => rune > 127)) {
      return icon;
    }
    const iconMap = {
      'book-open': '📖',
      'bell': '🔔',
      'hands-praying': '🙏',
      'rosary': '📿',
      'calendar': '📅',
      'star': '⭐',
      'heart': '❤️',
      'church': '⛪',
      'cross': '✝️',
      'bible': '📜',
      'candle': '🕯️',
      'dove': '🕊️',
      'book': '📚',
      'scroll': '📜',
      'pray': '🙏',
      'news': '📰',
      'info': 'ℹ️',
      'sparkles': '✨',
    };
    return iconMap[icon.toLowerCase()] ?? '🔔';
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasPermission
                      ? _buildPermissionRequest()
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _buildTopicsSection(),
            ),
          ],
        ),
        floatingActionButton: _pendingChanges.isNotEmpty && _hasPermission
            ? FloatingActionButton.extended(
                onPressed: _isLoading ? null : _saveChanges,
                backgroundColor: HomeV2.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  'notifications.action.save_changes'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
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
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'notifications.title'.tr(),
            style: HomeV2.serifTitle(context, size: 28, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Stavy ─────────────────────────────────────────────────────────────────
  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_off_rounded,
                  size: 52, color: HomeV2.iconAccent(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'notifications.permission.title'.tr(),
              style: HomeV2.serifTitle(context, size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'notifications.permission.description'.tr(),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.notifications_active_rounded, size: 20),
              label: Text(
                'notifications.permission.request'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeV2.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 52, color: _danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'notifications.error.title'.tr(),
              style: HomeV2.serifTitle(context, size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage ?? 'notifications.error.unknown'.tr(),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: _initializeNotificationSettings,
              icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
              label: Text(
                'notifications.action.retry'.tr(),
                style: TextStyle(
                    color: HomeV2.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sekcie ──────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        text,
        style: HomeV2.serifTitle(context, size: 19),
      ),
    );
  }

  Widget _categoryTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: HomeV2.textMuted(context),
        ),
      ),
    );
  }

  Widget _tile({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget trailing,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
        border: highlight
            ? Border.all(color: HomeV2.primary.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ),
    );
  }

  Widget _v2Switch(bool value, ValueChanged<bool>? onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: HomeV2.primary,
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? HomeV2.iconAccent(context)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLocalNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('notifications.local.section_title'.tr()),
        _tile(
          emoji: '📖',
          title: 'notifications.local.daily_lectio_title'.tr(),
          subtitle: _dailyLectioEnabled && _dailyLectioTime != null
              ? 'notifications.local.daily_lectio_time_subtitle'
                  .tr(args: ['${_dailyLectioTime!.hour}:00'])
              : 'notifications.local.daily_lectio_subtitle'.tr(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dailyLectioEnabled)
                _iconBtn(Icons.access_time_rounded, _onDailyLectioTimeChanged),
              _v2Switch(
                _dailyLectioEnabled,
                _isLoading ? null : (v) => _onDailyLectioChanged(v),
              ),
            ],
          ),
        ),
        _tile(
          emoji: '🙏',
          title: 'notifications.local.prayer_title'.tr(),
          subtitle: _prayerReminderEnabled && _prayerReminderTime != null
              ? 'notifications.local.prayer_subtitle_set'.tr(args: [
                  '${_prayerReminderTime!.hour}:${_prayerReminderTime!.minute.toString().padLeft(2, '0')}',
                ])
              : 'notifications.local.prayer_subtitle_unset'.tr(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_prayerReminderEnabled)
                _iconBtn(
                    Icons.access_time_rounded, _onPrayerReminderTimeChanged),
              _v2Switch(
                _prayerReminderEnabled,
                _isLoading
                    ? null
                    : (v) => v
                        ? _onPrayerReminderTimeChanged()
                        : _onPrayerReminderDisabled(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopicTile(NotificationTopic topic) {
    final currentLanguage = context.locale.languageCode;
    final topicName = topic.getNameByLanguage(currentLanguage);

    bool isEnabled;
    if (_pendingChanges.containsKey(topic.id)) {
      isEnabled = _pendingChanges[topic.id]!;
    } else {
      isEnabled = _preferencesData?.isTopicEnabled(topic.id) ?? false;
    }

    final hasChanges = _pendingChanges.containsKey(topic.id);

    return _tile(
      emoji: _getIconEmoji(topic.emoji),
      title: topicName,
      subtitle: 'notifications.category.${topic.category}'.tr(),
      highlight: hasChanges,
      trailing: _v2Switch(
        isEnabled,
        _isLoading ? null : (value) => _onTopicChanged(topic.id, value),
      ),
    );
  }

  Widget _buildTopicsSection() {
    if (_preferencesData == null) {
      return const SizedBox.shrink();
    }

    final groupedTopics = NotificationApiHelper.groupTopicsByCategory(
      _preferencesData!.topics.where((topic) => topic.isActive).toList(),
    );

    return RefreshIndicator(
      onRefresh: () => _initializeNotificationSettings(forceRefresh: true),
      color: HomeV2.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 96,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'notifications.settings.description'.tr(),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
          ),
          _buildLocalNotificationsSection(),
          _sectionTitle('notifications.remote.section_title'.tr()),
          ...groupedTopics.entries.map((categoryEntry) {
            final category = categoryEntry.key;
            final topics = categoryEntry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _categoryTitle('notifications.category.${category.value}'.tr()),
                ...topics.map(_buildTopicTile),
              ],
            );
          }),
        ],
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

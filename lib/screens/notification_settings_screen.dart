import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/notification_models.dart';
import '../services/fcm_service.dart';
import '../services/local_notifications_service.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _logger = appLogger;
  final FcmService _fcmService = FcmService.instance;
  final LocalNotificationsService _localNotifications =
      LocalNotificationsService.instance;

  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  NotificationPreferencesResponse? _preferencesData;
  final Map<String, bool> _pendingChanges = {};

  // Lokálne notifikácie state
  bool _dailyLectioEnabled = false;
  bool _prayerReminderEnabled = false;
  TimeOfDay? _prayerReminderTime;

  @override
  void initState() {
    super.initState();
    // Always force refresh when opening this screen to get latest data
    _initializeNotificationSettings(forceRefresh: true);
  }

  Future<void> _initializeNotificationSettings({
    bool forceRefresh = false,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Skontroluj povolenia
      final hasPermission = await _fcmService.hasNotificationPermissions();
      setState(() => _hasPermission = hasPermission);

      if (!hasPermission) {
        setState(() => _isLoading = false);
        return;
      }

      // Inicializuj lokálne notifikácie
      await _localNotifications.initialize();

      // Force clear cache if requested (to sync with web changes)
      if (forceRefresh) {
        _logger.i('🔄 Force refreshing notification preferences from database');
      }

      // Načítaj FCM notification preferences
      final preferencesData = await _fcmService.getNotificationPreferences(
        forceRefresh: forceRefresh,
      );

      // Načítaj lokálne nastavenia
      final localSettings = await _localNotifications.getSettings();

      setState(() {
        _preferencesData = preferencesData;
        _dailyLectioEnabled = localSettings['daily_lectio_enabled'] ?? false;
        _prayerReminderEnabled =
            localSettings['prayer_reminder_enabled'] ?? false;
        _prayerReminderTime = localSettings['prayer_reminder_time'];
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('notifications.error.permission_denied'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.error.permission_request_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
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
        // Clear pending changes
        setState(() {
          _pendingChanges.clear();
        });

        // Refresh data from database to ensure sync
        await _initializeNotificationSettings(forceRefresh: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('notifications.success.preferences_saved'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to save preferences');
      }
    } catch (e) {
      _logger.e('Error saving notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('notifications.error.save_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Lokálne notifikácie handlers
  Future<void> _onDailyLectioChanged(bool enabled) async {
    try {
      // 🔥 NOVÉ: Pri zapnutí notifikácií požiadaj o potrebné povolenia
      if (enabled) {
        _logger.i('🔔 Requesting battery optimization exemption...');
        await _localNotifications.requestIgnoreBatteryOptimizations();

        _logger.i('🔔 Requesting exact alarm permission...');
        await _localNotifications.requestExactAlarmPermission();
      }

      await _localNotifications.setDailyLectioEnabled(enabled);
      setState(() => _dailyLectioEnabled = enabled);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Denné lectio notifikácie zapnuté (9:00)'
                : 'Denné lectio notifikácie vypnuté',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error toggling daily lectio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chyba pri nastavovaní denných notifikácií'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onPrayerReminderTimeChanged() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _prayerReminderTime ?? const TimeOfDay(hour: 18, minute: 0),
    );

    if (picked != null) {
      try {
        // 🔥 NOVÉ: Pri zapnutí notifikácií požiadaj o potrebné povolenia
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pripomenutie modlitby nastavené na ${picked.hour}:${picked.minute.toString().padLeft(2, '0')}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _logger.e('Error setting prayer reminder: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chyba pri nastavovaní pripomenutia'),
            backgroundColor: Colors.red,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pripomenutie modlitby vypnuté'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error disabling prayer reminder: $e');
    }
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'notifications.permission.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'notifications.permission.description'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.notifications_active),
              label: Text('notifications.permission.request'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'notifications.error.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'notifications.error.unknown'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeNotificationSettings,
              icon: const Icon(Icons.refresh),
              label: Text('notifications.action.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicTile(NotificationTopic topic) {
    final currentLanguage = context.locale.languageCode;
    final topicName = topic.getNameByLanguage(currentLanguage);

    // Získaj aktuálnu hodnotu (buď z pending changes alebo z existujúcich preferencií)
    bool isEnabled;
    if (_pendingChanges.containsKey(topic.id)) {
      isEnabled = _pendingChanges[topic.id]!;
    } else {
      isEnabled = _preferencesData?.isTopicEnabled(topic.id) ?? false;
    }

    final hasChanges = _pendingChanges.containsKey(topic.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            topic.emoji ?? '📢',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          topicName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: hasChanges ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          'notifications.category.${topic.category}'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: _isLoading
              ? null
              : (value) => _onTopicChanged(topic.id, value),
          thumbColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Lokálne notifikácie',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Denné lectio
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text('📖', style: TextStyle(fontSize: 20)),
            ),
            title: const Text('Denné zamyslenie'),
            subtitle: const Text('Každý deň o 9:00 - lectio divina text'),
            trailing: Switch(
              value: _dailyLectioEnabled,
              onChanged: _isLoading
                  ? null
                  : (value) => _onDailyLectioChanged(value),
            ),
          ),
        ),

        // Pripomenutie modlitby
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text('🙏', style: TextStyle(fontSize: 20)),
            ),
            title: const Text('Pripomenutie modlitby'),
            subtitle: Text(
              _prayerReminderEnabled && _prayerReminderTime != null
                  ? 'Každý deň o ${_prayerReminderTime!.hour}:${_prayerReminderTime!.minute.toString().padLeft(2, '0')}'
                  : 'Nastaviť čas pripomenutia',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_prayerReminderEnabled)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _onPrayerReminderDisabled,
                    tooltip: 'Vypnúť',
                  ),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: _onPrayerReminderTimeChanged,
                  tooltip: 'Nastaviť čas',
                ),
              ],
            ),
          ),
        ),
      ],
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
      child: ListView(
        children: [
          // Header s popisom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'notifications.settings.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'notifications.settings.description'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Lokálne notifikácie
          _buildLocalNotificationsSection(),

          // FCM Topics rozdelené podľa kategórií
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Text(
              'Vzdialené notifikácie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ...groupedTopics.entries.map((categoryEntry) {
            final category = categoryEntry.key;
            final topics = categoryEntry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategórie header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'notifications.category.${category.value}'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Topics v kategórii
                ...topics.map(_buildTopicTile),
              ],
            );
          }),

          // Bottom spacing
          const SizedBox(height: 100), // Space pre FAB
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications.title'.tr()),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
          ? _buildPermissionRequest()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildTopicsSection(),
      floatingActionButton: _pendingChanges.isNotEmpty && _hasPermission
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text('notifications.action.save_changes'.tr()),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

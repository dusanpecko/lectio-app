import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart';
import '../services/fcm_service.dart';
import '../models/notification_models.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Logger _logger = Logger();
  final FcmService _fcmService = FcmService.instance;

  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  NotificationPreferencesResponse? _preferencesData;
  Map<String, bool> _pendingChanges = {};

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

      // Force clear cache if requested (to sync with web changes)
      if (forceRefresh) {
        _logger.i('🔄 Force refreshing notification preferences from database');
      }

      // Načítaj notification preferences (pass forceRefresh to bypass cache)
      final preferencesData = await _fcmService.getNotificationPreferences(
        forceRefresh: forceRefresh,
      );

      setState(() {
        _preferencesData = preferencesData;
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

      if (granted) {
        setState(() => _hasPermission = true);
        _initializeNotificationSettings();
      } else {
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
          activeColor: Theme.of(context).colorScheme.primary,
        ),
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

          // Topics rozdelené podľa kategórií
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
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

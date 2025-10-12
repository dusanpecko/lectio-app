import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';

/// API služba pre komunikáciu s backend endpoints pre notifications
class NotificationAPI {
  static final NotificationAPI _instance = NotificationAPI._internal();
  factory NotificationAPI() => _instance;
  NotificationAPI._internal();

  // Public getter for singleton instance
  static NotificationAPI get instance => _instance;

  final _logger = Logger();

  // Get Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  // Development mode - use environment variable to control mock data
  // To enable mock mode, run: flutter run --dart-define=USE_MOCK_DATA=true
  static const bool _useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );

  /// Register FCM token in Supabase
  /// This is called from fcm_service.dart after getting the token
  Future<void> registerFCMToken({
    required String fcmToken,
    required String deviceType,
    required String appVersion,
    String? deviceId,
  }) async {
    // Mock mode - just log
    if (_useMockData) {
      _logger.i('🚧 Development Mode: Mock FCM token registration');
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    try {
      _logger.i('Registering FCM token in Supabase...');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw NotificationApiException('User not authenticated');
      }

      // Upsert token (insert or update if exists)
      await _supabase.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'token': fcmToken,
        'device_type': deviceType,
        'device_id': deviceId,
        'app_version': appVersion,
        'is_active': true,
        'last_used_at': DateTime.now().toIso8601String(),
      });

      _logger.i('✅ FCM token registered successfully');
    } catch (e) {
      _logger.e('❌ Failed to register FCM token', error: e);
      // Don't throw - FCM should still work even if backend fails
    }
  }

  /// Get notification preferences (topics + user's enabled state)
  Future<NotificationPreferencesResponse> getNotificationPreferences({
    bool forceRefresh = false,
  }) async {
    _logger.i('Fetching notification preferences from Supabase...');

    // Return mock data if in development mode
    if (_useMockData) {
      _logger.w('🚧 Development Mode: Using mock notification data');
      await Future.delayed(const Duration(milliseconds: 500));
      return _getMockNotificationPreferences();
    }

    // Try cache first (unless force refresh)
    if (!forceRefresh) {
      final cacheAge = await NotificationPreferencesCache.getCacheAge();
      final cached = await NotificationPreferencesCache.getCachedPreferences();

      if (cached != null) {
        _logger.i(
          '📦 Using cached notification preferences (${cached.topics.length} topics, ${cached.preferences.length} prefs, age: ${cacheAge}s)',
        );
        return cached;
      } else if (cacheAge != null) {
        _logger.i('⏰ Cache expired (age: ${cacheAge}s), fetching fresh data');
      }
    } else {
      _logger.i('🔄 Force refresh - ignoring cache');
    }

    try {
      // Get user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw NotificationApiException('User not authenticated');
      }

      // Fetch all active topics
      final topicsResponse = await _supabase
          .from('notification_topics')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      // Fetch user preferences
      final preferencesResponse = await _supabase
          .from('user_notification_preferences')
          .select()
          .eq('user_id', userId);

      // Convert to models
      final topics = (topicsResponse as List)
          .map((json) => NotificationTopic.fromJson(json))
          .toList();

      final preferences = (preferencesResponse as List)
          .map((json) => NotificationPreference.fromJson(json))
          .toList();

      final responseData = NotificationPreferencesResponse(
        topics: topics,
        preferences: preferences,
      );

      // Cache the result
      await NotificationPreferencesCache.cachePreferences(responseData);
      _logger.i(
        '✅ Fetched ${topics.length} topics and ${preferences.length} preferences from Supabase',
      );

      return responseData;
    } catch (e) {
      _logger.e(
        '❌ Error fetching notification preferences from Supabase',
        error: e,
      );

      // Try to return cached data as fallback
      final cached = await NotificationPreferencesCache.getCachedPreferences();
      if (cached != null) {
        _logger.w('⚠️ Using stale cache due to error');
        return cached;
      }

      throw NotificationApiException('Failed to fetch preferences: $e');
    }
  }

  /// Aktualizuje preference pre konkrétny notification topic
  Future<void> updateTopicPreference({
    required String topicId,
    required bool isEnabled,
  }) async {
    // Mock mode - just log the change
    if (_useMockData) {
      _logger.i(
        '🚧 Development Mode: Mock update topic $topicId to $isEnabled',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    try {
      _logger.i('Updating topic preference in Supabase: $topicId = $isEnabled');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw NotificationApiException('User not authenticated');
      }

      // Upsert preference (insert or update)
      await _supabase.from('user_notification_preferences').upsert(
        {'user_id': userId, 'topic_id': topicId, 'is_enabled': isEnabled},
        onConflict: 'user_id,topic_id', // Handle duplicate key constraint
      );

      // Invalidate cache after successful update
      await NotificationPreferencesCache.clearCache();

      _logger.i('✅ Topic preference updated successfully');
    } catch (e) {
      _logger.e('❌ Failed to update topic preference', error: e);
      throw NotificationApiException('Failed to update preference: $e');
    }
  }

  /// Hromadne aktualizuje viacero topic preferencií naraz
  Future<void> updateMultipleTopicPreferences({
    required Map<String, bool> preferences,
  }) async {
    // Mock mode - just log the changes
    if (_useMockData) {
      _logger.i(
        '🚧 Development Mode: Mock bulk update ${preferences.length} preferences',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      _logger.i(
        'Bulk updating ${preferences.length} topic preferences in Supabase',
      );

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw NotificationApiException('User not authenticated');
      }

      // Update each preference individually to avoid bulk upsert issues
      int successCount = 0;
      for (final entry in preferences.entries) {
        try {
          // Check if preference exists
          final existing = await _supabase
              .from('user_notification_preferences')
              .select('id')
              .eq('user_id', userId)
              .eq('topic_id', entry.key)
              .maybeSingle();

          if (existing != null) {
            // UPDATE existing preference
            await _supabase
                .from('user_notification_preferences')
                .update({'is_enabled': entry.value})
                .eq('user_id', userId)
                .eq('topic_id', entry.key);
          } else {
            // INSERT new preference
            await _supabase.from('user_notification_preferences').insert({
              'user_id': userId,
              'topic_id': entry.key,
              'is_enabled': entry.value,
            });
          }
          successCount++;
        } catch (e) {
          _logger.w('Failed to update preference for topic ${entry.key}: $e');
          // Continue with other preferences
        }
      }

      // Invalidate cache after successful update
      await NotificationPreferencesCache.clearCache();

      _logger.i(
        '✅ Updated $successCount/${preferences.length} preferences successfully',
      );
    } catch (e) {
      _logger.e('❌ Failed to bulk update preferences', error: e);
      throw NotificationApiException('Failed to update preferences: $e');
    }
  }

  /// Deaktivuje FCM token (napríklad pri odhlásení)
  Future<void> deactivateFCMToken(String fcmToken) async {
    try {
      _logger.i('Deactivating FCM token in Supabase...');

      // Update token to inactive in database
      await _supabase
          .from('user_fcm_tokens')
          .update({'is_active': false})
          .eq('token', fcmToken);

      _logger.i('✅ FCM token deactivated successfully');
    } catch (e) {
      _logger.e('❌ Failed to deactivate FCM token', error: e);
      throw NotificationApiException('Failed to deactivate token: $e');
    }
  }

  /// Získa len zoznam dostupných topics (bez user preferencií)
  Future<List<NotificationTopic>> getAvailableTopics() async {
    try {
      _logger.i('Fetching available notification topics from Supabase...');

      final response = await _supabase
          .from('notification_topics')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final topics = (response as List)
          .map((json) => NotificationTopic.fromJson(json))
          .toList();

      _logger.i('✅ Fetched ${topics.length} available topics');
      return topics;
    } catch (e) {
      _logger.e('❌ Failed to fetch available topics', error: e);
      throw NotificationApiException('Failed to fetch topics: $e');
    }
  }

  // ============================================================================
  // MOCK DATA METHODS (for development/testing when backend is not available)
  // ============================================================================

  /// Returns mock notification preferences for development
  NotificationPreferencesResponse _getMockNotificationPreferences() {
    final now = DateTime.now();
    final mockTopics = [
      NotificationTopic(
        id: '1',
        nameSk: 'Denné zamyslenia',
        nameEn: 'Daily Reflections',
        nameCs: 'Denní úvahy',
        nameEs: 'Reflexiones diarias',
        category: 'spiritual',
        emoji: '🙏',
        sortOrder: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '2',
        nameSk: 'Biblické výklady',
        nameEn: 'Biblical Interpretations',
        nameCs: 'Biblické výklady',
        nameEs: 'Interpretaciones bíblicas',
        category: 'educational',
        emoji: '📖',
        sortOrder: 2,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '3',
        nameSk: 'Modlitby',
        nameEn: 'Prayers',
        nameCs: 'Modlitby',
        nameEs: 'Oraciones',
        category: 'spiritual',
        emoji: '🕊️',
        sortOrder: 3,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '4',
        nameSk: 'Aktuality',
        nameEn: 'News',
        nameCs: 'Aktuality',
        nameEs: 'Noticias',
        category: 'news',
        emoji: '📰',
        sortOrder: 4,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '5',
        nameSk: 'Denné pripomienky',
        nameEn: 'Daily Reminders',
        nameCs: 'Denní připomínky',
        nameEs: 'Recordatorios diarios',
        category: 'reminders',
        emoji: '⏰',
        sortOrder: 5,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '6',
        nameSk: 'Sviatky a slávnosti',
        nameEn: 'Feasts and Celebrations',
        nameCs: 'Svátky a slavnosti',
        nameEs: 'Fiestas y celebraciones',
        category: 'special',
        emoji: '✨',
        sortOrder: 6,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '7',
        nameSk: 'Liturgický kalendár',
        nameEn: 'Liturgical Calendar',
        nameCs: 'Liturgický kalendář',
        nameEs: 'Calendario litúrgico',
        category: 'educational',
        emoji: '📅',
        sortOrder: 7,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationTopic(
        id: '8',
        nameSk: 'Katechézy',
        nameEn: 'Catechesis',
        nameCs: 'Katecheze',
        nameEs: 'Catequesis',
        category: 'educational',
        emoji: '📚',
        sortOrder: 8,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Mock user preferences - first 4 topics enabled by default
    final mockPreferences = [
      NotificationPreference(
        id: '1',
        userId: 'mock-user-123',
        topicId: '1',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationPreference(
        id: '2',
        userId: 'mock-user-123',
        topicId: '2',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationPreference(
        id: '3',
        userId: 'mock-user-123',
        topicId: '3',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationPreference(
        id: '4',
        userId: 'mock-user-123',
        topicId: '4',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      NotificationPreference(
        id: '5',
        userId: 'mock-user-123',
        topicId: '5',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    _logger.i(
      '📦 Returning ${mockTopics.length} mock topics with ${mockPreferences.length} preferences',
    );

    return NotificationPreferencesResponse(
      topics: mockTopics,
      preferences: mockPreferences,
    );
  }
}

/// Custom exception pre NotificationAPI errors
class NotificationApiException implements Exception {
  final String message;
  final int? statusCode;

  NotificationApiException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'NotificationApiException ($statusCode): $message';
    }
    return 'NotificationApiException: $message';
  }
}

/// Helper pre offline caching notification preferencií
class NotificationPreferencesCache {
  static const String _cacheKey = 'notification_preferences_cache';
  static const String _cacheTimeKey = 'notification_preferences_cache_time';
  // Cache je platná 5 minút - potom sa automaticky obnoví z API
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Uloží preferences do cache
  static Future<void> cachePreferences(
    NotificationPreferencesResponse preferences,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(preferences.toJson());

      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger().w('Failed to cache preferences: $e');
    }
  }

  /// Načíta preferences z cache ak sú platné
  static Future<NotificationPreferencesResponse?> getCachedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt(_cacheTimeKey);

      if (jsonString == null || cacheTime == null) return null;

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (cacheAge > _cacheValidDuration.inMilliseconds) {
        return null; // Cache expired
      }

      final json = jsonDecode(jsonString);
      return NotificationPreferencesResponse.fromJson(json);
    } catch (e) {
      Logger().w('Failed to get cached preferences: $e');
      return null;
    }
  }

  /// Vyčistí cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (e) {
      Logger().w('Failed to clear preferences cache: $e');
    }
  }

  /// Overí či je cache stále platná
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);

      if (cacheTime == null) return false;

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
      return cacheAge <= _cacheValidDuration.inMilliseconds;
    } catch (e) {
      Logger().w('Failed to check cache validity: $e');
      return false;
    }
  }

  /// Získa vek cache v sekundách
  static Future<int?> getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);

      if (cacheTime == null) return null;

      final ageInMs = DateTime.now().millisecondsSinceEpoch - cacheTime;
      return (ageInMs / 1000).round();
    } catch (e) {
      Logger().w('Failed to get cache age: $e');
      return null;
    }
  }
}

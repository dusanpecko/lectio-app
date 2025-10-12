import 'dart:convert';

/// Model pre notification topics z backend API
class NotificationTopic {
  final String id;
  final String nameSk;
  final String nameEn;
  final String nameCs;
  final String nameEs;
  final String? nameDe;
  final String? emoji;
  final String category;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationTopic({
    required this.id,
    required this.nameSk,
    required this.nameEn,
    required this.nameCs,
    required this.nameEs,
    this.nameDe,
    this.emoji,
    required this.category,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Získa názov topics podľa jazyka
  String getNameByLanguage(String languageCode) {
    switch (languageCode) {
      case 'sk':
        return nameSk;
      case 'en':
        return nameEn;
      case 'cs':
      case 'cz':
        return nameCs;
      case 'es':
        return nameEs;
      case 'de':
        return nameDe ?? nameEn;
      default:
        return nameEn;
    }
  }

  /// Vytvorí NotificationTopic z JSON response
  factory NotificationTopic.fromJson(Map<String, dynamic> json) {
    return NotificationTopic(
      id: json['id'] as String,
      nameSk: json['name_sk'] as String,
      nameEn: json['name_en'] as String? ?? json['name_sk'] as String,
      nameCs: json['name_cs'] as String? ?? json['name_sk'] as String,
      nameEs: json['name_es'] as String? ?? json['name_sk'] as String,
      nameDe: json['name_de'] as String?,
      emoji: json['icon'] as String?, // Database uses 'icon' instead of 'emoji'
      category: json['category'] as String? ?? 'general',
      sortOrder:
          json['display_order'] as int? ?? 0, // Database uses 'display_order'
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Konvertuje na JSON pre API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_sk': nameSk,
      'name_en': nameEn,
      'name_cs': nameCs,
      'name_es': nameEs,
      'name_de': nameDe,
      'emoji': emoji,
      'category': category,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'NotificationTopic{id: $id, category: $category, emoji: $emoji}';
  }
}

/// Model pre používateľské preferencie k notification topics
class NotificationPreference {
  final String id;
  final String userId;
  final String topicId;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NotificationTopic? topic; // Optional pre joined queries

  NotificationPreference({
    required this.id,
    required this.userId,
    required this.topicId,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.topic,
  });

  /// Vytvorí NotificationPreference z JSON response
  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      topicId: json['topic_id'] as String,
      isEnabled: json['is_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      topic: json['topic'] != null
          ? NotificationTopic.fromJson(json['topic'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Konvertuje na JSON pre API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'topic_id': topicId,
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Vytvorí kópiu s novými hodnotami
  NotificationPreference copyWith({
    String? id,
    String? userId,
    String? topicId,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    NotificationTopic? topic,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      topicId: topicId ?? this.topicId,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      topic: topic ?? this.topic,
    );
  }

  @override
  String toString() {
    return 'NotificationPreference{topicId: $topicId, isEnabled: $isEnabled}';
  }
}

/// Model pre FCM token registráciu
class FCMTokenRequest {
  final String fcmToken;
  final String deviceType;
  final String appVersion;
  final String? deviceId;
  final String? localeCode;

  FCMTokenRequest({
    required this.fcmToken,
    required this.deviceType,
    required this.appVersion,
    this.deviceId,
    this.localeCode,
  });

  /// Konvertuje na JSON pre API calls
  Map<String, dynamic> toJson() {
    return {
      'fcm_token': fcmToken,
      'device_type': deviceType,
      'app_version': appVersion,
      'device_id': deviceId,
      'locale_code': localeCode,
    };
  }

  @override
  String toString() {
    return 'FCMTokenRequest{deviceType: $deviceType, appVersion: $appVersion}';
  }
}

/// Model pre API response s notification preferences
class NotificationPreferencesResponse {
  final List<NotificationTopic> topics;
  final List<NotificationPreference> preferences;

  NotificationPreferencesResponse({
    required this.topics,
    required this.preferences,
  });

  /// Vytvorí response z JSON
  factory NotificationPreferencesResponse.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesResponse(
      topics: (json['topics'] as List<dynamic>)
          .map((e) => NotificationTopic.fromJson(e as Map<String, dynamic>))
          .toList(),
      preferences: (json['preferences'] as List<dynamic>)
          .map(
            (e) => NotificationPreference.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Získa preference pre konkrétny topic
  NotificationPreference? getPreferenceForTopic(String topicId) {
    try {
      return preferences.firstWhere((pref) => pref.topicId == topicId);
    } catch (e) {
      return null;
    }
  }

  /// Skontroluje či je topic povolený
  /// Default je TRUE - ak používateľ nemá ešte nastavenú preferenciu, topic je zapnutý
  bool isTopicEnabled(String topicId) {
    final preference = getPreferenceForTopic(topicId);
    return preference?.isEnabled ??
        true; // ✅ Default TRUE - všetky topics zapnuté
  }

  /// Konvertuje na JSON pre caching
  Map<String, dynamic> toJson() {
    return {
      'topics': topics.map((e) => e.toJson()).toList(),
      'preferences': preferences.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'NotificationPreferencesResponse{topics: ${topics.length}, preferences: ${preferences.length}}';
  }
}

/// Enum pre kategórie notification topics
enum NotificationCategory {
  spiritual('spiritual'),
  educational('educational'),
  news('news'),
  reminders('reminders'),
  special('special');

  const NotificationCategory(this.value);
  final String value;

  static NotificationCategory fromString(String value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => NotificationCategory.spiritual,
    );
  }
}

/// Helper pre parsovanie API responses
class NotificationApiHelper {
  /// Parsuje JSON string na NotificationPreferencesResponse
  static NotificationPreferencesResponse parsePreferencesResponse(
    String jsonString,
  ) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return NotificationPreferencesResponse.fromJson(json);
  }

  /// Parsuje JSON string na list NotificationTopic
  static List<NotificationTopic> parseTopicsList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => NotificationTopic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Groupuje topics podľa kategórií
  static Map<NotificationCategory, List<NotificationTopic>>
  groupTopicsByCategory(List<NotificationTopic> topics) {
    final Map<NotificationCategory, List<NotificationTopic>> grouped = {};

    for (final topic in topics) {
      final category = NotificationCategory.fromString(topic.category);
      grouped[category] = [...(grouped[category] ?? []), topic];
    }

    // Sortuj každú kategóriu podľa sort_order
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return grouped;
  }
}

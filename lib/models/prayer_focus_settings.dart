class PrayerFocusSettings {
  final bool isEnabled;
  final bool silenceAllNotifications;
  final bool minimizeSystemNotifications;
  final bool suspendAppNotifications;
  final bool allowEmergencyCalls;
  final int detectionDelaySeconds; // Ako dlho čaká pred aktiváciou

  const PrayerFocusSettings({
    this.isEnabled = false,
    this.silenceAllNotifications = false,
    this.minimizeSystemNotifications = false,
    this.suspendAppNotifications = true, // Default - len app notifikácie
    this.allowEmergencyCalls = true, // Default - vždy povoliť emergency
    this.detectionDelaySeconds = 30, // 30 sekúnd čítania = aktivácia
  });

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'silenceAllNotifications': silenceAllNotifications,
      'minimizeSystemNotifications': minimizeSystemNotifications,
      'suspendAppNotifications': suspendAppNotifications,
      'allowEmergencyCalls': allowEmergencyCalls,
      'detectionDelaySeconds': detectionDelaySeconds,
    };
  }

  factory PrayerFocusSettings.fromJson(Map<String, dynamic> json) {
    return PrayerFocusSettings(
      isEnabled: json['isEnabled'] ?? false,
      silenceAllNotifications: json['silenceAllNotifications'] ?? false,
      minimizeSystemNotifications: json['minimizeSystemNotifications'] ?? false,
      suspendAppNotifications: json['suspendAppNotifications'] ?? true,
      allowEmergencyCalls: json['allowEmergencyCalls'] ?? true,
      detectionDelaySeconds: json['detectionDelaySeconds'] ?? 30,
    );
  }

  PrayerFocusSettings copyWith({
    bool? isEnabled,
    bool? silenceAllNotifications,
    bool? minimizeSystemNotifications,
    bool? suspendAppNotifications,
    bool? allowEmergencyCalls,
    int? detectionDelaySeconds,
  }) {
    return PrayerFocusSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      silenceAllNotifications:
          silenceAllNotifications ?? this.silenceAllNotifications,
      minimizeSystemNotifications:
          minimizeSystemNotifications ?? this.minimizeSystemNotifications,
      suspendAppNotifications:
          suspendAppNotifications ?? this.suspendAppNotifications,
      allowEmergencyCalls: allowEmergencyCalls ?? this.allowEmergencyCalls,
      detectionDelaySeconds:
          detectionDelaySeconds ?? this.detectionDelaySeconds,
    );
  }

  /// Zisti či sú aktivované nejaké stlmenia
  bool get hasAnyNotificationSettings {
    return silenceAllNotifications ||
        minimizeSystemNotifications ||
        suspendAppNotifications;
  }

  /// Opis aktívnych nastavení pre UI
  String getActiveSettingsDescription() {
    if (!hasAnyNotificationSettings) return 'Žiadne stlmenie';

    List<String> active = [];
    if (silenceAllNotifications) active.add('Všetky notifikácie');
    if (minimizeSystemNotifications) active.add('Systémové');
    if (suspendAppNotifications) active.add('Aplikačné');

    String result = active.join(', ');
    if (allowEmergencyCalls && active.isNotEmpty) {
      result += ' (emergency calls povolené)';
    }

    return result;
  }
}

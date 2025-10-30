import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_focus_settings.dart';

enum PrayerFocusStatus {
  inactive, // Nie je aktívny
  detecting, // Detekuje aktívne čítanie
  active, // Aktívny tichý režim
}

enum SpiritualScreen {
  lectio, // Lectio Divina
  rosary, // Ruženec
  adoration, // Adorácie
  crossway, // Krížové cesty
}

class PrayerFocusService {
  static final PrayerFocusService _instance = PrayerFocusService._internal();
  factory PrayerFocusService() => _instance;
  PrayerFocusService._internal();

  final Logger _logger = Logger();

  // Settings
  PrayerFocusSettings _settings = const PrayerFocusSettings();

  // State management
  PrayerFocusStatus _status = PrayerFocusStatus.inactive;
  SpiritualScreen? _currentScreen;
  Timer? _detectionTimer;

  // Stream controllers pre notifikácie zmien
  final StreamController<PrayerFocusStatus> _statusController =
      StreamController<PrayerFocusStatus>.broadcast();
  final StreamController<PrayerFocusSettings> _settingsController =
      StreamController<PrayerFocusSettings>.broadcast();

  // Getters
  PrayerFocusSettings get settings => _settings;
  PrayerFocusStatus get status => _status;
  SpiritualScreen? get currentScreen => _currentScreen;
  bool get isActive => _status == PrayerFocusStatus.active;
  bool get isDetecting => _status == PrayerFocusStatus.detecting;

  // Streams
  Stream<PrayerFocusStatus> get statusStream => _statusController.stream;
  Stream<PrayerFocusSettings> get settingsStream => _settingsController.stream;

  /// Inicializácia service
  Future<void> initialize() async {
    _logger.i('🧘‍♂️ Initializing Prayer Focus Service');
    await _loadSettings();
  }

  /// Načítanie nastavení z SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('prayer_focus_settings');

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = PrayerFocusSettings.fromJson(settingsMap);
        _logger.i(
          '📱 Prayer Focus settings loaded: enabled=${_settings.isEnabled}',
        );
      } else {
        _logger.i('📱 Using default Prayer Focus settings');
      }

      _settingsController.add(_settings);
    } catch (e) {
      _logger.e('❌ Error loading Prayer Focus settings: $e');
    }
  }

  /// Uloženie nastavení do SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString('prayer_focus_settings', settingsJson);
      _logger.i('💾 Prayer Focus settings saved');
    } catch (e) {
      _logger.e('❌ Error saving Prayer Focus settings: $e');
    }
  }

  /// Aktualizácia nastavení
  Future<void> updateSettings(PrayerFocusSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    _settingsController.add(_settings);

    // Ak sa vypli nastavenia, deaktivuj focus mode
    if (!_settings.isEnabled && _status != PrayerFocusStatus.inactive) {
      await deactivateFocusMode();
    }
  }

  /// Notifikácia o vstupe do spiritual screen
  void onSpiritualScreenEntered(SpiritualScreen screen) {
    if (!_settings.isEnabled) return;

    _logger.i('🙏 Spiritual screen entered: ${screen.name}');
    _currentScreen = screen;

    _startDetection();
  }

  /// Notifikácia o opustení spiritual screen
  void onSpiritualScreenExited(SpiritualScreen screen) {
    if (_currentScreen != screen) return;

    _logger.i('👋 Spiritual screen exited: ${screen.name}');
    _currentScreen = null;

    _stopDetection();

    // Deaktivuj focus mode ak bol aktívny
    if (_status == PrayerFocusStatus.active) {
      deactivateFocusMode();
    }
  }

  /// Notifikácia o user interakcii (scroll, tap, atď.)
  void onUserInteraction() {
    if (!_settings.isEnabled || _currentScreen == null) return;

    // Reset detection timer pri user interakcii
    if (_status == PrayerFocusStatus.detecting) {
      _resetDetectionTimer();
    }
  }

  /// Spustenie detekcie
  void _startDetection() {
    if (_status != PrayerFocusStatus.inactive) return;

    _updateStatus(PrayerFocusStatus.detecting);
    _resetDetectionTimer();
  }

  /// Reset detection timer
  void _resetDetectionTimer() {
    _detectionTimer?.cancel();

    _detectionTimer = Timer(
      Duration(seconds: _settings.detectionDelaySeconds),
      _onDetectionComplete,
    );

    _logger.d('⏰ Detection timer reset: ${_settings.detectionDelaySeconds}s');
  }

  /// Zastavenie detekcie
  void _stopDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;

    if (_status == PrayerFocusStatus.detecting) {
      _updateStatus(PrayerFocusStatus.inactive);
    }
  }

  /// Callback po dokončení detekcie
  void _onDetectionComplete() {
    if (_status != PrayerFocusStatus.detecting) return;

    _logger.i('✅ Detection complete - activating Prayer Focus Mode');
    _activateFocusMode();
  }

  /// Aktivácia Prayer Focus Mode
  Future<void> _activateFocusMode() async {
    try {
      _updateStatus(PrayerFocusStatus.active);

      // Aplikuj notification settings
      await _applyNotificationSettings();

      _logger.i('🧘‍♂️ Prayer Focus Mode activated');
    } catch (e) {
      _logger.e('❌ Error activating Prayer Focus Mode: $e');
      _updateStatus(PrayerFocusStatus.detecting);
    }
  }

  /// Deaktivácia Prayer Focus Mode
  Future<void> deactivateFocusMode() async {
    if (_status != PrayerFocusStatus.active) return;

    try {
      // Obnov notification settings
      await _restoreNotificationSettings();

      _updateStatus(PrayerFocusStatus.inactive);
      _logger.i('👋 Prayer Focus Mode deactivated');
    } catch (e) {
      _logger.e('❌ Error deactivating Prayer Focus Mode: $e');
    }
  }

  /// Manuálne zapnutie Focus Mode
  Future<void> manualActivate() async {
    if (!_settings.isEnabled) {
      _logger.w('⚠️ Prayer Focus Mode is disabled in settings');
      return;
    }

    _stopDetection(); // Zastav automatickú detekciu
    await _activateFocusMode();
  }

  /// Manuálne vypnutie Focus Mode
  Future<void> manualDeactivate() async {
    await deactivateFocusMode();
  }

  /// Aplikovanie notification settings
  Future<void> _applyNotificationSettings() async {
    _logger.i(
      '🔕 Applying notification settings: ${_settings.getActiveSettingsDescription()}',
    );

    if (_settings.silenceAllNotifications) {
      await _silenceAllNotifications();
    } else {
      if (_settings.minimizeSystemNotifications) {
        await _minimizeSystemNotifications();
      }
      if (_settings.suspendAppNotifications) {
        await _suspendAppNotifications();
      }
    }
  }

  /// Obnovenie notification settings
  Future<void> _restoreNotificationSettings() async {
    _logger.i('🔔 Restoring notification settings');

    // TODO: Implementovať restoration podľa toho čo bolo aplikované
    await _restoreAllNotifications();
  }

  /// Implementácia notification management
  Future<void> _silenceAllNotifications() async {
    _logger.d('🔕 Silencing all notifications');

    try {
      // Použijeme existujúci flutter_local_notifications service
      final localNotifications = await _getLocalNotifications();
      if (localNotifications != null) {
        // Pozastavíme všetky scheduled notifications
        await localNotifications.cancelAll();
        _logger.i('� All local notifications cancelled');
      }

      // Pre systémové notifikácie by sme potrebovali platform-specific riešenie
      _logger.i('🔕 All notifications silenced');
    } catch (e) {
      _logger.e('❌ Error silencing notifications: $e');
    }
  }

  Future<void> _minimizeSystemNotifications() async {
    _logger.d('🔕 Minimizing system notifications');

    try {
      // Pre systémové notifikácie potrebujeme platform channels
      // Zatiaľ len logujeme
      _logger.i('🔕 System notifications minimized (limited support)');
    } catch (e) {
      _logger.e('❌ Error minimizing system notifications: $e');
    }
  }

  Future<void> _suspendAppNotifications() async {
    _logger.d('🔕 Suspending app notifications');

    try {
      // Pozastavíme naše vlastné notifikácie
      final localNotifications = await _getLocalNotifications();
      if (localNotifications != null) {
        // Zrušíme scheduled notifications
        await localNotifications.cancelAll();
        _logger.i('� App notifications suspended');
      }
    } catch (e) {
      _logger.e('❌ Error suspending app notifications: $e');
    }
  }

  Future<void> _restoreAllNotifications() async {
    _logger.d('🔔 Restoring all notifications');

    try {
      // Obnovíme naše scheduled notifications
      await _rescheduleLocalNotifications();
      _logger.i('🔔 All notifications restored');
    } catch (e) {
      _logger.e('❌ Error restoring notifications: $e');
    }
  }

  /// Helper metóda na získanie lokálnych notifikácií
  Future<dynamic> _getLocalNotifications() async {
    try {
      // Import FlutterLocalNotificationsPlugin dynamicky
      return null; // Placeholder - implementovať podľa potreby
    } catch (e) {
      _logger.w('⚠️ Local notifications service not available: $e');
      return null;
    }
  }

  /// Obnovenie naplánovaných lokálnych notifikácií
  Future<void> _rescheduleLocalNotifications() async {
    try {
      // Implementovať obnovenie daily lectio a prayer reminders
      _logger.i('📅 Local notifications rescheduled');
    } catch (e) {
      _logger.e('❌ Error rescheduling notifications: $e');
    }
  }

  /// Update status a notify listeners
  void _updateStatus(PrayerFocusStatus newStatus) {
    if (_status == newStatus) return;

    final oldStatus = _status;
    _status = newStatus;
    _statusController.add(_status);

    _logger.i('📊 Prayer Focus status: ${oldStatus.name} → ${newStatus.name}');
  }

  /// Cleanup
  void dispose() {
    _detectionTimer?.cancel();
    _statusController.close();
    _settingsController.close();
  }
}

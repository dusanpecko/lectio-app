import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service pre správu Do Not Disturb (Nerušiť) funkcionality
/// Automaticky aktivuje režim "Nerušiť" počas čítania a modlitby
class DoNotDisturbService {
  static final DoNotDisturbService _instance = DoNotDisturbService._internal();
  factory DoNotDisturbService() => _instance;
  DoNotDisturbService._internal();

  final Logger _logger = Logger();
  static const _platform = MethodChannel('sk.lectio.divina/do_not_disturb');

  bool _isEnabled = false;
  bool _isDndActive = false;
  Timer? _activationTimer;
  Timer? _sessionTimer;

  // Stream controller pre real-time updates
  final StreamController<bool> _dndStateController =
      StreamController<bool>.broadcast();

  // Settings
  bool _autoActivate = true;
  int _activationDelaySeconds = 30;
  int _maxSessionDurationMinutes = 120; // 2 hodiny max

  /// Inicializácia service
  Future<void> initialize() async {
    await _loadSettings();
    _logger.i('🔕 DoNotDisturbService initialized - enabled: $_isEnabled');
  }

  /// Načítanie nastavení zo SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('dnd_enabled') ?? false;
    _autoActivate = prefs.getBool('dnd_auto_activate') ?? true;
    _activationDelaySeconds = prefs.getInt('dnd_activation_delay') ?? 30;
    _maxSessionDurationMinutes =
        prefs.getInt('dnd_max_session_duration') ?? 120;
  }

  /// Uloženie nastavení
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dnd_enabled', _isEnabled);
    await prefs.setBool('dnd_auto_activate', _autoActivate);
    await prefs.setInt('dnd_activation_delay', _activationDelaySeconds);
    await prefs.setInt('dnd_max_session_duration', _maxSessionDurationMinutes);
  }

  /// Zapnutie/vypnutie DND funkcie
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _saveSettings();

    if (!enabled && _isDndActive) {
      await _deactivateDnd();
    }

    _logger.i('🔕 DoNotDisturb ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Začiatok čítania/modlitby - spustí timer pre aktiváciu DND
  Future<void> startReadingSession() async {
    if (!_isEnabled || !_autoActivate) return;

    _logger.i(
      '🔕 Starting reading session - DND will activate in $_activationDelaySeconds seconds',
    );

    // Zruš existujúce timery
    _cancelTimers();

    // Nastav timer pre aktiváciu DND
    _activationTimer = Timer(Duration(seconds: _activationDelaySeconds), () {
      _activateDnd();
    });

    // Nastav maximálny timer pre session
    _sessionTimer = Timer(Duration(minutes: _maxSessionDurationMinutes), () {
      endReadingSession();
    });
  }

  /// Konec čítania/modlitby - deaktivuje DND
  Future<void> endReadingSession() async {
    _logger.i('🔕 Ending reading session');
    _cancelTimers();

    if (_isDndActive) {
      await _deactivateDnd();
    }
  }

  /// Zrušenie všetkých timerov
  void _cancelTimers() {
    _activationTimer?.cancel();
    _activationTimer = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Aktivácia Do Not Disturb režimu
  Future<void> _activateDnd() async {
    if (_isDndActive) return;

    try {
      if (Platform.isIOS) {
        await _activateIOSDnd();
      } else if (Platform.isAndroid) {
        await _activateAndroidDnd();
      }

      _isDndActive = true;
      _dndStateController.add(true);
      _logger.i('🔕 ✅ Do Not Disturb ACTIVATED');
    } catch (e) {
      _logger.e('🔕 ❌ Failed to activate DND: $e');
    }
  }

  /// Deaktivácia Do Not Disturb režimu
  Future<void> _deactivateDnd() async {
    if (!_isDndActive) return;

    try {
      if (Platform.isIOS) {
        await _deactivateIOSDnd();
      } else if (Platform.isAndroid) {
        await _deactivateAndroidDnd();
      }

      _isDndActive = false;
      _dndStateController.add(false);
      _logger.i('🔕 ✅ Do Not Disturb DEACTIVATED');
    } catch (e) {
      _logger.e('🔕 ❌ Failed to deactivate DND: $e');
    }
  }

  /// iOS Do Not Disturb aktivácia s podporou Shortcuts
  Future<void> _activateIOSDnd() async {
    try {
      // Prioritne skúsime spustiť Shortcuts pre DND
      final shortcutsResult = await _tryActivateIOSShortcuts();
      if (shortcutsResult) {
        _logger.i('🔕 iOS DND activated via Shortcuts');
        return;
      }

      // Fallback na Focus API (iOS 15+)
      await _platform.invokeMethod('activateIOSFocus', {
        'focusMode': 'prayer', // custom focus mode pre modlitbu
        'allowCalls': true, // povoliť emergency calls
        'allowMessages': false,
        'allowApps': [], // žiadne aplikácie
      });

      _logger.i('🔕 iOS Focus mode activated');
    } catch (e) {
      // Posledný fallback na Silent Mode
      try {
        await _platform.invokeMethod('activateIOSSilent');
        _logger.i('🔕 iOS Silent mode activated (fallback)');
      } catch (fallbackError) {
        _logger.e('🔕 iOS DND fallback failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// iOS Do Not Disturb deaktivácia s podporou Shortcuts
  Future<void> _deactivateIOSDnd() async {
    try {
      // Prioritne skúsime deaktivovať cez Shortcuts
      final shortcutsResult = await _tryDeactivateIOSShortcuts();
      if (shortcutsResult) {
        _logger.i('🔕 iOS DND deactivated via Shortcuts');
        return;
      }

      // Fallback na Focus API
      await _platform.invokeMethod('deactivateIOSFocus');
      _logger.i('🔕 iOS Focus mode deactivated');
    } catch (e) {
      try {
        await _platform.invokeMethod('deactivateIOSSilent');
        _logger.i('🔕 iOS Silent mode deactivated (fallback)');
      } catch (fallbackError) {
        _logger.e('🔕 iOS DND deactivation failed: $fallbackError');
      }
    }
  }

  /// Pokus o aktiváciu DND cez iOS Shortcuts
  Future<bool> _tryActivateIOSShortcuts() async {
    try {
      // URL pre spustenie Shortcut-u pre zapnutie DND
      final shortcutUrl = Uri.parse(
        'shortcuts://run-shortcut?name=Lectio%20Divina%20DND%20On',
      );

      if (await canLaunchUrl(shortcutUrl)) {
        final launched = await launchUrl(shortcutUrl);
        if (launched) {
          _logger.i('🔕 iOS Shortcut launched for DND activation');
          // Predpokladáme úspech ak sa Shortcut spustil
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.w('🔕 iOS Shortcuts activation failed: $e');
      return false;
    }
  }

  /// Pokus o deaktiváciu DND cez iOS Shortcuts
  Future<bool> _tryDeactivateIOSShortcuts() async {
    try {
      // URL pre spustenie Shortcut-u pre vypnutie DND
      final shortcutUrl = Uri.parse(
        'shortcuts://run-shortcut?name=Lectio%20Divina%20DND%20Off',
      );

      if (await canLaunchUrl(shortcutUrl)) {
        final launched = await launchUrl(shortcutUrl);
        if (launched) {
          _logger.i('🔕 iOS Shortcut launched for DND deactivation');
          // Predpokladáme úspech ak sa Shortcut spustil
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.w('🔕 iOS Shortcuts deactivation failed: $e');
      return false;
    }
  }

  /// Kontrola či sú iOS Shortcuts dostupné
  Future<bool> checkIOSShortcutsSupport() async {
    try {
      // Kontrolujeme či je možné otvoriť Shortcuts app
      final shortcutsAppUrl = Uri.parse('shortcuts://');
      return await canLaunchUrl(shortcutsAppUrl);
    } catch (e) {
      _logger.w('🔕 iOS Shortcuts support check failed: $e');
      return false;
    }
  }

  /// Otvorenie iOS Shortcuts app pre vytvorenie shortcut-ov
  Future<void> openIOSShortcutsApp() async {
    try {
      final shortcutsAppUrl = Uri.parse('shortcuts://');

      if (await canLaunchUrl(shortcutsAppUrl)) {
        await launchUrl(shortcutsAppUrl);
        _logger.i('🔕 iOS Shortcuts app opened');
      } else {
        throw Exception('Shortcuts app is not available');
      }
    } catch (e) {
      _logger.e('🔕 Failed to open iOS Shortcuts app: $e');
      rethrow;
    }
  }

  /// Otvorenie Gallery s prednastavenými Shortcut-mi pre Lectio Divina
  Future<void> openLectioDivinaShortcutsGallery() async {
    try {
      // URL pre pridanie shortcut-u z gallery alebo z iCloud
      final galleryUrl = Uri.parse(
        'shortcuts://gallery/search?query=Focus%20Mode',
      );

      if (await canLaunchUrl(galleryUrl)) {
        await launchUrl(galleryUrl);
        _logger.i('🔕 iOS Shortcuts gallery opened');
      } else {
        // Fallback na základné Shortcuts app
        await openIOSShortcutsApp();
      }
    } catch (e) {
      _logger.e('🔕 Failed to open iOS Shortcuts gallery: $e');
      rethrow;
    }
  }

  /// Android Do Not Disturb aktivácia
  Future<void> _activateAndroidDnd() async {
    try {
      // Android používa NotificationManager.Policy pre DND
      await _platform.invokeMethod('activateAndroidDnd', {
        'priority': 'priority', // INTERRUPTION_FILTER_PRIORITY
        'allowCalls': false, // úplne zakázať hovory
        'allowMessages': false, // úplne zakázať správy
        'allowAlarms': true, // povoliť budíky
        'allowMedia': true, // povoliť naše audio
        'allowReminders': false,
        'allowEvents': false,
        'suppressNotifications': true,
      });

      _logger.i('🔕 Android DND mode activated');
    } catch (e) {
      _logger.e('🔕 Android DND activation failed: $e');
      rethrow;
    }
  }

  /// Android Do Not Disturb deaktivácia
  Future<void> _deactivateAndroidDnd() async {
    try {
      await _platform.invokeMethod('deactivateAndroidDnd');
      _logger.i('🔕 Android DND mode deactivated');
    } catch (e) {
      _logger.e('🔕 Android DND deactivation failed: $e');
    }
  }

  /// Kontrola či má aplikácia potrebné povolenia pre DND
  Future<bool> checkPermissions() async {
    try {
      final result = await _platform.invokeMethod('checkDndPermissions');
      return result as bool;
    } catch (e) {
      _logger.e('🔕 Failed to check DND permissions: $e');
      return false;
    }
  }

  /// Požiadanie o povolenia pre DND
  Future<bool> requestPermissions() async {
    try {
      final result = await _platform.invokeMethod('requestDndPermissions');
      return result as bool;
    } catch (e) {
      _logger.e('🔕 Failed to request DND permissions: $e');
      return false;
    }
  }

  /// Gettery pre aktuálny stav
  bool get isEnabled => _isEnabled;
  bool get isDndActive => _isDndActive;
  bool get autoActivate => _autoActivate;
  int get activationDelaySeconds => _activationDelaySeconds;
  int get maxSessionDurationMinutes => _maxSessionDurationMinutes;

  /// Stream pre sledovanie stavu DND
  Stream<bool> get dndStateStream => _dndStateController.stream;

  /// Setters pre nastavenia
  Future<void> setAutoActivate(bool value) async {
    _autoActivate = value;
    await _saveSettings();
  }

  Future<void> setActivationDelay(int seconds) async {
    _activationDelaySeconds = seconds;
    await _saveSettings();
  }

  Future<void> setMaxSessionDuration(int minutes) async {
    _maxSessionDurationMinutes = minutes;
    await _saveSettings();
  }

  /// Manuálna aktivácia DND (pre tlačidlo v UI)
  Future<void> activateDndManually() async {
    if (!_isEnabled) return;

    _cancelTimers(); // Zruš existujúce timery
    await _activateDnd();
  }

  /// Manuálna deaktivácia DND (pre tlačidlo v UI)
  Future<void> deactivateDndManually() async {
    _cancelTimers(); // Zruš existujúce timery
    await _deactivateDnd();
  }

  /// Toggle DND stavu (pre tlačidlo v UI)
  Future<void> toggleDnd() async {
    if (_isDndActive) {
      await deactivateDndManually();
    } else {
      await activateDndManually();
    }
  }

  /// Čistenie pri dispose
  void dispose() {
    _cancelTimers();
    if (_isDndActive) {
      _deactivateDnd();
    }
    _dndStateController.close();
  }
}

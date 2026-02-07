import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

/// Služba pre sledovanie stavu internetového pripojenia
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance =>
      _instance ??= ConnectivityService._internal();

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Aktuálny stav pripojenia
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Stream pre sledovanie zmien stavu pripojenia
  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  /// Callback pre zmeny stavu (voliteľný)
  void Function(bool isOnline)? onStatusChanged;

  /// Inicializácia služby - volať v main.dart
  Future<void> initialize() async {
    appLogger.i('🌐 ConnectivityService: Inicializácia...');

    // Zisti počiatočný stav
    await _checkConnectivity();

    // Počúvaj na zmeny
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    appLogger.i('🌐 ConnectivityService: Inicializovaný, online: $_isOnline');
  }

  /// Skontroluj aktuálny stav pripojenia
  Future<bool> checkConnectivity() async {
    await _checkConnectivity();
    return _isOnline;
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();

      // connectivity_plus len hovorí či sme pripojení k sieti, nie či máme internet
      final hasNetworkConnection =
          results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);

      if (!hasNetworkConnection) {
        // Žiadna sieť = definitívne offline
        _isOnline = false;
        appLogger.i('🌐 ConnectivityService: Žiadna sieť - OFFLINE');
      } else {
        // Máme sieť, ale overíme či máme skutočný internet
        _isOnline = await _hasRealConnectivity();
        appLogger.i(
          '🌐 ConnectivityService: Sieť OK, internet: ${_isOnline ? "ONLINE" : "OFFLINE"}',
        );
      }
    } catch (e) {
      appLogger.e(
        '🌐 ConnectivityService: Chyba pri kontrole pripojenia',
        error: e,
      );
      // Skúsime skutočný DNS lookup namiesto predpokladu online
      _isOnline = await _hasRealConnectivity();
      appLogger.i(
        '🌐 ConnectivityService: Fallback DNS check: ${_isOnline ? "ONLINE" : "OFFLINE"}',
      );
    }
  }

  /// Skutočný test pripojenia cez HTTP request (nie len DNS)
  Future<bool> _hasRealConnectivity() async {
    try {
      // Google's connectivity check endpoint - vráti 204 ak je internet
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 204;
    } catch (e) {
      appLogger.d('🌐 ConnectivityService: HTTP check failed: $e');
      return false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Ak sieť zmizla úplne, okamžite nastav offline
    final hasNetworkConnection =
        results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (!hasNetworkConnection) {
      final wasOnline = _isOnline;
      _isOnline = false;
      if (wasOnline) {
        appLogger.i('🌐 ConnectivityService: Sieť zmizla - OFFLINE');
        _onlineController.add(_isOnline);
        onStatusChanged?.call(_isOnline);
      }
    } else {
      // Sieť je dostupná - skúsime overenie s retry
      _verifyConnectivityWithRetry();
    }
  }

  /// Overí skutočnú konektivitu s retry logikou
  /// (sieť nemusí byť hneď plne pripravená)
  Future<void> _verifyConnectivityWithRetry() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt));
      }
      final hasInternet = await _hasRealConnectivity();
      if (hasInternet) {
        if (!_isOnline) {
          _isOnline = true;
          appLogger.i(
            '🌐 ConnectivityService: Internet obnovený - ONLINE (pokus ${attempt + 1})',
          );
          _onlineController.add(_isOnline);
          onStatusChanged?.call(_isOnline);
        }
        return;
      }
    }
    // Po 3 pokusoch stále offline
    if (_isOnline) {
      _isOnline = false;
      appLogger.i('🌐 ConnectivityService: Sieť bez internetu - OFFLINE');
      _onlineController.add(_isOnline);
      onStatusChanged?.call(_isOnline);
    }
  }

  /// Typ pripojenia (pre debugging)
  Future<String> getConnectionType() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return 'Offline';
    }

    final types = results
        .where((r) => r != ConnectivityResult.none)
        .map((r) => _connectionTypeName(r))
        .join(', ');
    return types;
  }

  String _connectionTypeName(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobilné dáta';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Iné';
      case ConnectivityResult.none:
        return 'Žiadne';
    }
  }

  /// Uvoľnenie zdrojov
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
    appLogger.i('🌐 ConnectivityService: Disposed');
  }

  /// Označ ako offline (volať keď API request zlyhá)
  void markOffline() {
    if (_isOnline) {
      _isOnline = false;
      appLogger.i('🌐 ConnectivityService: Manuálne označený ako OFFLINE');
      _onlineController.add(_isOnline);
      onStatusChanged?.call(_isOnline);
    }
  }

  /// Znova skontroluj pripojenie (volať keď chceme retry)
  Future<void> recheckConnectivity() async {
    await _checkConnectivity();
    _onlineController.add(_isOnline);
    onStatusChanged?.call(_isOnline);
  }

  /// Pre testovanie
  @visibleForTesting
  static void setInstanceForTesting(ConnectivityService instance) {
    _instance = instance;
  }

  @visibleForTesting
  void setOnlineStatus(bool online) {
    _isOnline = online;
    _onlineController.add(_isOnline);
  }
}

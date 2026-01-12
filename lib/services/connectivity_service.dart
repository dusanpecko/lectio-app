import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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
      _updateStatus(results);
    } catch (e) {
      appLogger.e(
        '🌐 ConnectivityService: Chyba pri kontrole pripojenia',
        error: e,
      );
      // V prípade chyby predpokladáme online
      _isOnline = true;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _updateStatus(results);

    if (wasOnline != _isOnline) {
      appLogger.i(
        '🌐 ConnectivityService: Stav zmenený: ${_isOnline ? "ONLINE" : "OFFLINE"}',
      );
      _onlineController.add(_isOnline);
      onStatusChanged?.call(_isOnline);
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // Sme online ak máme akékoľvek pripojenie okrem none
    _isOnline =
        results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
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

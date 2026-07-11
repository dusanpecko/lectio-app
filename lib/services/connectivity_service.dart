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
      _isOnline = _hasNetwork(results);
      appLogger.i(
        '🌐 ConnectivityService: ${_isOnline ? "ONLINE" : "OFFLINE"}',
      );
    } catch (e) {
      // Pri chybe kontroly predpokladaj online (reálne sieťové chyby zachytia
      // fetch metódy cez markOffline()).
      _isOnline = true;
      appLogger.e('🌐 ConnectivityService: Chyba pri kontrole', error: e);
    }
  }

  /// Je dostupné aspoň jedno sieťové rozhranie (wifi/mobil)?
  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      !results.every((r) => r == ConnectivityResult.none);

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final online = _hasNetwork(results);
    if (online == _isOnline) return;
    _isOnline = online;
    appLogger.i('🌐 ConnectivityService: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    _onlineController.add(_isOnline);
    onStatusChanged?.call(_isOnline);
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
      case ConnectivityResult.satellite:
        return 'Satelit';
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

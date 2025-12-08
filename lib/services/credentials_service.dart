import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/app_logger.dart';

class CredentialsService {
  static const _storage = FlutterSecureStorage();

  static const _emailKey = 'user_email';
  static const _passwordKey = 'user_password';

  final _logger = appLogger;

  // Uloží prihlasovacie údaje
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _passwordKey, value: password);
      _logger.i('Credentials saved successfully');
    } catch (e) {
      _logger.e('Error saving credentials: $e');
      rethrow;
    }
  }

  // Načíta email
  Future<String?> getEmail() async {
    try {
      return await _storage.read(key: _emailKey);
    } catch (e) {
      _logger.e('Error reading email: $e');
      return null;
    }
  }

  // Načíta heslo
  Future<String?> getPassword() async {
    try {
      return await _storage.read(key: _passwordKey);
    } catch (e) {
      _logger.e('Error reading password: $e');
      return null;
    }
  }

  // Načíta oba údaje naraz
  Future<Map<String, String?>> getCredentials() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      return {'email': email, 'password': password};
    } catch (e) {
      _logger.e('Error reading credentials: $e');
      return {'email': null, 'password': null};
    }
  }

  // Vymaže uložené údaje
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
      _logger.i('Credentials cleared successfully');
    } catch (e) {
      _logger.e('Error clearing credentials: $e');
      rethrow;
    }
  }

  // Skontroluje či sú údaje uložené
  Future<bool> hasCredentials() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      return email != null && password != null;
    } catch (e) {
      _logger.e('Error checking credentials: $e');
      return false;
    }
  }
}

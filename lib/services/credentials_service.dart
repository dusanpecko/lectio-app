import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/app_logger.dart';

/// Ukladá len e-mail na predvyplnenie prihlasovacieho formulára.
///
/// Heslo sa zámerne neukladá: session drží `supabase_flutter` a uložené heslo
/// by na zdieľanom alebo kompromitovanom zariadení bolo znovupoužiteľné.
/// `purgeLegacyPassword()` dočisťuje heslá z inštalácií pred touto zmenou.
class CredentialsService {
  static CredentialsService? _instance;
  static CredentialsService get instance =>
      _instance ??= CredentialsService._internal();

  static void setInstanceForTesting(CredentialsService service) {
    _instance = service;
  }

  CredentialsService._internal();

  factory CredentialsService() => instance;

  static const _storage = FlutterSecureStorage();

  static const _emailKey = 'user_email';

  /// Kľúč z historickej verzie, ktorá ukladala aj heslo. Už sa nezapisuje,
  /// len maže — viď `purgeLegacyPassword()`.
  static const _legacyPasswordKey = 'user_password';

  final _logger = appLogger;

  // Uloží e-mail na predvyplnenie
  Future<void> saveEmail(String email) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      await _storage.delete(key: _legacyPasswordKey);
      _logger.i('Email saved successfully');
    } catch (e) {
      _logger.e('Error saving email: $e');
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

  // Vymaže uložené údaje (volané pri odhlásení a pri vypnutí „zapamätať si ma")
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _legacyPasswordKey);
      _logger.i('Credentials cleared successfully');
    } catch (e) {
      _logger.e('Error clearing credentials: $e');
      rethrow;
    }
  }

  /// Zmaže heslo uložené staršou verziou aplikácie. E-mail ponechá.
  Future<void> purgeLegacyPassword() async {
    try {
      await _storage.delete(key: _legacyPasswordKey);
    } catch (e) {
      _logger.w('Failed to purge legacy stored password', error: e);
    }
  }

  // Skontroluje či je e-mail uložený
  Future<bool> hasCredentials() async {
    try {
      return await _storage.read(key: _emailKey) != null;
    } catch (e) {
      _logger.e('Error checking credentials: $e');
      return false;
    }
  }
}

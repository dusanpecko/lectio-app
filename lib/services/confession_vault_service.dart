import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Šifrovaný trezor Spovedného zrkadla — **spovedné tajomstvo**.
///
/// Odpovede (zaškrtnuté otázky + poznámky per sekcia) NIKDY neopustia
/// zariadenie a na disku existujú výhradne šifrované. Architektúra
/// (docs/SPOVEDNE_ZRKADLO_STRATEGIA.md):
///
/// ```
/// PIN ── PBKDF2-HMAC-SHA256 (100k, náhodná soľ) ──▶ KEK
/// KEK ── AES-GCM unwrap ──▶ DEK (náhodný AES-256, drží sa len v pamäti)
/// DEK ── AES-GCM ──▶ šifrovaný blob odpovedí (flutter_secure_storage)
/// ```
///
/// · Overenie PIN-u = úspešné rozbalenie DEK (GCM autentifikácia) — žiadny
///   hash PIN-u sa neukladá.
/// · Biometria (voliteľná): kópia DEK v secure storage (Keychain/Keystore,
///   this-device-only) — číta sa až po úspešnom local_auth.
/// · „Vyspovedal som sa" = zmazanie bloba odpovedí (PIN/DEK ostáva).
/// · „Zabudol som PIN" = zmazanie všetkého (žiadne obnovenie — zámer).
/// · Storage je this-device-only → nič nejde do cloud záloh.
/// · V spovedných obrazovkách nie je ŽIADNA analytika.
class ConfessionVaultService {
  ConfessionVaultService._();
  static final ConfessionVaultService instance = ConfessionVaultService._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(),
  );

  static const _kSalt = 'confession_v1_salt';
  static const _kWrappedDek = 'confession_v1_wrapped_dek';
  static const _kDekBio = 'confession_v1_dek_bio'; // len ak je biometria zapnutá
  static const _kBlob = 'confession_v1_blob';

  static const _pbkdf2Iterations = 100000;

  final _aes = AesGcm.with256bits();
  final _localAuth = LocalAuthentication();

  /// DEK v pamäti — existuje len medzi unlock() a lock().
  SecretKey? _dek;

  bool get isUnlocked => _dek != null;

  // ── Stav trezoru ────────────────────────────────────────────────────────────

  /// Bol už nastavený PIN?
  Future<bool> isSetUp() async =>
      (await _storage.read(key: _kWrappedDek)) != null;

  /// Je zapnuté biometrické odomykanie?
  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _kDekBio)) != null;

  /// Je biometria na zariadení dostupná (senzor + nastavená)?
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  // ── Kryptografia (interné) ──────────────────────────────────────────────────

  Future<SecretKey> _deriveKek(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  /// Serializuje SecretBox (nonce + ciphertext + mac) do base64 JSON.
  String _encodeBox(SecretBox box) => jsonEncode({
    'n': base64Encode(box.nonce),
    'c': base64Encode(box.cipherText),
    'm': base64Encode(box.mac.bytes),
  });

  SecretBox _decodeBox(String encoded) {
    final j = jsonDecode(encoded) as Map<String, dynamic>;
    return SecretBox(
      base64Decode(j['c'] as String),
      nonce: base64Decode(j['n'] as String),
      mac: Mac(base64Decode(j['m'] as String)),
    );
  }

  // ── Nastavenie / odomykanie ─────────────────────────────────────────────────

  /// Prvé nastavenie PIN-u: vygeneruje soľ + náhodný DEK, DEK zabalí KEK-om.
  Future<void> setupPin(String pin, {bool enableBiometrics = false}) async {
    final salt = _aes.newNonce(); // 12 B náhodná soľ postačuje pre PBKDF2
    final kek = await _deriveKek(pin, salt);
    final dekKey = await _aes.newSecretKey();
    final dekBytes = await dekKey.extractBytes();

    final wrapped = await _aes.encrypt(
      dekBytes,
      secretKey: kek,
    );

    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(key: _kWrappedDek, value: _encodeBox(wrapped));
    if (enableBiometrics) {
      await _storage.write(key: _kDekBio, value: base64Encode(dekBytes));
    }
    _dek = SecretKey(dekBytes);
  }

  /// Odomknutie PIN-om. `false` = nesprávny PIN.
  Future<bool> unlockWithPin(String pin) async {
    final saltB64 = await _storage.read(key: _kSalt);
    final wrappedStr = await _storage.read(key: _kWrappedDek);
    if (saltB64 == null || wrappedStr == null) return false;
    try {
      final kek = await _deriveKek(pin, base64Decode(saltB64));
      final dekBytes = await _aes.decrypt(_decodeBox(wrappedStr), secretKey: kek);
      _dek = SecretKey(dekBytes);
      return true;
    } catch (_) {
      return false; // GCM MAC nesedí → zlý PIN
    }
  }

  /// Odomknutie biometriou (ak je zapnutá). `false` = zlyhalo/zrušené.
  Future<bool> unlockWithBiometrics(String localizedReason) async {
    final dekB64 = await _storage.read(key: _kDekBio);
    if (dekB64 == null) return false;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return false;
      _dek = SecretKey(base64Decode(dekB64));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Zapne/vypne biometrické odomykanie (vyžaduje odomknutý trezor).
  Future<void> setBiometricEnabled(bool enabled) async {
    final dek = _dek;
    if (dek == null) throw StateError('Vault locked');
    if (enabled) {
      final bytes = await dek.extractBytes();
      await _storage.write(key: _kDekBio, value: base64Encode(bytes));
    } else {
      await _storage.delete(key: _kDekBio);
    }
  }

  /// Zamkne trezor (DEK preč z pamäte) — pri odchode z obrazoviek/appky.
  void lock() {
    _dek = null;
  }

  // ── Dáta (odpovede) ─────────────────────────────────────────────────────────

  /// Uloží odpovede (šifrovane). Map: mirrorBase → {checked: [...], notes: {...}}.
  Future<void> saveData(Map<String, dynamic> data) async {
    final dek = _dek;
    if (dek == null) throw StateError('Vault locked');
    final box = await _aes.encrypt(utf8.encode(jsonEncode(data)), secretKey: dek);
    await _storage.write(key: _kBlob, value: _encodeBox(box));
  }

  /// Načíta odpovede; `{}` ak nič nie je uložené.
  Future<Map<String, dynamic>> loadData() async {
    final dek = _dek;
    if (dek == null) throw StateError('Vault locked');
    final blobStr = await _storage.read(key: _kBlob);
    if (blobStr == null) return {};
    try {
      final bytes = await _aes.decrypt(_decodeBox(blobStr), secretKey: dek);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// „Vyspovedal som sa" — zmaže odpovede, PIN (a biometria) ostávajú.
  Future<void> clearData() async {
    await _storage.delete(key: _kBlob);
  }

  /// „Zabudol som PIN / začať odznova" — zmaže VŠETKO (nenávratné).
  Future<void> wipeAll() async {
    _dek = null;
    await _storage.delete(key: _kBlob);
    await _storage.delete(key: _kWrappedDek);
    await _storage.delete(key: _kDekBio);
    await _storage.delete(key: _kSalt);
  }

  // ── FLAG_SECURE (Android) ───────────────────────────────────────────────────

  static const _secureChannel = MethodChannel('sk.lectio.divina/secure_screen');

  /// Zapne/vypne ochranu obrazovky (screenshoty, prepínač aplikácií).
  /// iOS kanál nemá — no-op (Keychain dáta chráni OS).
  static Future<void> setSecureScreen(bool enabled) async {
    try {
      await _secureChannel.invokeMethod(enabled ? 'enable' : 'disable');
    } catch (_) {
      // iOS / kanál nedostupný — ignoruj
    }
  }
}

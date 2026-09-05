import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

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
/// Blob sa nepodarilo dešifrovať alebo rozparsovať.
///
/// Zámerne samostatná výnimka: pôvodne sa každá takáto chyba menila na `{}`,
/// teda na stav nerozoznateľný od prázdneho trezoru. Používateľ videl prázdnu
/// prípravu a prvá ďalšia zmena prepísala kryptograficky platný blob prázdnou
/// mapou — nenávratná tichá strata.
class VaultCorruptedException implements Exception {
  const VaultCorruptedException();
  @override
  String toString() => 'VaultCorruptedException';
}

class ConfessionVaultService {
  ConfessionVaultService._();
  static final ConfessionVaultService instance = ConfessionVaultService._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(),
  );

  /// Úložisko pre biometrickú kópiu DEK.
  ///
  /// Oddelené zámerne: kľúč tu drží platforma pod user-auth podmienkou, takže
  /// ho operačný systém vydá až po overení. Predtým bola kópia v bežnom
  /// úložisku a `local_auth` prompt bol len UI brána — kľúč sa načítal ešte
  /// pred ním, takže proces s prístupom k úložisku ho prečítal bez biometrie.
  ///
  /// `biometryCurrentSet` na iOS znamená, že zmena zapísaných odtlačkov/tvárí
  /// kópiu zneplatní; na Androide to isté rieši `enforceBiometrics`. Nie je to
  /// strata dát — trezor sa vždy dá otvoriť PIN-om a biometria sa znova zapne.
  ///
  /// `resetOnError: false` je KRITICKÉ. Predvolené `true` znamená, že keď
  /// čítanie zlyhá, plugin dáta „ako poškodené" ZMAŽE. A zlyhanie tu nie je
  /// výnimočné: kľúč v Android keystore má okno platnosti overenia (log zo
  /// zariadenia: `KEY_USER_NOT_AUTHENTICATED ... timeout=5s`), takže stačí
  /// jeden pokus mimo okna a biometrická kópia DEK je nenávratne preč —
  /// biometria sa sama vypne a používateľ ju už nemá ako zapnúť späť.
  /// Presne to sa dialo: prvý raz po nastavení fungovala, po reštarte zmizla.
  /// S `false` sa chyba len vyhodí, kľúč prežije a dá sa skúsiť znova.
  static const _bioStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accessControlFlags: [AccessControlFlag.biometryCurrentSet],
    ),
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      resetOnError: false,
    ),
  );

  static const _kSalt = 'confession_v1_salt';
  static const _kWrappedDek = 'confession_v1_wrapped_dek';
  static const _kDekBio = 'confession_v1_dek_bio'; // len ak je biometria zapnutá
  static const _kBlob = 'confession_v1_blob';

  /// Príznak „biometria je zapnutá" v BEŽNOM úložisku.
  ///
  /// Zámerne nie v tom chránenom: na iOS si každý dotyk položky s
  /// `biometryCurrentSet` vypýta overenie zvlášť, takže samotné zisťovanie,
  /// či je biometria zapnutá, vyvolávalo ďalší prompt. Príznak nie je tajomstvo
  /// — hovorí len to, či ponúknuť tlačidlo. Kľúč ostáva chránený.
  static const _kBioFlag = 'confession_v1_bio_enabled';

  static const _pbkdf2Iterations = 100000;

  /// Marker inštalácie v SharedPreferences — tie sa pri odinštalovaní appky
  /// mažú VŽDY, na rozdiel od iOS Keychainu, ktorý odinštalovanie PREŽÍVA.
  static const _kInstallMarker = 'confession_vault_install_marker';

  /// iOS: Keychain prežíva odinštalovanie appky — bez tohto by PIN aj
  /// zašifrované odpovede ostali v zariadení aj po zmazaní appky (zistené
  /// 12.7.2026 na iPhone aj simulátore). Ak marker chýba → čerstvá
  /// inštalácia → zmaž všetky dáta trezoru. Volať pri štarte appky.
  Future<void> ensureWipedAfterReinstall() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kInstallMarker) ?? false) return;
    await wipeAll();
    await prefs.setBool(_kInstallMarker, true);
  }

  /// Presunie biometrickú kópiu DEK zo starého úložiska do toho, ktoré je
  /// viazané na biometriu.
  ///
  /// NEVOLAŤ pri štarte appky. Pôvodne sa to robilo v `main.dart` s tým, že kto
  /// používa iba biometriu, by inak PIN nikdy nezadal. Lenže zápis do úložiska
  /// viazaného na biometriu si vyžiada systémový prompt — ten sa preto zjavil
  /// hneď na home screene, mimo akéhokoľvek kontextu. A keď neprešiel, `catch`
  /// zmazal starú kópiu, takže odomykanie tvárou/odtlačkom po aktualizácii
  /// zmizlo a ostal len PIN. Presne to hlásili používatelia po 11.2 (vo verzii
  /// z obchodu to fungovalo).
  ///
  /// Volá sa preto až z `unlockWithPin`, kde je používateľ overený a prompt
  /// dáva zmysel. Kto sa dovtedy dostane dnu biometriou, používa starú kópiu
  /// cez fallback v [unlockWithBiometrics] — presun počká na najbližší PIN.
  Future<void> migrateLegacyStorage() async {
    try {
      final legacy = await _storage.read(key: _kDekBio);
      if (legacy == null) return;
      await _bioStorage.write(key: _kDekBio, value: legacy);
      // Starú kópiu zmažeme AŽ keď je nová overiteľne na mieste. Predtým sa
      // mazala aj pri zlyhaní zápisu, čím sa biometria nenávratne stratila.
      if (await _bioStorage.containsKey(key: _kDekBio)) {
        await _storage.delete(key: _kDekBio);
        appLogger.w('Vault: biometrická kópia presunutá do chráneného úložiska');
      }
    } catch (e) {
      // Stará kópia ZOSTÁVA — biometria funguje ďalej cez fallback a presun
      // sa skúsi znova. Radšej slabšie chránená kópia než žiadna biometria.
      appLogger.w('Vault: presun biometrickej kópie sa nepodaril: $e');
    }
  }

  final _aes = AesGcm.with256bits();
  final _localAuth = LocalAuthentication();

  /// DEK v pamäti — existuje len medzi unlock() a lock().
  SecretKey? _dek;

  /// Dokument odpovedí vlastní služba, nie obrazovka.
  ///
  /// Predtým robil každý zápis vlastný read-modify-write celého blobu. Dva
  /// súbežné zápisy (rýchle preklikanie, odchod do pozadia počas ukladania)
  /// tak vedeli prepísať novší stav starším snapshotom.
  Map<String, dynamic>? _doc;
  bool _docLoaded = false;

  /// Serializuje zápisy — vždy beží najviac jeden a v poradí zaradenia.
  Future<void> _writeChain = Future<void>.value();

  bool get isUnlocked => _dek != null;

  // ── Stav trezoru ────────────────────────────────────────────────────────────

  /// Bol už nastavený PIN?
  Future<bool> isSetUp() async =>
      (await _storage.read(key: _kWrappedDek)) != null;

  /// Je zapnuté biometrické odomykanie?
  ///
  /// `containsKey` zámerne namiesto `read` — samotné zistenie, či je biometria
  /// zapnutá, nesmie vyžadovať biometrické overenie.
  Future<bool> isBiometricEnabled() async {
    try {
      final flag = await _storage.read(key: _kBioFlag);
      if (flag != null) return flag == '1';
      // Staršia inštalácia bez príznaku: zisti raz (na iOS to stojí jeden
      // prompt) a výsledok si zapamätaj, nech sa to už neopakuje.
      final has = await _bioStorage.containsKey(key: _kDekBio) ||
          await _storage.containsKey(key: _kDekBio);
      await _storage.write(key: _kBioFlag, value: has ? '1' : '0');
      return has;
    } catch (e) {
      // Tichý `false` tu znamenal, že sa tlačidlo biometrie ani neponúkne a
      // nikto sa nedozvie prečo — dôvod preto aspoň zalogujeme.
      appLogger.w('Vault: isBiometricEnabled zlyhalo — $e');
      return false;
    }
  }

  /// Je biometria na zariadení dostupná (senzor + nastavená)?
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      appLogger.w('Vault: canCheckBiometrics=$canCheck isDeviceSupported=$supported');
      return canCheck && supported;
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
      // Zápis do úložiska viazaného na biometriu si vie vyžiadať systémový
      // prompt. Keď ho používateľ zruší (alebo sa nezobrazí), zápis padne a
      // biometria sa ticho nezapne — preto to musí byť v logu.
      try {
        await _bioStorage.write(key: _kDekBio, value: base64Encode(dekBytes));
        final ok = await _bioStorage.containsKey(key: _kDekBio);
        await _storage.write(key: _kBioFlag, value: ok ? '1' : '0');
        appLogger.w('Vault: setup — biometrická kópia zapísaná, overenie=$ok');
      } catch (e) {
        await _storage.write(key: _kBioFlag, value: '0');
        appLogger.w('Vault: setup — zápis biometrickej kópie padol: $e');
      }
    } else {
      await _storage.write(key: _kBioFlag, value: '0');
      appLogger.w('Vault: setup — biometria nebola zvolená (enableBiometrics=false)');
    }
    _dek = SecretKey(dekBytes);
    _doc = <String, dynamic>{};
    _docLoaded = true;
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
      await migrateLegacyStorage();
      return true;
    } catch (_) {
      return false; // GCM MAC nesedí → zlý PIN
    }
  }

  /// Odomknutie biometriou (ak je zapnutá). `false` = zlyhalo/zrušené.
  ///
  /// Kľúč sa načíta až PO úspešnom overení a z úložiska viazaného na
  /// biometriu, takže ho vydá operačný systém, nie naša podmienka v kóde.
  Future<bool> unlockWithBiometrics(String localizedReason) async {
    if (!await isBiometricEnabled()) {
      appLogger.w('Vault: biometria nie je zapnutá (kľúč v bio úložisku chýba)');
      return false;
    }
    try {
      // iOS si overenie vynúti SÁM pri čítaní položky z Keychainu
      // (`biometryCurrentSet`), takže náš prompt by bol druhý v poradí — presne
      // preto sa spoveď pýtala na Face ID viackrát za sebou. Na Androide ho
      // ponechávame: kľúč v keystore má okno platnosti overenia a čítanie mimo
      // neho končí na `KEY_USER_NOT_AUTHENTICATED`.
      if (Platform.isAndroid) {
        final ok = await _localAuth.authenticate(
          localizedReason: localizedReason,
          // local_auth 3.0: options sa sploštili do priamych parametrov,
          // stickyAuth → persistAcrossBackgrounding.
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!ok) {
          appLogger.w('Vault: local_auth overenie neprešlo (zrušené alebo zlyhalo)');
          return false;
        }
      }
      // Fallback na starú kópiu: kým presun neprebehne (alebo keď zlyhá),
      // musí biometria fungovať ďalej — tak sa správala verzia z obchodu.
      String? dekB64;
      try {
        dekB64 = await _bioStorage.read(key: _kDekBio);
      } catch (e) {
        appLogger.w('Vault: čítanie z chráneného úložiska padlo: $e');
      }
      dekB64 ??= await _storage.read(key: _kDekBio);
      if (dekB64 == null) {
        appLogger.w('Vault: overenie prešlo, ale kľúč sa nevrátil zo žiadneho úložiska');
        return false;
      }
      _dek = SecretKey(base64Decode(dekB64));
      return true;
    } catch (e) {
      // Napr. zmenená sada biometrie zneplatnila kľúč — používateľ sa dostane
      // dnu PIN-om a biometria sa pritom obnoví (viď unlockWithPin).
      appLogger.w('Vault: odomknutie biometriou padlo — $e');
      return false;
    }
  }

  /// Zapne/vypne biometrické odomykanie (vyžaduje odomknutý trezor).
  Future<void> setBiometricEnabled(bool enabled) async {
    final dek = _dek;
    if (dek == null) throw StateError('Vault locked');
    if (enabled) {
      final bytes = await dek.extractBytes();
      // Zámerne bez fallbacku na bežné úložisko: keď platforma kľúč viazaný na
      // biometriu neponúkne (Android < 9), radšej biometriu neponúknuť vôbec,
      // než sľubovať ochranu, ktorú by nedržala.
      await _bioStorage.write(key: _kDekBio, value: base64Encode(bytes));
      await _storage.write(key: _kBioFlag, value: '1');
    } else {
      await _bioStorage.delete(key: _kDekBio);
      await _storage.delete(key: _kDekBio); // aj prípadná stará kópia
      await _storage.write(key: _kBioFlag, value: '0');
    }
  }

  /// Zamkne trezor (DEK preč z pamäte) — pri odchode z obrazoviek/appky.
  ///
  /// Pozor: zahadzuje kľúč okamžite. Ak môžu byť rozpracované zápisy, volajte
  /// [flushAndLock].
  void lock() {
    _dek = null;
    _doc = null;
    _docLoaded = false;
  }

  // ── Dáta (odpovede) ─────────────────────────────────────────────────────────

  /// Načíta dokument odpovedí. Prvé volanie po odomknutí číta z úložiska,
  /// ďalšie vracajú tú istú inštanciu z pamäte.
  ///
  /// Vyhadzuje [VaultCorruptedException], ak sa blob nedá dešifrovať — NIKDY
  /// nevracia prázdnu mapu ako náhradu, pretože by ju nasledujúci zápis uložil
  /// namiesto pôvodných dát.
  Future<Map<String, dynamic>> loadData() async {
    final dek = _dek;
    if (dek == null) throw StateError('Vault locked');
    final cached = _doc;
    if (_docLoaded && cached != null) return cached;

    final blobStr = await _storage.read(key: _kBlob);
    if (blobStr == null) {
      _doc = <String, dynamic>{};
      _docLoaded = true;
      return _doc!;
    }
    try {
      final bytes = await _aes.decrypt(_decodeBox(blobStr), secretKey: dek);
      _doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      _docLoaded = true;
      return _doc!;
    } catch (_) {
      _doc = null;
      _docLoaded = false;
      throw const VaultCorruptedException();
    }
  }

  /// Zapíše jednu položku dokumentu (kľúč = id zrkadla) a zaradí uloženie.
  ///
  /// Mutácia je synchrónna, samotný zápis beží vo fronte. Vracia future, ktorý
  /// skončí po dokončení TOHTO zápisu; kto chce počkať na všetko, volá
  /// [flush].
  Future<void> updateEntry(String key, Map<String, dynamic> value) {
    if (_dek == null) return Future.error(StateError('Vault locked'));
    final doc = _doc;
    if (!_docLoaded || doc == null) {
      // Bez úspešne načítaného dokumentu sa nesmie zapisovať — inak by sa
      // poškodený alebo neprečítaný blob prepísal neúplným stavom.
      return Future.error(StateError('Vault document not loaded'));
    }
    doc[key] = value;
    return _enqueueWrite();
  }

  /// Odstráni položku dokumentu (napr. „začať prípravu odznova") a zaradí zápis.
  Future<void> removeEntry(String key) {
    if (_dek == null) return Future.error(StateError('Vault locked'));
    final doc = _doc;
    if (!_docLoaded || doc == null) {
      return Future.error(StateError('Vault document not loaded'));
    }
    doc.remove(key);
    return _enqueueWrite();
  }

  /// Zaradí zápis aktuálneho stavu dokumentu za posledný prebiehajúci.
  Future<void> _enqueueWrite() {
    final scheduled = _writeChain.then(
      (_) => _persistNow(),
      onError: (_) => _persistNow(),
    );
    // Reťaz musí prežiť aj neúspešný zápis, inak by sa ďalšie preskočili.
    _writeChain = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> _persistNow() async {
    final dek = _dek;
    final doc = _doc;
    if (dek == null) throw StateError('Vault locked');
    if (!_docLoaded || doc == null) throw StateError('Vault document not loaded');
    // Serializuje sa stav v čase behu, nie v čase zaradenia — starší zápis tak
    // nikdy neprepíše novší obsah.
    final box = await _aes.encrypt(utf8.encode(jsonEncode(doc)), secretKey: dek);
    await _storage.write(key: _kBlob, value: _encodeBox(box));
  }

  /// Počká na dokončenie všetkých zaradených zápisov. Nikdy nevyhadzuje.
  Future<void> flush() => _writeChain;

  /// Bezpečné zamknutie: najprv dopíše, až potom zahodí kľúč.
  ///
  /// `dispose()` nevie awaitovať, ale volať toto je aj tak korektné — poradie
  /// drží samotná služba, nie volajúci.
  Future<void> flushAndLock() async {
    try {
      await flush();
    } catch (_) {
      // stav chyby už rieši volajúci cez updateEntry
    }
    lock();
  }

  /// „Vyspovedal som sa" — zmaže odpovede, PIN (a biometria) ostávajú.
  Future<void> clearData() async {
    await flush();
    _doc = <String, dynamic>{};
    _docLoaded = _dek != null;
    await _storage.delete(key: _kBlob);
  }

  /// Zahodí poškodený blob a začne s prázdnym dokumentom.
  /// Volá sa len na výslovné potvrdenie používateľa po chybe dešifrovania.
  Future<void> discardCorruptedData() async {
    if (_dek == null) throw StateError('Vault locked');
    await _storage.delete(key: _kBlob);
    _doc = <String, dynamic>{};
    _docLoaded = true;
  }

  /// „Zabudol som PIN / začať odznova" — zmaže VŠETKO (nenávratné).
  Future<void> wipeAll() async {
    lock();
    await _storage.delete(key: _kBlob);
    await _storage.delete(key: _kWrappedDek);
    await _storage.delete(key: _kSalt);
    await _storage.delete(key: _kDekBio); // stará kópia pred migráciou
    try {
      await _bioStorage.delete(key: _kDekBio);
    } catch (_) {
      // Ak platforma položku neponúkne, nie je čo mazať.
    }
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

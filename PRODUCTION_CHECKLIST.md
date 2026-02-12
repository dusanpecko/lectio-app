# 📋 Production Checklist - Lectio Divina v10.0

> Posledná aktualizácia: 11. februára 2026

---

## 📊 Stav projektu

Projekt je v **veľmi dobrom stave** a blízko produkčnej pripravenosti.

- **Kvalita kódu**: `flutter analyze` hlási **0 problémov**
- **Štruktúra**: Čistý kód, len 3 menšie TODO v rosary
- **Bezpečnosť**: Žiadne hardcoded secrets, `.env` v `.gitignore`
- **Auth**: Email/heslo + Google OAuth + Apple Sign-In (natívny) ✅

---

## 🔴 KRITICKÉ - Pred vydaním

### Bezpečnosť ✅
- [x] **Keystore** - `android/key.properties` v `.gitignore`
- [x] **Žiadne hardcoded secrets** - `.env` v `.gitignore`, Supabase keys z env
- [x] **flutter_secure_storage** - credentials cez Keychain/Keystore

### iOS App Store ✅
- [x] **Privacy Descriptions v Info.plist**
  - [x] `NSCameraUsageDescription`
  - [x] `NSPhotoLibraryUsageDescription`
- [x] **Background Modes** - `audio`, `fetch`, `remote-notification`
- [x] **Apple Sign-In entitlement** - `com.apple.developer.applesignin`
- [x] **`ITSAppUsesNonExemptEncryption`** - pridať `NO` do Info.plist (HTTPS exempt) ✅

### Android ✅
- [x] **ProGuard/R8** - enabled pre release
- [x] **Signing** - release signing cez `key.properties`

### Audio ✅
- [x] **Background Audio playback** - `just_audio` + `just_audio_background`
- [x] **Lock screen controls** - Next/Previous/Play/Pause (Android + iOS)
- [x] **Seek slider** + progress tracking
- [x] **Auto-progression** medzi trackmi s medzihrami
- [x] **Offline playback** - lokálne uložené MP3
- [x] **Global Mini Player** - FAB na všetkých obrazovkách

---

## 🟡 VYSOKÁ PRIORITA

### Prihlásenie ✅
- [x] **Email/Heslo** - sign-in, sign-up, password reset
- [x] **Google Sign-In** - OAuth s deep link callback
- [x] **Apple Sign-In** - natívny flow s nonce (iOS/macOS)
- [x] **Guest Mode** - pokračovanie bez prihlásenia
- [x] **Remember Me** - flutter_secure_storage
- [x] **Zjednotený dizajn** - logo + rovnaké social tlačidlá
- [x] **Lokalizácia error hlášok** - google_sign_in_error, apple_sign_in_error, google_sign_in_timeout ✅

### Notifikácie ✅
- [x] **FCM Service** - init, token registrácia, foreground/background zobrazenie
- [x] **Notification Controller** - deep-link navigácia na 10+ obrazoviek
- [x] **Settings Screen** - FCM topics, denné lectio, prayer reminder s time picker
- [x] **Local Notifications** - timezone-aware scheduling, exact alarms
- [x] **Android permissions** - POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED
- [x] **iOS config** - remote-notification background mode
- [x] **Battery optimization exemption**
- [ ] **Duplicitná plugin inštancia** - `fcm_service.dart` globálna vs `LocalNotificationsService` singleton

### Kvalita kódu
- [x] **Lint** - 0 varovaní
- [x] **appLogger** - konzistentné logovanie namiesto print()
- [x] **CachedNetworkImage** - caching obrázkov
- [x] **mounted checks** - pred každým setState
- [x] **settings_screen.dart** - `deprecated_member_use` suppressed na celom súbore ✅
- [x] **auth_screen.dart** - tiché catch bloky bez logovania ✅
- [x] **globalAudioHandler** - nepoužitá premenná v background_audio_manager.dart ✅

---

## 🟢 STREDNÁ PRIORITA

### Obsah
- [x] **Offline Mode** - sťahovanie MP3, 14-dňová retencia
- [x] **Adorácie** - kompletná sekcia
- [x] **Ruženec** - prehrávania per desiatok


### UI
- [x] **Image Slider** - na home screene
- [x] **SpeedDial FAB** - Settings, Notes, Donation, About, Feedback, Notifications

### GDPR & Privacy ✅
- [x] **Privacy Screen** - expandovateľné sekcie, FCM token info, práva používateľa
- [x] **Delete Account** - potvrdenie → API → sign-out → redirect
- [x] **Privacy Policy link** - v nastaveniach

---

## 🔵 NÍZKA PRIORITA - Budúcnosť

### Roadmap v10.1+
- [ ] **Ruženec - záložky a zdieľanie** - zakomentované (TODO)
- [ ] **Ruženec - background audio** - nemá mini player ani background playback
- [ ] **Základné modlitby** - zoznam (Otčenáš, Zdravas'...)
- [ ] **Streak & Stats** - sledovanie pokroku, kalendár aktivity
- [ ] **Liturgický kalendár** - svätec dňa na home screene
- [ ] **Inbox** - systém správ od administrátorov
- [ ] **Semantics labels pre screen reader** - obrázky (`semanticLabel`), tlačidlá (`Semantics` widgety)
- [ ] **Banner na home screen** - dynamický widget s backend admin
- [ ] **Internacionalizácia** - infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov
- [ ] **Refactoring** - profile_screen (~2551), home_screen (~2054), lectio_screen rozdelenie

### Vyčistenie
- [x] Odstrániť `.bak` súbory z repo ✅
- [ ] Android namespace `com.example.lectio_divina` → zmeniť na produkčný (neblokuje publikáciu)

---

## 📦 BALÍČKY

### Aktualizované ✅
- [x] `carousel_slider` 5.1.1
- [x] `device_info_plus` 12.3.0
- [x] `google_sign_in` 7.2.0
- [x] `get_it` 9.2.0
- [x] `flutter_secure_storage` 10.0.0
- [x] `firebase_core` 4.3.0
- [x] `firebase_messaging` 16.1.0
- [x] `supabase_flutter` 2.12.0
- [x] `http` 1.6.0
- [x] `shared_preferences` 2.5.4

### Blokované / Beta
- [ ] `app_links` 6.4.1 → 7.0.0 ⚠️ (blokované supabase_flutter)
- [ ] `flutter_html` ^3.0.0-beta.2 ⚠️ beta
- [ ] `just_audio_background` 0.0.1-beta.17 ⚠️ beta

---

## ✅ HOTOVO - Funkčná výbava

- [x] **Lectio Divina** - denné čítania s audio
- [x] **Ruženec** - kategórie, desiatky, audio
- [x] **Adorácie** - nová sekcia
- [x] **Duchovný denník** - poznámky k meditáciám
- [x] **Spoločenstvo** - Prayer Wall a reakcie
- [x] **Duchovné cvičenia** - prihlášky
- [x] **Novinky** - správy a články
- [x] **Úmysly** - modlitebné úmysly
- [x] **Dary** - stránka s QR kódom a bankovým prevodom
- [x] **Profil** - avatar, údaje, predplatné, fakturačné údaje
- [x] **Nastavenia** - Biblia, jazyk, font, téma
- [x] **Feedback formulár** - v SpeedDial
- [x] **Umami Analytics**
- [x] **Firebase Crashlytics**
- [x] **CI/CD Pipeline** - GitHub Actions
- [x] **App ikony a Splash Screen**

---

## 📊 Progres

| Kategória | Hotovo | Celkom | % |
|-----------|--------|--------|---|
| Kritické | 8 | 9 | 89% |
| Vysoká priorita | 18 | 23 | 78% |
| Stredná priorita | 8 | 14 | 57% |
| Nízka priorita | 0 | 4 | 0% |
| Balíčky | 10 | 13 | 77% |

**Celkový progres: ~73%**

### ⚡ Na okamžité riešenie pred release:
1. iOS Info.plist `ITSAppUsesNonExemptEncryption` → `NO`
3. Duplicitná notifikačná plugin inštancia → zjednotiť
4. Lokalizovať hardcoded chybové hlášky v auth


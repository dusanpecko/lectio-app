# 📋 Production Checklist - Lectio Divina v10.0

> Posledná aktualizácia: 12. januára 2026

---

## 📊 Stav projektu

Projekt je v **excelentnom stave** a pripravený na nasadenie do produkcie.

- **Kvalita kódu**: `flutter analyze` hlási **0 problémov**
- **Štruktúra**: Čistý kód, žiadne `TODO`, `FIXME` alebo `HACK` komentári
- **CI/CD**: Plne automatizované pipelines pre build a testy
- **Testovanie**: Kritické toky sú pokryté (Unit, Widget, Integration)

---

## 🔴 KRITICKÉ - Pred vydaním ✅ HOTOVO

### Bezpečnosť
- [x] **Keystore** - `android/key.properties` v `.gitignore`, nikdy commitnutý

### iOS App Store
- [x] **Privacy Descriptions v Info.plist**
  - [x] `NSCameraUsageDescription`
  - [x] `NSPhotoLibraryUsageDescription`

### Audio
- [x] **Background Audio playback**
  - [x] Prehrávanie na zamknutej obrazovke
  - [x] Auto-progression medzi trackmi
  - [x] Next/Previous na lock screene (Android + iOS)
  - [x] Seek slider

---

## 🟡 VYSOKÁ PRIORITA

### Prístupnosť (Accessibility)
- [ ] **Semantics labels pre screen reader**
  - [ ] Obrázky - `semanticLabel`
  - [ ] Tlačidlá - `Semantics` widgety

### Kvalita kódu ✅
- [x] **Lint varovania opravené**
- [x] **debugPrint() nahradené s `appLogger`** (100+ výskytov v 16 súboroch)
- [x] **Image caching** - `CachedNetworkImage` v 11 súboroch

### Audio - Ruženec
- [ ] **Doladiť audio v Ruženci**
  - [ ] Skontrolovať plynulosť prehrávania
  - [ ] Synchronizácia UI so zvukom

---

## 🟢 STREDNÁ PRIORITA - Nové funkcie

### Notifikácie ✅
- [x] **Notifications Screen** - história prijatých notifikácií
  - [x] `notifications_screen.dart` so Supabase `notification_logs`
  - [x] SpeedDial menu + preklady SK/EN/ES

### Lokálne notifikácie
- [ ] **Plánovanie denných pripomienok**
  - [x] Scheduling (welcome 3d po registrácii, denné lectio 9:00, prayer reminder - custom čas)
  - [x] Badges na ikone
  - [x] Deep linking (payload → navigácia na LectioScreen / HomeScreen)
  - [x] Boot receiver (re-schedule po reštarte zariadenia)
  - [x] Battery optimization exemption
  - [x] Exact alarm permission (Android 13+)
  - [x] Notification settings UI (lokálne + FCM topics)
  - [x] Cache lectio dát pre notifikácie (12h validita)
  - [x] macOS support (DarwinNotificationDetails)

### Obsah
- [x] **Offline Mode** - sťahovanie MP3
  - [x] `download_service` - `AudioDownloadService` s HTTP streaming
  - [x] Lokálne úložisko - `path_provider` + SharedPreferences metadata
  - [x] UI indikátor stiahnutia - `DownloadStatusIcon`, `OfflineAudioBanner`, `AudioDownloadProgress`

- [ ] **Adorácie** - nová sekcia
  - [ ] Backend + Flutter obrazovky

- [ ] **Základné modlitby**
  - [ ] Zoznam modlitieb (Otčenáš, Zdravas'...)
  - [ ] Viacjazyčná podpora

### UI
- [ ] **Banner na home screen**
  - [ ] Dynamický widget
  - [ ] Backend administrácia

### Kvalita kódu - Refactoring
- [ ] **FÁZA 1: LectioScreen refactoring** (pred produkciou - 4-6h)
  - [ ] `LectioAudioState` Provider/Controller - audio state & logika (~800 riadkov)
  - [ ] `LectioFloatingPlayer` Widget - floating audio player UI (~650 riadkov)
  - [ ] `LectioDownloadHandler` Mixin - download logika & dialógy (~400 riadkov)
  - [ ] Cieľ: znížiť lectio_screen.dart z 3278 → ~1400 riadkov (57% ↓)

- [ ] **FÁZA 2: LectioScreen refactoring** (po produkcii - 2-3h)
  - [ ] `LectioDndHelper` - DND toggle & iOS instructions (~200 riadkov)
  - [ ] `LectioDataProvider` - data fetching, cache, offline/online (~300 riadkov)
  - [ ] Cieľ: znížiť lectio_screen.dart na ~900 riadkov (72% ↓ celkovo)

---

## 🔵 NÍZKA PRIORITA - Budúcnosť

### Internacionalizácia
- [ ] Pripraviť infraštruktúru pre FR, PT, DE, PL, IT
- [ ] Export textov pre prekladateľov

### Roadmap v10.1+
- [ ] **Streak & Stats** - sledovanie pokroku, kalendár aktivity
- [ ] **Liturgický kalendár** - svätec dňa na home screene
- [ ] **Inbox** - systém správ od administrátorov

---

## 📦 BALÍČKY - Upgrade

- [ ] `app_links` 6.4.1 → 7.0.0 ⚠️ (blokované supabase_flutter)
- [x] `carousel_slider` 4.2.1 → 5.1.1 ✅
- [x] `device_info_plus` 10.1.2 → 12.3.0 ✅
- [x] `google_sign_in` 6.3.0 → 7.2.0 ✅
- [x] `get_it` 8.2.0 → 9.2.0 ✅
- [x] `flutter_secure_storage` 9.2.4 → 10.0.0 ✅
- [x] `firebase_core` 4.1.1 → 4.3.0 ✅
- [x] `firebase_messaging` 16.0.2 → 16.1.0 ✅
- [x] `supabase_flutter` 2.10.3 → 2.12.0 ✅
- [x] `http` 1.5.0 → 1.6.0 ✅
- [x] `image` 4.5.4 → 4.7.2 ✅
- [x] `shared_preferences` 2.5.3 → 2.5.4 ✅

---

## ✅ HOTOVO - Existujúce funkcie

### Funkčná výbava
- [x] **Duchovný denník** - poznámky k meditáciám
- [x] **Spoločenstvo** - Prayer Wall a reakcie komunity
- [x] **Prístupnosť** - zväčšovanie písma, Light/Dark témy
- [x] **Zmazanie účtu** - GDPR compliant
- [x] **Feedback formulár** - v SpeedDial menu
- [x] **Umami Analytics** - Umami Cloud

### Technická výbava
- [x] **LectioScreen refaktoring** - `LectioAudioController`, `MiniAudioPlayer`, `LectioDataService`
- [x] **Audio Core** - `just_audio` + `just_audio_background`
- [x] **Firebase Crashlytics**
- [x] **CI/CD Pipeline** - GitHub Actions
- [x] **ProGuard/R8** konfigurácia
- [x] **App ikony a Splash Screen**

---

## 📊 Progres

| Kategória | Hotovo | Celkom | % |
|-----------|--------|--------|---|
| Kritické | 3 | 3 | ✅ 100% |
| Vysoká priorita | 4 | 6 | 67% |
| Stredná priorita | 2 | 8 | 25% |
| Nízka priorita | 0 | 3 | 0% |
| Balíčky | 11 | 12 | ✅ 92% |

**Celkový progres: ~63%**

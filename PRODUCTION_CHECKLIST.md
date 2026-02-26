# 📋 Production Checklist - Lectio Divina v10.0.1+5000008

> Posledná aktualizácia: 19. februára 2026

---

## 📊 Stav projektu

**Pripravené na PRODUCTION RELEASE** ✅

- **Kvalita kódu**: `flutter analyze` hlási **0 problémov**
- **Štruktúra**: Čistý kód, minimálne TODO položky
- **Bezpečnosť**: Žiadne hardcoded secrets, `.env` v `.gitignore`
- **Auth**: Email/heslo + Google OAuth + Apple Sign-In ✅
- **Onboarding**: 5 slidov, plne funkčný ✅
- **Notifikácie**: FCM + Local + Timezone-aware ✅

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
- [x] **Duplicitná plugin inštancia** - `fcm_service.dart` globálna odstránená, background handler inicializuje lokálnu inštanciu ✅

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

## 🐛 OPRAVY V v10.0.1+5000008

### 1. FAB menu preklady ✅
- [x] **Problém**: V FAB menu boli hardkódované slovenské texty namiesto prekladových kľúčov
- [x] **Priorita**: 🟡 Stredná (UX problém v internacionálnej verzii)
- [x] **Riešenie**: Nahradené hardcoded stringy prekladovými kľúčmi (`tr()`)
- [x] **Implementácia**:
  - **lectio_speed_dial_fab.dart**: Zmenené `'Obnoviť'` → `tr('common.refresh')`, `'Audio prehrávač'` → `tr('audio_player')`, `'Zrušiť Nerušiť'` → `tr('dnd.turn_off')`, `'Aktivovať Nerušiť'` → `tr('dnd.turn_on')`, `'Pridať poznámku'` → `tr('add_note')`

### 2. Likes a komentáre v novinkách ✅
- [x] **Problém**: PostgrestException 42501 - RLS polícia blokovala INSERT do `news_likes` a `news_comments`
- [x] **Priorita**: 🔴 Vysoká (blokuje funkciu pre všetkých používateľov)
- [x] **Riešenie**: Pridané RLS politiky pre authenticated users
- [x] **Implementácia (Backend)**:
  - **sql/fix_news_likes_rls.sql**: Pridané `authenticated_insert_news_likes`, `users_delete_own_likes`
  - **sql/fix_news_comments_rls.sql**: Pridané `authenticated_insert_news_comments`, `users_delete_own_comments`, `admins_delete_any_comments`
  - **sql/run-fix-news-rls.sh**: Helper script pre spustenie SQL

### 3. Language switch flash ✅
- [x] **Problém**: Červená error obrazovka preblikla pri zmene jazyka v nastaveniach
- [x] **Priorita**: 🟡 Stredná (vizuálny bug)
- [x] **Riešenie**: Odstránené duplicitné `setState` volania, použitý `Future.microtask()` pre odloženie state update
- [x] **Implementácia**:
  - **settings_screen.dart**: `_handleLanguageChange()` - state update cez microtask, `_onLanguageChanged()` - odstránená duplicitná logika nastavenia biblie

---

## � KRITICKÉ CHYBY - v10.0.0.5000007

### 1. Onboarding — Google prihlásenie presmeruje späť na poslednú slide ✅
- [x] **Problém**: Po úspešnom prihlásení cez Google sa používateľ vráti na poslednú stranu onboarding slideshow namiesto toho, aby bol presmerovaný do aplikácie
- [x] **Priorita**: 🔴 Vysoká (blokuje nových používateľov)
- [x] **Riešenie**: Pridaný `_monitorAuthState()` ktorý počúva auth state changes a po úspešnom prihlásení volá `widget.onComplete()`
- [x] **Implementácia**:
  - Pridaný `StreamSubscription<AuthState>` do `_Slide5State`
  - Metóda `_monitorAuthState()` kontroluje aktuálnu session a naslúcha zmenám
  - Po `AuthChangeEvent.signedIn` sa zavolá `widget.onComplete()`
  - Timeout 120 sekúnd pre OAuth flow
  - Disposal subscription v `dispose()`

### 2. Heslo — chýba tlačidlo „zobraziť heslo" (oko) ✅
- [x] **Problém**: Pri zadávaní hesla nie je dostupná ikona oka na zobrazenie/skrytie hesla
- [x] **Priorita**: 🟡 Stredná (UX problém)
- [x] **Riešenie**: Pridaný `suffixIcon` s ikonkou oka a toggle pre `obscureText` na všetkých password poliach
- [x] **Implementácia**:
  - **auth_screen.dart**: Pridaná `bool _obscurePassword` a visibility toggle na password poli
  - **profile_screen.dart**: Pridané 3 samostatné bool premenné (`obscureCurrentPass`, `obscureNewPass`, `obscureConfirmPass`) pre changePassword dialóg
  - Ikona sa mení medzi `visibility_outlined` a `visibility_off_outlined`
  - Toggle funguje cez `setState()` v oboch prípadoch


---

## �🔵 NÍZKA PRIORITA - Budúcnosť

### Pred finálnym releaseom
- [x] **Vrátiť cron na `0 * * * *`** ✅ - send-daily-lectio beží každú hodinu (send-scheduled-notifications ostáva každú minútu)
- [x] **Onboarding (First Launch)** ✅ - 5 slidov, skip tlačidlo, ilustrácie, plná funkcionalita
  - [x] Slide 1 – Uvítanie: logo, motto „Božie slovo", obrázok slide1.webp
  - [x] Slide 2 – Denné čítania: kalendár + interaktívny FAB menu demo
  - [x] Slide 3 – Čo je Lectio Divina: 4 kroky s animovaným kruhom (Lectio, Meditatio, Oratio, Contemplatio)
  - [x] Slide 4 – Pripomienky: výber času dennej pripomienky s time pickerom, FCM permissions
  - [x] Slide 5 – Prihlásenie: Apple Sign-In, Google OAuth, Email/Heslo + možnosť preskočiť (Guest mode)
  - [x] Background obrázky (pozadie_slide.png, slide1.webp)
  - [x] `shared_preferences` flag `onboarding_completed` (cez onComplete callback)
  - [x] Dots navigation indicator
  - [x] Next/Skip buttons

### Roadmap v10.1+
- [ ] **Audio player lifecycle (staršie Android)** - Na starších Android zariadeniach (8/9 a nižšie) sa media player nezatvára po zatvorení aplikácie na zamknutej obrazovke. Možná príčina: nesprávne spravovaný AudioSession / MediaSession lifecycle. Na preskúmanie: správanie `just_audio` / `audio_service` pluginu pri lifecycle eventoch.
- [ ] **Edge-to-edge zobrazenie** - Flutter framework issue (`setStatusBarColor`, `setNavigationBarColor`, `setNavigationBarDividerColor` deprecated v Android 15). Opraví sa v budúcich verziách Fluttera, momentálne ignorovať.

### Roadmap v10.2+
- [ ] **FCM Token Cleanup Cron** - periodická očista starých/neplatných tokenov (90+ dní neaktívne)
- [ ] **Ruženec - záložky a zdieľanie** - zakomentované (TODO)
- [ ] **Ruženec - background audio** - nemá mini player ani background playback
- [ ] **Základné modlitby** - zoznam (Otčenáš, Zdravas'...)

### Roadmap v10.3+
- [ ] **Streak & Stats** - sledovanie pokroku, kalendár aktivity
- [ ] **Liturgický kalendár** - svätec dňa na home screene
- [ ] **Inbox** - systém správ od administrátorov
- [ ] **Semantics labels pre screen reader** - obrázky (`semanticLabel`), tlačidlá (`Semantics` widgety)

### Roadmap v10.4+
- [ ] **Banner na home screen** - dynamický widget s backend admin
- [ ] **Internacionalizácia** - infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov
- [ ] **Refactoring** - profile_screen (~2551), home_screen (~2054), lectio_screen rozdelenie

### Roadmap v10.5+ 🎓
- [ ] **Teologické prehĺbenie (Magisterium AI)** - Voliteľná sekcia pod Actio s AI-generovaným teologickým komentárom k dennému evanjeliu. Integrácia Magisterium API (28 000+ cirkevných dokumentov) + ChatGPT/Claude pre prepis do štruktúrovaných 4 blokov: Teologické jadro, Cirkevní Otcovia, KKC, Dokumenty Cirkvi. Generovanie 1x denne per jazyk, cache v DB, editovateľné adminom. **Nie chatbot interface** - len akademické prehĺbenie s povinnými zdrojmi. Detaily: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`  - ✅ **Bude teologická validácia** - Draft → Teológ schvaľuje → Publikácia
  - ✅ **Budget pokryje API costs** - Kalkulácia 365 dní × 5 jazykov, premium model €2-3/mesiac
  - ✅ **Users to budú skutočne používať** - Pilot 100-200 users, 2-4 týždne, meranie engagement
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
| **Kritické chyby v10.0.0.5000007** | **2** | **2** | **100%** |
| **Opravy v10.0.1+5000008** | **3** | **3** | **100%** |
| Vysoká priorita | 18 | 23 | 78% |
| Stredná priorita | 8 | 14 | 57% |
| Nízka priorita | 3 | 17 | 18% |
| Balíčky | 10 | 13 | 77% |

**Celkový progres: ~78%**

### ⚡ Všetky kritické chyby v10.0.0.5000007 OPRAVENÉ! ✅
1. ✅ **Onboarding Google redirect** - Auth state monitoring + widget.onComplete()
2. ✅ **Password visibility toggle** - Ikona oka na všetkých password poliach

### 🐛 Všetky opravy v10.0.1+5000008 IMPLEMENTOVANÉ! ✅
1. ✅ **FAB menu preklady** - Hardcoded SK texty nahradené tr() kľúčmi
2. ✅ **Likes a komentáre RLS** - PostgrestException 42501 opravený na backend
3. ✅ **Language switch flash** - Odstránený červený flash efekt

**Audio player lifecycle** presunutý do roadmap v10.1+ (nekritické pre release)


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

### Roadmap v10.1+ - marec 2026
- [x] **Krížová cesta** - Nová sekcia s PageView swipe navigáciou, hero obrázkami zastavení, kolapsovateľný SliverAppBar, bodkové indikátory, rímske čísla, HTML obsah s app fontom, lectio-štýlový audio prehrávač s `ConcatenatingAudioSource` playlistom, lock screen artwork, carousel karta na home screene.
- [x] **Audio player lifecycle (staršie Android)** - Na starších Android zariadeniach (8/9 a nižšie) sa media player nezatvára po zatvorení aplikácie na zamknutej obrazovke. Možná príčina: nesprávne spravovaný AudioSession / MediaSession lifecycle. Na preskúmanie: správanie `just_audio` / `audio_service` pluginu pri lifecycle eventoch.
- [x] **Edge-to-edge zobrazenie** - ✅ Pridané `values-v35`/`values-night-v35` štýly, odstránené deprecated volania z nášho kódu. Zvyšné deprecated API volania sú interné vo Flutter frameworku (`FlutterFragmentActivity`, `PlatformPlugin`) a Google Play Services — opravia sa v budúcich verziách.
- [x] **Stránka newsletterov** - Nová sekcia v aplikácii a na webe pre zobrazenie newsletterov (zoznam + detail)
- [x] **Notifikácie pri novom newsletteri** - Push notifikácia používateľom keď sa objaví nový newsletter

### Roadmap v10.1.1 - marec 2026 — Primárny jazyk EN

#### ✅ Engagement & Notifikácie (10.1.1)

**App Rating Prompt**
- [x] **AppEngagementService** — Nová služba `lib/services/app_engagement_service.dart`
  - Singleton, SharedPreferences pre tracking otvorení LectioScreen
  - Po 5 otvoreniach zobrazí natívny in-app review dialóg (App Store / Google Play)
  - Smart cooldown: ak user odmietne, znova po 90 dňoch
  - Fallback na store URL ak in-app review nie je dostupný
- [x] **LectioScreen integrácia** — Volanie `AppEngagementService.instance.onLectioScreenOpened(context)` v `initState` s post-frame callback

**Support/Donation Prompt**
- [x] **Výzva na podporu** — Každých 10 otvorení LectioScreen
  - Preskočí sa pre aktívnych supporter-ov (Priateľ/Friend, Patrón/Patron, Zakladateľ/Founder)
  - Kontroluje `subscriptions` tabuľku v Supabase
  - Cooldown 30 dní medzi zobrazeniami
  - Navigácia na DonationScreen po potvrdení

**Technical Notifications Category**
- [x] **NotificationCategory enum** — Pridané `technical` do `notification_models.dart`
- [x] **SQL migrácia** — `backend/sql/add_technical_notification_topic.sql` — témy "Technické oznamy" a "Aktualizácie aplikácie"
- [x] **Preklady** — Pridané `notifications.category.technical` do sk/en/es.json

**Deep Link URL Support**
- [x] **NotificationController** — Pridané `url` case do `navigateToScreen()` s `url_launcher`
- [x] **Priamy URL handling** — `handleRemoteNotificationTap()` a `handleLocalNotificationTap()` podporujú `url` field v notification data
- [x] **`_openUrl()` metóda** — Otvorí externý URL z notifikácie

**Preklady**
- [x] **engagement.rating.\*** — sk/en/es.json (title, message, rate_now, later)
- [x] **engagement.support.\*** — sk/en/es.json (title, message, tiers, support_now, later)

> **Cieľ:** Zmeniť predvolený/fallback jazyk z `sk` na `en`, aby anglickí používatelia mali natívny zážitok bez fallbacku na slovenčinu. Slovenčina zostáva plne podporovaná, ale už nie je hardcoded default.

#### 📱 Mobile (Flutter)

**Onboarding — language picker + onboarding / onboarding_update**
- [ ] **main.dart** — Zmeniť `onboarding_completed` (bool) na **`onboarding_version`** (int):
  - `version == 0` → nový user → **language picker → plný onboarding**
  - `version < CURRENT_VERSION` → existujúci user po update → **language picker → onboarding_update** (len novinky)
  - Po dokončení uložiť `onboarding_version = CURRENT_ONBOARDING_VERSION`
  - Konštanta `CURRENT_ONBOARDING_VERSION = 2` (zvýšiť pri každej zmene)
- [ ] **LanguagePickerScreen** — nový widget, prvá obrazovka vždy (nový aj update):
  - Vlajky/ikony: 🇬🇧 English, 🇸🇰 Slovenčina, 🇪🇸 Español
  - Upozornenie: *"Português (pt-BR) e Français (fr) — coming June 2026"* (šedý text, disabled)
  - Predvolený výber podľa systémového jazyka (ak je podporovaný)
  - Uloží do `shared_preferences` a nastaví `EasyLocalization` locale
  - Po potvrdení → navigácia na `OnboardingScreen` alebo `OnboardingUpdateScreen`
- [ ] **OnboardingScreen** — existujúci plný onboarding (5 slidov), spustí sa len pre nových používateľov
  - Všetky texty v jazyku zvolenom v language pickeri
- [ ] **OnboardingUpdateScreen** — nový widget, krátky "What's new" onboarding pre existujúcich:
  - 1-2 slidy s novinkami verzie (napr. "Zmenili sme predvolený jazyk", "Nové funkcie")
  - Možnosť zmeniť jazyk aj tu (link späť na language picker)
  - Tlačidlo "Pokračovať" → zavrieť a ísť do appky
  - Obsah slidov parametrický — ľahko pridať nový slide pri budúcom update

**Flow:**
```
Nový user:     LanguagePicker → OnboardingScreen (5 slidov) → Appka
Update user:   LanguagePicker → OnboardingUpdateScreen (1-2 slidy) → Appka
Aktuálny user: Priamo do Appky (version == CURRENT)
```

**Lokalizácia & bootstrap**
- [ ] **main.dart L41, L44** — `supportedLanguages` poradie `['en', 'sk', 'es']`, fallback `'en'`
- [ ] **main.dart L112, L114** — `supportedLocales: [Locale('en'), Locale('sk'), ...]`, `fallbackLocale: Locale('en')`
- [ ] **main.dart L184, L186** — rovnaký pattern (druhý `MaterialApp` blok)
- [ ] **bootstrap.dart L52, L54, L104, L106** — `supportedLocales` + `fallbackLocale` → `en`
- [ ] **bootstrap.dart L117, L120** — `supportedLanguages` + fallback → `en`
- [ ] **theme_provider.dart L138, L141** — `supportedLanguages` + fallback → `en`

**Dátové služby — fallback queries**
- [ ] **lectio_data_service.dart** (L47, L52, L233, L238, L264, L270, L334, L342, L352) — fallback `locale != 'sk'` → `locale != 'en'`, `.eq('locale_code'/'lang', 'sk')` → `'en'`
- [ ] **lectio_cache_service.dart** (L231, L236) — rovnaký fallback pattern
- [ ] **home_screen.dart** (L236, L241, L324, L332, L342) — fallback queries na `'en'`
- [ ] **lectio_screen.dart** (L1306, L1311, L1337, L1343, L1438, L1444, L1455) — fallback queries na `'en'`

**Notifikácie**
- [ ] **local_notifications_service.dart L521** — `texts['sk']` → `texts['en']` ako fallback
- [ ] **local_notifications_service.dart L537** — `return 'sk'` → `return 'en'` v `_getCurrentLanguage()`

**Modely — JSON parsing defaults**
- [ ] **rosary_model.dart L84** — `?? 'sk'` → `?? 'en'`
- [ ] **adoration_model.dart L73** — `?? 'sk'` → `?? 'en'`
- [ ] **stations_of_cross_model.dart L46** — `?? 'sk'` → `?? 'en'`
- [ ] **lectio_audio_track.dart L84, L99** — zmeniť `sk`-specific label logiku na `en`-first

**Obrazovky**
- [ ] **notifications_screen.dart L78** — `localeIdMap` zostáva (mapovanie ID), overiť poradie
- [ ] **spiritual_exercise_detail_screen.dart L117** — `DateFormat('d. MMMM yyyy', 'sk')` → použiť aktuálny locale

#### 🌐 Backend (Next.js)

**Core — LanguageProvider & layout**
- [ ] **LanguageProvider.tsx L14, L21** — default context `'en'`, `useState('en')`
- [ ] **layout.tsx L27** — `<html lang="en">`
- [ ] **layout.tsx L69** — `geo.region` — ponechať `SK` (server je v SK) alebo odstrániť
- [ ] **layout.tsx L78** — `og:locale` → `en_US`

**API routes — default lang parameter**
- [ ] **api/lectio/route.ts L32** — `|| "sk"` → `|| "en"`
- [ ] **api/lectio/today/route.ts L35** — `|| 'sk'` → `|| 'en'`
- [ ] **api/lectio-sources/route.ts L14** — `|| "sk"` → `|| "en"`
- [ ] **api/news/route.ts L13** — `|| "sk"` → `|| "en"`
- [ ] **api/public/newsletters/route.ts L21** — `|| 'sk'` → `|| 'en'`
- [ ] **api/feedback/route.ts L46** — `|| 'sk'` → `|| 'en'`

**API routes — fallback logic**
- [ ] **api/lectio/route.ts** (L59, L64, L71, L118, L123, L182, L187, L205) — všetky fallback queries `'sk'` → `'en'`
- [ ] **api/lectio/today/route.ts** (L61, L66, L92, L98, L103, L167, L173, L186) — všetky fallback queries `'sk'` → `'en'`

**Lectio page (web)**
- [ ] **lectio/page.tsx** (L258, L264, L281, L325, L331, L354, L361, L371, L375) — fallback queries `'sk'` → `'en'`

**Cron & notifikácie**
- [ ] **cron/send-scheduled-notifications/route.ts L133, L325** — `|| 'sk'` → `|| 'en'`
- [ ] **newsletter/campaigns/send/route.ts L194, L251, L269** — `|| 'sk'` → `|| 'en'`

**TTS & kontakt**
- [ ] **text-to-speech/route.ts L146, L150** — default language detection → `'en'`
- [ ] **contact/route.ts L198, L238, L414** — default parameter `'sk'` → `'en'`
- [ ] **email-sender.ts L78** — `locale = 'sk'` → `locale = 'en'`

**Utility & metadata**
- [ ] **dateFormatter.ts L55, L101** — default `lang = 'sk'` → `lang = 'en'`
- [ ] **metadata.ts L31, L41, L47** — default locale + URL routing logic
- [ ] **DatePickerModal.tsx L35** — `locale = 'sk'` → `locale = 'en'`
- [ ] **VoiceSelector.tsx L39** — `language = 'sk'` → `language = 'en'`
- [ ] **AudioGenerateButton.tsx L30** — `language = 'sk'` → `language = 'en'`
- [ ] **notes/layout.tsx L11, L17** — metadata default → `'en'`

**Admin UI**
- [ ] **admin/notifications/new/page.tsx L69, L341** — default form `locale: 'en'`
- [ ] **admin/content_cards/page.tsx L73, L191** — default filter/import lang
- [ ] **admin/content_cards/[id]/page.tsx L66, L322** — default card lang
- [ ] **admin/lectio-sources/page.tsx L448, L562** — default filter lang
- [ ] **admin/lectio-sources/[id]/page.tsx** (L771, L943, L969, L995, L1021, L1047) — audio component language
- [ ] **admin/rosary/page.tsx L544** — import fallback
- [ ] **admin/rosary/[id]/page.tsx** (L1220–L1621, 8 miest) — audio component language
- [ ] **admin/rosary/[id]/components/SaveButtonsSection.tsx L124** — currentLang fallback
- [ ] **admin/liturgical-calendar/page.tsx** (L192, L685, L703, L954, L1476, L1490) — hardcoded `'sk'` → `'en'`
- [ ] **profile/page.tsx L653, L662** — switch default → `name_en` / `description_en`

**Ostatné**
- [ ] **checkout/page.tsx L30, L49** — `country: 'SK'` — zvážiť detekciu krajiny
- [ ] **api/checkout/products/route.ts L178** — `product.name.sk` → `product.name.en`
- [ ] **support/2-percenta/page.tsx L187** — translation fallback → `en`
- [ ] **api/create-beta-table/route.ts L19** — DB schema `DEFAULT 'sk'` → `DEFAULT 'en'`
- [ ] **rosary-utils.ts L35, L226** — poradie + default parameter
- [ ] **adoracia-utils.ts L25** — poradie `['en', 'sk', ...]`

#### ⚠️ Predpoklady & riziká
- [ ] **Overiť EN obsah v DB** — lectio_sources, liturgical_calendar, rosary, adorácie musia mať anglický obsah pre všetky dni, inak sa fallback na `en` zobrazí prázdno
- [ ] **Testovať nového používateľa** — onboarding flow s EN defaultom
- [ ] **Testovať existujúceho SK používateľa** — jazyk musí zostať `sk` (uložený v preferences)
- [ ] **SEO dopad** — zmena `<html lang>` a `og:locale` ovplyvní indexovanie

### Roadmap v10.2+ apríl 2026
- [ ] **FCM Token Cleanup Cron** - periodická očista starých/neplatných tokenov (90+ dní neaktívne)
- [ ] **Ruženec - záložky a zdieľanie** - zakomentované (TODO)
- [ ] **Ruženec - background audio** - nemá mini player ani background playback
- [ ] **Základné modlitby** - zoznam (Otčenáš, Zdravas'...)
- [ ] **Brazílska portugalčina (pt-BR) - obsah** - tvorba liturgického kalendára, lectio-sources, krížové cesty, adorácie, modlitby
- [ ] **Jednoduché návody** - krátke videá alebo pop-up okná „Vedeli ste, že..." (onboarding tipy, feature discovery)

### Roadmap v10.3+ máj 2026
- [ ] **Streak & Stats** - sledovanie pokroku, kalendár aktivity
- [ ] **Liturgický kalendár** - svätec dňa na home screene
- [ ] **Inbox** - systém správ od administrátorov
- [ ] **Semantics labels pre screen reader** - obrázky (`semanticLabel`), tlačidlá (`Semantics` widgety)
- [ ] **Brazílska portugalčina (pt-BR) - web + marketing** - preklad webu parochia + marketingová kampaň zacielená na Brazíliu
- [ ] **Francúzština (fr-FR) - obsah** - tvorba liturgického kalendára, lectio-sources, krížové cesty, adorácie, modlitby

### Roadmap v10.4+ jún 2026
- [ ] **Banner na home screen** - dynamický widget s backend admin
- [ ] **Internacionalizácia** - infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov
- [ ] **Refactoring** - profile_screen (~2551), home_screen (~2054), lectio_screen rozdelenie
- [ ] **Brazílska portugalčina (pt-BR) - preklad aplikácie** - lokalizácia všetkých stringov v mobilnej aplikácii
- [ ] **Francúzština (fr-FR) - web + aplikácia + marketing** - preklad webu, lokalizácia mobilnej aplikácie, marketingová kampaň

### Roadmap v10.5+ 🎓 september 2026
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


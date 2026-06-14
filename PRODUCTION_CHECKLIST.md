# 📋 Production Checklist & Roadmap — Lectio Divina

> **Jediný zdroj pravdy** pre stav projektu (mobil Flutter + backend Next.js).
> Posledná aktualizácia: **3. jún 2026** · Verzia mobilu: **v10.1.2+5000013**

**Legenda:** `[ ]` = treba urobiť · `[x]` = hotové · ⚠️ = blokované / na overenie

---

# 🎯 ČO TREBA UROBIŤ (priorita)

## 🐛 Známe problémy / chyby

- [ ] **Android BackgroundAudioManager fallback** (nízka) — staršie Android (8/9) nezatvárajú media player po zatvorení appky na zamknutej obrazovke.
- [ ] **Android namespace** `com.example.lectio_divina` → zmeniť na produkčný (neblokuje publikáciu).

## 🖥️ Backend (Next.js) — produkčné odporúčania

> Odvodené z finančného hodnotenia (3. jún 2026). Zvyšujú zrelosť a spoľahlivosť produkčnej prevádzky.

- [ ] **Monitoring & error tracking** (Vysoká) — Sentry: automatické zachytávanie chýb v produkcii (stack trace, kontext, frekvencia).
- [ ] **Štruktúrované logovanie** (Vysoká) — Pino / Winston: nahradiť `console.log` JSON logmi (filtrovateľné, archivovateľné).
- [ ] **Automatizované testy backendu** (Vysoká) — Vitest / Jest: pokryť kritické endpointy (platby, autentifikácia, webhooky).
- [ ] **CI/CD pipeline** (Stredná) — GitHub Actions: automatizovaný build, testy a nasadenie backendu.
- [ ] **Dokumentácia API** (Stredná) — OpenAPI / Swagger: formálna špecifikácia 148 endpointov.

## 🧪 QA review — zostáva skontrolovať

Pre každú položku: **Jazyk** (gramatika, preklady SK/EN/ES) · **Kód** (best practices, error handling) · **Vizuál** (UI/UX, responzivita, dark mode).

**Obrazovky**
- [ ] **Auth Screen** — Jazyk / Kód / Vizál

**Moduly** (Jazyk / Kód / Vizuál)
- [ ] Rosary — Zoznam · Detail
- [ ] Prayer Intentions
- [ ] Spiritual Exercises — Zoznam · Detail · Registrácia
- [ ] Donation Screen
- [ ] News — Zoznam · Detail
- [ ] Notes
- [ ] Intro / Onboarding

**Komponenty** (Kód / Vizuál)
- [ ] Audio Player Card · Module Button · Loading/Error widgets · Navigation (FAB menu)

**Lokalizácia** (kompletnosť + gramatika)
- [ ] `sk.json` · `en.json` · `es.json` · porovnanie kľúčov (žiadne chýbajúce)

**Platformy** (iOS / Android)
- [ ] Permissions · Push notifications · Background audio · Deep links

**Build & Release**
- [ ] `flutter analyze` 0 errors · `flutter test` pass · version number · release build iOS · release build Android

**Záverečné testovanie** (iOS / Android)
- [ ] Fresh install · Upgrade z predošlej verzie · Offline mode · Všetky jazyky (SK/EN/ES) · Light/Dark mode

## 🌍 Migrácia predvoleného jazyka SK → EN (v10.1.1)

> **Cieľ:** Zmeniť fallback jazyk z `sk` na `en`, aby anglickí používatelia mali natívny zážitok. Slovenčina zostáva plne podporovaná, ale už nie je hardcoded default.

### Predpoklady & riziká
- [ ] **Overiť EN obsah v DB** — lectio_sources, liturgical_calendar, rosary, adorácie musia mať anglický obsah pre všetky dni (inak fallback na `en` zobrazí prázdno).
- [ ] **Testovať nového používateľa** — onboarding flow s EN defaultom.
- [ ] **Testovať existujúceho SK používateľa** — jazyk musí zostať `sk` (uložený v preferences).
- [ ] **SEO dopad** — zmena `<html lang>` a `og:locale` ovplyvní indexovanie.

### Mobile (Flutter) — onboarding language picker + versioning
- [ ] **main.dart** — `onboarding_completed` (bool) → **`onboarding_version`** (int): `0` = nový user → language picker → plný onboarding; `< CURRENT` = po update → language picker → onboarding_update; po dokončení uložiť `onboarding_version`. Konštanta `CURRENT_ONBOARDING_VERSION = 2`.
- [ ] **LanguagePickerScreen** — nový widget, prvá obrazovka vždy: 🇬🇧 English / 🇸🇰 Slovenčina / 🇪🇸 Español; upozornenie *„Português (pt-BR) e Français (fr) — coming June 2026"* (disabled); predvolený výber podľa systémového jazyka; uloží do `shared_preferences` + `EasyLocalization`.
- [ ] **OnboardingScreen** — existujúci plný onboarding (5 slidov), len pre nových.
- [ ] **OnboardingUpdateScreen** — nový widget, krátky „What's new" (1–2 slidy) pre existujúcich; možnosť zmeniť jazyk; parametrický obsah.

```
Nový user:     LanguagePicker → OnboardingScreen (5 slidov) → Appka
Update user:   LanguagePicker → OnboardingUpdateScreen (1-2 slidy) → Appka
Aktuálny user: Priamo do Appky (version == CURRENT)
```

### Mobile — lokalizácia & bootstrap (fallback → `en`)
- [ ] **main.dart** L41/L44, L112/L114, L184/L186 — `supportedLanguages`/`supportedLocales` poradie `['en','sk','es']`, `fallbackLocale: en`.
- [ ] **bootstrap.dart** L52/L54/L104/L106/L117/L120 — `supportedLocales` + `fallbackLocale` + `supportedLanguages` → `en`.
- [ ] **theme_provider.dart** L138/L141 — `supportedLanguages` + fallback → `en`.

### Mobile — dátové služby, notifikácie, modely
- [ ] **lectio_data_service.dart** (L47,52,233,238,264,270,334,342,352) — fallback `locale != 'sk'` → `'en'`, `.eq(..., 'sk')` → `'en'`.
- [ ] **lectio_cache_service.dart** (L231,236) — rovnaký fallback pattern.
- [ ] **home_screen.dart** (L236,241,324,332,342) — fallback queries → `'en'`.
- [ ] **lectio_screen.dart** (L1306,1311,1337,1343,1438,1444,1455) — fallback queries → `'en'`.
- [ ] **local_notifications_service.dart** L521 `texts['sk']` → `texts['en']`; L537 `return 'sk'` → `return 'en'`.
- [ ] **rosary_model.dart** L84, **adoration_model.dart** L73, **stations_of_cross_model.dart** L46 — `?? 'sk'` → `?? 'en'`.
- [ ] **lectio_audio_track.dart** L84/L99 — `sk`-specific label logiku → `en`-first.
- [ ] **notifications_screen.dart** L78 — overiť poradie `localeIdMap`.
- [ ] **spiritual_exercise_detail_screen.dart** L117 — `DateFormat('d. MMMM yyyy','sk')` → aktuálny locale.

### Backend (Next.js) — default lang
- [ ] **LanguageProvider.tsx** L14/L21 — default `'en'`, `useState('en')`.
- [ ] **layout.tsx** L27 `<html lang="en">`, L78 `og:locale` → `en_US`, L69 `geo.region` ponechať/odstrániť.
- [ ] **API default param** `|| 'sk'` → `|| 'en'`: lectio/route L32, lectio/today L35, lectio-sources L14, news L13, public/newsletters L21, feedback L46.
- [ ] **API fallback queries** `'sk'` → `'en'`: lectio/route (L59,64,71,118,123,182,187,205), lectio/today (L61,66,92,98,103,167,173,186).
- [ ] **lectio/page.tsx** (L258,264,281,325,331,354,361,371,375) — fallback queries → `'en'`.
- [ ] **cron/send-scheduled-notifications** L133/L325; **newsletter/campaigns/send** L194/L251/L269 — `|| 'sk'` → `|| 'en'`.
- [ ] **text-to-speech** L146/L150; **contact** L198/L238/L414; **email-sender.ts** L78 — default → `'en'`.
- [ ] **Utility/metadata**: dateFormatter L55/L101, metadata.ts L31/L41/L47, DatePickerModal L35, VoiceSelector L39, AudioGenerateButton L30, notes/layout L11/L17.
- [ ] **Admin UI** default lang: notifications/new (L69,341), content_cards (L73,191) + [id] (L66,322), lectio-sources (L448,562) + [id] (L771,943,969,995,1021,1047), rosary (L544) + [id] (8×) + SaveButtonsSection L124, liturgical-calendar (L192,685,703,954,1476,1490), profile (L653,662).
- [ ] **Ostatné**: checkout L30/L49 (detekcia krajiny), api/checkout/products L178, support/2-percenta L187, api/create-beta-table L19, rosary-utils L35/L226, adoracia-utils L25.

## 🗺️ Roadmap (ďalšie verzie)

### v10.2+ — jún 2026
- [ ] **FCM Token Cleanup Cron** — očista starých/neplatných tokenov (90+ dní neaktívne).
- [ ] **Ruženec — záložky a zdieľanie** (zakomentované).
- [ ] **Ruženec — background audio** (chýba mini player aj background playback).
- [ ] **Základné modlitby** — zoznam (Otčenáš, Zdravas'…).
- [ ] **Brazílska portugalčina (pt-BR) — obsah** — liturgický kalendár, lectio-sources, krížové cesty, adorácie, modlitby.
- [ ] **Jednoduché návody** — krátke videá / pop-up „Vedeli ste, že…" (onboarding tipy, feature discovery).

### v10.3+ — júl 2026
- [ ] **Streak & Stats** — sledovanie pokroku, kalendár aktivity.
- [ ] **Liturgický kalendár** — svätec dňa na home screene.
- [ ] **Inbox** — systém správ od administrátorov.
- [ ] **Semantics labels pre screen reader** — obrázky (`semanticLabel`), tlačidlá (`Semantics`).
- [ ] **Brazílska portugalčina (pt-BR) — web + marketing** — preklad webu parochia + kampaň na Brazíliu.
- [ ] **Francúzština (fr-FR) — obsah** — liturgický kalendár, lectio-sources, krížové cesty, adorácie, modlitby.

### v10.4+ — august 2026
- [ ] **Banner na home screen** — dynamický widget s backend admin.
- [ ] **Internacionalizácia** — infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov.
- [ ] **Refactoring** — profile_screen (~2551), home_screen (~2054), lectio_screen rozdelenie.
- [ ] **Brazílska portugalčina (pt-BR) — preklad aplikácie** — lokalizácia všetkých stringov.
- [ ] **Francúzština (fr-FR) — web + aplikácia + marketing**.

### v10.5+ 🎓 — september 2026
- [ ] **Teologické prehĺbenie (Magisterium AI)** — voliteľná sekcia pod Actio s AI-generovaným komentárom k dennému evanjeliu. Magisterium API (28 000+ dokumentov) + ChatGPT/Claude → 4 bloky: Teologické jadro, Cirkevní Otcovia, KKC, Dokumenty Cirkvi. 1× denne per jazyk, cache v DB, editovateľné adminom. *Nie chatbot* — len akademické prehĺbenie s povinnými zdrojmi. Detaily: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`. Validácia teológom (Draft → schválenie → publikácia), budget na API costs, pilot 100–200 users.

## 📦 Balíčky — blokované / beta
- [ ] `app_links` 6.4.1 → 7.0.0 ⚠️ (blokované `supabase_flutter`)
- [ ] `flutter_html` ^3.0.0-beta.2 ⚠️ beta
- [ ] `just_audio_background` 0.0.1-beta.17 ⚠️ beta

---

# ✅ HOTOVO (skrátený prehľad)

**Stav:** Pripravené na produkciu · `flutter analyze` = 0 problémov · žiadne hardcoded secrets.

**Kritické (pred vydaním)** — Bezpečnosť (keystore, secure_storage, env), iOS App Store (Info.plist privacy, background modes, Apple entitlement, encryption flag), Android (ProGuard/R8, release signing), Audio (background playback, lock screen controls, seek, auto-progression, offline, global mini player). ✅

**Auth** — Email/heslo, Google Sign-In, **Apple Sign-In (nonce) — funguje ✅**, Guest mode, Remember Me, zjednotený dizajn, lokalizované error hlášky. ✅

**Notifikácie** — FCM service, deep-link na 10+ obrazoviek, settings (topics, denné lectio, prayer reminder), local notifications (timezone, exact alarms), Android/iOS permissions, battery exemption. ✅

**Engagement (v10.1.1)** — App rating prompt (po 5 otvoreniach, cooldown 90 dní), support/donation prompt (každých 10 otvorení, cooldown 30 dní), technical notifications kategória, deep-link URL support. ✅

**Obsah & UI** — Lectio Divina, Ruženec, Adorácie, Krížová cesta (PageView, hero obrázky, audio playlist, lock screen artwork), Duchovný denník, Spoločenstvo (Prayer Wall), Duchovné cvičenia, Novinky, Úmysly, Dary (QR + prevod), Profil, Nastavenia, Feedback, Newslettery (zoznam + detail + push). ✅

**Onboarding** — 5 slidov (uvítanie, denné čítania, čo je Lectio Divina, pripomienky, prihlásenie), skip, dots, `onboarding_completed` flag. ✅

**Infraštruktúra** — Umami Analytics, Firebase Crashlytics, CI/CD (GitHub Actions), app ikony + splash, edge-to-edge (values-v35). ✅

**Services (kód)** — app_logger, fcm_service, local_notifications_service, notification_api, lectio_audio_service, prayer_focus_service, credentials_service, do_not_disturb_service, notification_settings_screen — všetky na `appLogger`. ✅

**Opravené chyby**
- v10.0.0.5000007: Onboarding Google redirect (auth state monitoring), Password visibility toggle. ✅
- v10.0.1+5000008: FAB menu preklady (`tr()`), Likes/komentáre RLS (PostgrestException 42501), Language switch flash. ✅

**Balíčky aktualizované** — carousel_slider 5.1.1, device_info_plus 12.3.0, google_sign_in 7.2.0, get_it 9.2.0, flutter_secure_storage 10.0.0, firebase_core 4.3.0, firebase_messaging 16.1.0, supabase_flutter 2.12.0, http 1.6.0, shared_preferences 2.5.4. ✅

---

## ⚠️ Dočasne deaktivované funkcie
- **DND (Nerušiť)** — iOS nepovoľuje priamy prístup k Focus API, Android vyžaduje špeciálne povolenia. Obnoviť v `settings_screen.dart`, `lectio_screen.dart`, `lectio_audio_service.dart`.
- **Background Play nastavenia** — nedokončené (TODO) v `settings_screen.dart`.

---

## 🔗 Súvisiace dokumenty
- Finančné hodnotenie: `docs/FINANCIAL_EVALUATION.md`
- Testovanie notifikácií: `docs/TESTING_CHECKLIST.md`
- Launch checklist (admin nástroj): `docs/docs/LAUNCH_CHECKLIST.md`
- Teologické prehĺbenie: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`

# 📋 Production Checklist & Roadmap — Lectio Divina

> Zostávajúce úlohy pre mobil (Flutter) + backend (Next.js). **Hotový stav appky** → [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md).
> Verzia mobilu: **v11.0.0+5000015** · Release: **14. júl 2026** 🎂 · Aktualizované: **29. jún 2026**

**Legenda:** `[ ]` = treba urobiť · `[x]` = hotové · ⚠️ = blokované / na overenie

---

# 🚦 Pred release-build (14. júl 2026)

> Robí sa **tesne pred buildom**, nie priebežne.

**Dev flagy → `false`** (všetky ✅ hotové)
- [x] `_kTestCheckout` (`shop/checkout_screen.dart`) — `false`
- [x] `kForceOnboardingUpdate` (`main.dart`) — `false`
- [x] `_kCoachAlwaysShow` (`home_screen.dart`) — `false`
- [x] Vercel `ALLOW_TEST_CHECKOUT` — odstránené

**SQL migrácie spustené v produkcii (Supabase)**
- [x] `add_campaign_rewards.sql` (odmeny za dar)
- [x] `add_help_articles_platform.sql` (per-OS Pomocník) — už importované
- [x] `add_refund_to_orders.sql` (refundácie/dobropisy)
- [x] `add_decrement_product_stock.sql` (atomický sklad)
- [x] `add_invoice_token_to_orders.sql` (ochrana faktúr/dobropisov tokenom)
- [x] `add_full_lectio_audio.sql` (kombinované lectio audio)
- [x] `add_payment_to_se_registrations.sql` + `fix_se_email_template_fee.sql` (DC platby)
- [x] supporter-discount migrácia (ak ešte nebežala)

**Build & store**
- [x] `flutter analyze` = 0 errors (celý projekt) — overené 2.7.2026 (len 3 info deprecations)
- [ ] Verzia / build number navýšený
- [ ] Release build iOS (App Store) + Android (Play)
- [ ] App ikony + splash OK

**Konfigurácia / prepínače**
- [x] **Podporovateľská zľava** — master `enabled` flag je default OFF; **zapnúť po teste**.
- [x] **Apple OAuth secret** v Supabase — vložený nový JWT (platí do **26. 12. 2026**; rotovať skriptom `generate-apple-secret.cjs`).
- [x] Vercel env (ak relevantné): `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` + `RECAPTCHA_SECRET_KEY` (reCAPTCHA sa zapne až keď sú nastavené).
- [ ] V admine doplniť fakturačné údaje OZ (adresa, DIČ, IČ DPH, IBAN).

---

# 🗺️ Roadmap (ďalšie verzie)

### v11.1+ — august 2026
- [ ] **Audio disk cache (`LockCachingAudioSource`)** — seek po fixe 5.7.2026 trvá ~1–1,5 s (sieťový range request); s priebežnou diskovou cache by bol seek v prehratej časti aj opakované prehratie okamžité. Pozor na súbeh s offline sťahovaním (`audio_download_service`) a správu miesta. _Rozhodnúť po v11.0._
- [ ] **Android BackgroundAudioManager fallback** (nízka) — staršie Android (8/9) nezatvárajú media player po zatvorení appky na zamknutej obrazovke.
- [ ] **Inbox** — systém správ od administrátorov.
- [ ] **Semantics labels pre screen reader** — obrázky (`semanticLabel`), tlačidlá (`Semantics`).
- [ ] **Brazílska portugalčina (pt-BR)** — web + marketing · obsah (kalendár, lectio-sources, krížové cesty, adorácie, modlitby) · preklad aplikácie (lokalizácia stringov).
- [ ] **FCM Token Cleanup Cron** — očista starých/neplatných tokenov (90+ dní neaktívne).

### v11.2+ — september 2026
- [ ] **Internacionalizácia** — infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov.
- [ ] **E-shop — medzinárodné poštovné** _(až keď sa e-shop spustí mimo SK)_ — teraz je poštovné **per-produkt, country-agnostické**. Pri expanzii: (a) per-produkt `shipping_cost_intl`, alebo (b) násobiteľ podľa skupiny krajín. Stačí pridať kód krajiny do `ALLOWED_COUNTRIES` + country zoznamov + doriešiť poštovné.
- [ ] **Refactoring** — `profile_screen` (~2551), `home_screen` (~2054), `lectio_screen` rozdelenie.
- [ ] **Upratať print/debugPrint** — 22× v `lib/` (audit 2.7.2026). Kozmetika: release ich prakticky nevidí (`appLogger` filtruje na warning+), ale zjednotiť na `appLogger`.
- [ ] **Nová testovacia sada pre v2** — staré testy (pred-v2 HomeScreen, starý audio stack, widget_test s reálnym .env/Supabase) boli 2.7.2026 vymazané ako zastarané; ostal len `test/utils/ui_helpers_test.dart`. Napísať unit/widget testy pre v2 obrazovky a services (mocknúť Supabase, bez siete).
- [ ] **Lokalizovať DC obrazovky** — `spiritual_exercise_detail/registration/list_screen` majú `tr()` = 0 (hardcoded SK) → externalizovať do `*.json`.
- [ ] **Ruženec** — záložky a zdieľanie (zakomentované) · background audio (chýba mini player aj background playback).
- [ ] **Liturgický kalendár** — svätec dňa na home screene.
- [ ] **Streak & Stats** — sledovanie pokroku, kalendár aktivity.

### v11.3+ 🎓 — november 2026
- [ ] **Teologické prehĺbenie (Magisterium AI)** — voliteľná sekcia pod Actio s AI-generovaným komentárom k dennému evanjeliu. Magisterium API (28 000+ dokumentov) + ChatGPT/Claude → 4 bloky: Teologické jadro, Cirkevní Otcovia, KKC, Dokumenty Cirkvi. 1× denne/jazyk, cache v DB, editovateľné adminom. *Nie chatbot.* Detaily: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`. Validácia teológom, budget na API, pilot 100–200 users.
- [ ] **Roly & oprávnenia — rola `editor`** — teraz je 10 `admin` (veľa). Pridať `editor` (CHECK na `users.role`), rozlíšiť obsahové vs. citlivé endpointy, `requireEditor` popri `requireAdmin`, gating admin UI per rola. Migrácia: preklasifikovať väčšinu adminov → `editor`, nechať 1–2 `admin`. _(Nie akútne.)_

---

# 🖥️ Backend (Next.js) — produkčné odporúčania
> Zvyšujú zrelosť produkčnej prevádzky (nie blokery releasu).
- [ ] **Monitoring & error tracking** (Vysoká) — Sentry: zachytávanie chýb v produkcii.
- [ ] **Štruktúrované logovanie** (Vysoká) — Pino / Winston namiesto `console.log`.
- [ ] **Automatizované testy backendu** (Vysoká) — Vitest / Jest: platby, auth, webhooky.
- [ ] **CI/CD pipeline** (Stredná) — GitHub Actions: build, testy, nasadenie.
- [ ] **Dokumentácia API** (Stredná) — OpenAPI / Swagger.

---

# 🧪 QA review — zostáva skontrolovať
> Pre každú: **Jazyk** (gramatika, preklady) · **Kód** (best practices, error handling) · **Vizuál** (UI/UX, responzivita, dark mode).

- [ ] **Obrazovky:** Auth.
- [ ] **Moduly:** Rosary (zoznam/detail) · Prayer Intentions · Spiritual Exercises (zoznam/detail/registrácia) · Donation · News (zoznam/detail) · Notes · Intro/Onboarding.
- [ ] **Komponenty:** Audio Player Card · Module Button · Loading/Error widgets · Navigation (FAB menu).
- [ ] **Platformy (iOS/Android):** Permissions · Push · Background audio · Deep links.

---

# 🌍 SK → EN — zostávajúce backend defaulty
> Mobil + hlavné endpointy hotové. Ostávajú menej kritické backend defaulty (`|| 'sk'` → `|| 'en'`, fallback queries).
- [ ] `cron/send-scheduled-notifications` (L133/L325); `newsletter/campaigns/send` (L194/L251/L269).
- [ ] `text-to-speech` (L146/L150); `contact` (L198/L238/L414); `email-sender.ts` (L78).
- [ ] Utility/metadata: dateFormatter, metadata.ts, DatePickerModal, VoiceSelector, AudioGenerateButton, notes/layout.
- [ ] Admin UI default lang: notifications/new, content_cards, lectio-sources, rosary, liturgical-calendar, profile.
- [ ] Ostatné: checkout (detekcia krajiny), api/checkout/products, support/2-percenta, rosary-utils, adoracia-utils.
- [ ] `notification_models.dart` — pridať DB stĺpec `name_fr` + `case 'fr'` (inak FR → EN).

---

# 📦 Balíčky — blokované / beta
- [ ] `app_links` 6.4.1 → 7.0.0 ⚠️ (blokované `supabase_flutter`)
- [ ] `flutter_html` ^3.0.0-beta.2 ⚠️ beta
- [ ] `just_audio_background` 0.0.1-beta.17 ⚠️ beta
- [ ] **3 deprecations** (audit 2.7.2026, len info) — `ConcatenatingAudioSource` (adoration_detail, stations_of_cross_detail) a `onReorder` (lectio_survey — beztak vypnutý). Fungujú; riešiť pri upgrade `just_audio` / Fluttera.

**Pozn. — TODO v kóde (audit 2.7.2026):** 4 komentáre, všetky platné a podchytené — 3× ruženec záložky/zdieľanie (→ roadmap v11.2), 1× Spotify feed URL pre EN/ES/FR/PT-BR (čaká na schválenie Spotify; → mapa prekladov bod 4).

---

# 🌐 Prekladové súbory (mapa pre budúce jazyky)
> Všetky miesta v `mobile/lib`, kde žijú preklady. Pri pridávaní jazyka (pt-BR, DE…) prejsť celý zoznam.

**1) JSON — UI stringy (easy_localization), hlavný zdroj**
- `assets/translations/{sk,en,es,fr}.json` — **~1294 kľúčov**, identický set vo všetkých 4.

**2) Hardcoded prekladové mapy v Dart (`switch` `_sk/_en/_es/_fr`)**
- `lib/screens/intro_translations.dart` · `lib/screens/intro_step_translations.dart` · `lib/services/local_notifications_service.dart` (`_getNotificationText`).

**3) Preklady v DB (kód len mapuje jazyk)**
- `lib/models/notification_models.dart` — `getNameByLanguage` (`name_sk/en/cs/es/de`); pridať `name_fr`.

**4) Konfigurácia podľa jazyka (URL / ID / zoznamy)**
- `lib/services/podcast_service.dart` — `_channelCover` (FR ✅) + `_spotifyShowUrl` (len `sk`; FR URL keď bude FR podcast).
- `lib/screens/notifications_screen.dart` — `localeIdMap` `{sk:1,en:2,es:4,fr:7}`.
- `lib/screens/settings_screen.dart` — `_getAvailableBiblesForLocale` (FR biblia keď bude preklad).

**5) Nelokalizované obrazovky (hardcoded SK, `tr()` = 0) — väčšia úloha**
- `spiritual_exercise_detail_screen.dart` · `spiritual_exercise_registration_screen.dart` · `spiritual_exercises_list_screen.dart`.

---

# ⚠️ Dočasne deaktivované funkcie
- **DND (Nerušiť)** — iOS nepovoľuje priamy prístup k Focus API, Android vyžaduje špeciálne povolenia. Obnoviť v `settings_screen.dart`, `lectio_screen.dart`, `lectio_audio_service.dart`.
- **Background Play nastavenia** — nedokončené (TODO) v `settings_screen.dart`.
- **Lectio dotazník** — viď sekciu nižšie.

---

# 🔗 Súvisiace dokumenty
- Audit appky: [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md)
- Testovací protokol: [`TESTING_CHECKLIST.md`](TESTING_CHECKLIST.md)
- iOS widgety: [`IOS_WIDGETS_PLAN.md`](IOS_WIDGETS_PLAN.md)
- Finančné hodnotenie: `docs/FINANCIAL_EVALUATION.md`
- Teologické prehĺbenie: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`

---

# ⚠️ Dotazník (Lectio survey) — DOČASNE VYPNUTÝ

Po spustení podpory kurzu Lectio sme dotazník deaktivovali. **Nič sa nezmazalo** — stránka `lib/screens/lectio_survey_screen.dart` aj celý wiring ostávajú pre budúci dotazník.

- Vypnuté cez flag `_surveyFeatureEnabled = false` v `lib/screens/home_screen.dart` → `_surveyPending` je vždy `false`, spúšťací odznak na home sa nezobrazí.
- Dôsledok: keďže dotazník mal prioritu pred donation srdcom, po 6. spustení sa teraz skôr ukáže donation srdce (každé 10. otvorenie, nepodporovateľom).
- **Reaktivácia:** prepni `_surveyFeatureEnabled` na `true`. Pre nový dotazník prepíš obsah `LectioSurveyScreen` a prípadne resetni prefs `survey_completed` / `survey_launch_count`.

---

# 🛠 iOS build: patch `xcodeproj` pre Xcode 16 (objectVersion 70)

**Čo to robí:** Po update na Xcode 16 začne `pod install` padať s chybou `[Xcodeproj] Unknown object version (70)`, lebo Xcode 16 zapisuje `*.pbxproj` s `objectVersion = 70`, ktorú bundlovaná verzia gemu `xcodeproj` (1.27.0 vo vnútri CocoaPods 1.16.2) ešte nepozná. Patch pridá do mapy `COMPATIBILITY_VERSION_BY_OBJECT_VERSION` (v `constants.rb` toho gemu) riadok `70 => 'Xcode 16.0'` hneď za existujúci `77 => 'Xcode 16.0'`. Tým sa CocoaPods naučí čítať/zapisovať projekt s objectVersion 70 a iOS build / `pod install` prejde. Druhý príkaz (`grep`) len overí, že sa riadok pridal.

> ⚠️ Patch sa **stráca pri každom upgrade/reinštalácii CocoaPods** (mení súbor v `Cellar`) — po `brew upgrade cocoapods` ho treba spustiť znova. Cesta obsahuje konkrétne verzie (`cocoapods/1.16.2_2`, `xcodeproj-1.27.0`) — pri inej nainštalovanej verzii uprav cestu podľa skutočnosti.

```bash
# Pridá mapovanie objectVersion 70 → Xcode 16.0 do gemu xcodeproj (používa ho CocoaPods)
perl -0pi -e "s/(77 => 'Xcode 16\.0',\n)/\$1      70 => 'Xcode 16.0',\n/" "/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems/xcodeproj-1.27.0/lib/xcodeproj/constants.rb"

# Overenie, že sa riadok pridal
grep "70 =>" "/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems/xcodeproj-1.27.0/lib/xcodeproj/constants.rb"
```

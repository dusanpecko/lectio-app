# 📋 Production Checklist & Roadmap — Lectio Divina

> Zostávajúce úlohy pre mobil (Flutter) + backend (Next.js). **Hotový stav appky** → [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md).
> V obchodoch: **v11.0.1+6000003** (manuálne publikovanie **14. júl 2026** 🎂) · Vo vývoji: **v11.1.0+6000004** · Aktualizované: **12. júl 2026**

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
- [x] Verzia / build number navýšený — `11.0.0+6000001` (éra 6 = Flutter v11; 5.7.2026)
- [x] Release build — Android AAB zbuildený (5.7.2026); iOS archív cez Xcode Cloud (auto pri pushi na main)
- [x] App ikony + splash OK

**Konfigurácia / prepínače**
- [x] **Podporovateľská zľava** — master `enabled` flag je default OFF; **zapnúť po teste**.
- [x] **Apple OAuth secret** v Supabase — vložený nový JWT (platí do **26. 12. 2026**; rotovať skriptom `generate-apple-secret.cjs`).
- [x] Vercel env (ak relevantné): `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` + `RECAPTCHA_SECRET_KEY` (reCAPTCHA sa zapne až keď sú nastavené).
- [ ] V admine doplniť fakturačné údaje OZ (adresa, DIČ, IČ DPH, IBAN).

---

# 🗺️ Roadmap (ďalšie verzie)

### v11.1+ — august 2026
- [x] **Deviatniky (Novény)** ✅ 11.7.2026 — kompletná funkcia, otestovaná E2E: DB (`novenas` + `novena_days` + kategórie, RLS), admin `/admin/novenas` (jazykové záložky, rich text, dni, TTS per úvod/deň/záver, ilustračný obrázok — zdieľaný jazykmi), mobil (menu Deviatniky, zoznam s progresom a náhľadmi, kalendárny progres od štartu — lokálny, denné pripomienky, slidy úvod/deň/záver, copy, jazykové čipy, obrázkový hero). + **jednotný zbaliteľný hero** (`CollapsibleHeroAppBar` — vzor krížové cesty) nasadený na KC + adorácie + ruženec + deviatniky. _Obsah deviatnikov = editorská práca v admine (texty + TTS + obrázky)._
- [x] **Spytovanie svedomia (spovedné zrkadlo)** — pridať do sekcie modlitieb (multijazyčne, aj s audiom).
- [x] **E-shop — platba na dobierku** ⚠️ _čaká na E2E test_ — dnes máme len Mollie (karta); doplnená dobierka ako platobná metóda (checkout voľba, príplatok za dobierku, objednávka bez online platby → stav `pending_cod`, fulfillment manuálne, faktúra pri odoslaní cez „Odoslať dobierku" v admine). Pred testom: spustiť `backend/sql/add_cod_and_company_to_orders.sql` v Supabase + v admin Účtovníctve zapnúť `cod_enabled` (master flag, default OFF).
- [x] **E-shop — objednávka pre firmy** ⚠️ _čaká na E2E test_ — fakturačné údaje firmy v checkoute (IČO, DIČ, IČ DPH, názov firmy) + prenesenie na faktúru/dobropis.
- [x] **Home — featured slidy pre duchovný obsah** ✅ 11.7.2026 — do featured carouselu (kde sú Potulky a Kurz) pridaných 6 slidov s overline „POBOŽNOSTI": Krížové cesty, Základné modlitby, Deviatniky, Spytovanie svedomia, Ruženec, Adorácie — vstupné body na duchovný obsah priamo z home. Náhodný štartovací slide rotuje cez všetky strany.
- [x] **Úmysly — notifikačný schvaľovací flow** ✅ 7.7.2026 — používateľ pošle úmysel → admin dostane push (`notify-admin`, INSERT webhook) → po schválení (`approved=true`) dostane odosielateľ lokalizovaný push „Váš úmysel bol schválený a zaradený medzi modlitby" (`notify-approved`, UPDATE webhook, podľa `intentions.lang`). Informačná notifikácia — otvára hlavnú stránku, bez deep-linku. _Pozn.: Supabase webhook URL musí byť `www.lectio.one` (apex 301-redirect pg_net nenasleduje)._
- [x] **Audio disk cache (`LockCachingAudioSource`)** ✅ 7.7.2026 — stream sa cachuje na disk (Caches/, OS-evictable) na 6 streamovacích miestach (lectio player track+interlude, MediaPlayerBus, modlitby, universal, adorácie, krížové cesty); offline súbory ostávajú `AudioSource.file`. + home seek bar (`daily_podcast_card._ProgressBar`) prerobený: drag-state + seek raz na `onChangeEnd` + spinner počas bufferovania (namiesto seeku pri každom pixeli). Seek do vypočutej časti a opakované prehratie sú okamžité. Overené iOS + Pixel. _Správu miesta cache zatiaľ rieši OS; limit/čistenie doplniť ak bude treba._
- [ ] ⏸️ **Android — media notifikácia po zatvorení appky (8/9)** _(on-hold, opraviť len ak sa ozvú používatelia)_ — overené 7.7.2026: pôvodná položka sa týkala starého audio stacku; `BackgroundAudioManager` je dnes len kompat. obálka nad `LectioAudioPlayer` (mixin + controller + `mini_audio_player` = mŕtvy kód, kandidát na zmazanie pri v11.2 refactoringu). Správanie dnes riadi `just_audio_background` — kandidátsky fix je jednoriadkový: `androidStopForegroundOnPause: true` v `main.dart` (štandard ako Spotify: pauza → notifikácia zmietnuteľná, zatvorenie appky → player zmizne). Nemenené bez spätnej väzby — mení správanie na všetkých Androidoch.
- [x] **Semantics labels pre screen reader** ✅ 7.7.2026 (zameraný prechod hlavnej cesty) — 15 `a11y_*` kľúčov (sk/en/es/fr). Audio ovládanie (play/pauza/stop/skip/seek — `lectio_audio_controls`, `lectio_floating_audio_player`, `audio_player_controls`, `lectio_step_card` Semantics per krok), lectio navigácia (chevrony sekcií, šípky dňa Semantics), home hero obrázok `excludeFromSemantics` (dekoratívny). _Úplný sweep zvyšných ~80 obrázkov/tlačidiel = neskôr, ak bude záujem (viď v11.2 poznámka)._
- [x] **FCM Token Cleanup Cron** ✅ 7.7.2026 — `/api/cron/fcm-token-cleanup` (Bearer CRON_SECRET, fail-closed) maže tokeny s `last_used_at` starším ako 90 dní; týždenne (ne 4:00, `vercel.json`). Neplatné tokeny sa deaktivujú už pri odosielaní (`sendPushNotificationWithCleanup`) — cron rieši vekovú očistu. _Aktivuje sa po deployi backendu._


### v11.2+ — september 2026
- [ ] **Push tokeny pre neprihlásených** ⚠️ (zistené 12.7.2026 z logcatu) — anonymné zariadenia si od zapnutia RLS (24.11.2025) nedokážu zaregistrovať FCM token (`user_fcm_tokens` RLS: len `user_id = auth.uid()`; mobil zapisuje priamo cez Supabase) → neprihlásení nedostávajú denné push notifikácie. Fix: verejný endpoint s rate-limitom (service-role upsert) + fallback v `fcm_service.dart` keď nie je session.
- [ ] **O aplikácii — Sponzori** — pridať sekciu sponzorov/podporovateľov do obrazovky O aplikácii (`about_screen`).
- [ ] **Edge-to-edge QA sweep (Android 15 / SDK 35)** — appka už edge-to-edge zapína (`SystemUiMode.edgeToEdge` v main.dart) + rieši insety (SafeArea + viewPadding); Google Play upozornenie je plošné pre všetky SDK 35 appky, nie reálny bug (overené na Pixel 9a / Android 15+). Úloha = len vizuálne preklikať každú obrazovku na Androide 15, či niekde obsah/tlačidlo nie je za status/nav lištou. _Bez zmeny kódu, ak sa nič nenájde._
- [ ] **Internacionalizácia** — infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov.
- [ ] **Refactoring** — `profile_screen` (~2551), `home_screen` (~2054), `lectio_screen` rozdelenie. + zmazať mŕtvy audio kód (overené 7.7.2026): `lectio_audio_mixin` (0 použití), `lectio_audio_controller` + `mini_audio_player` (nikde nerenderovaný; v2 používa `GlobalMiniPlayer`), `floating_audio_player` + `audio_player_service` (legacy, nahradené `LectioFloatingAudioPlayer`/`MediaPlayerBus`), `background_audio_manager` zúžiť/zmazať (len kompat. obálka).
- [ ] **Upratať print/debugPrint** — 22× v `lib/` (audit 2.7.2026). Kozmetika: release ich prakticky nevidí (`appLogger` filtruje na warning+), ale zjednotiť na `appLogger`.
- [ ] **Nová testovacia sada pre v2** — staré testy (pred-v2 HomeScreen, starý audio stack, widget_test s reálnym .env/Supabase) boli 2.7.2026 vymazané ako zastarané; ostal len `test/utils/ui_helpers_test.dart`. Napísať unit/widget testy pre v2 obrazovky a services (mocknúť Supabase, bez siete).
- [ ] **Lokalizovať DC obrazovky** — `spiritual_exercise_detail/registration/list_screen` majú `tr()` = 0 (hardcoded SK) → externalizovať do `*.json`.
- [ ] **Ruženec** — záložky a zdieľanie (zakomentované) · background audio (chýba mini player aj background playback).
- [ ] **Liturgický kalendár** — svätec dňa na home screene.
- [ ] **Streak & Stats** — sledovanie pokroku, kalendár aktivity.
- [ ] **Brazílska portugalčina (pt-BR)** — web + marketing · obsah (kalendár, lectio-sources, krížové cesty, adorácie, modlitby) · preklad aplikácie (lokalizácia stringov).
- [ ] **Roly & oprávnenia — rola `editor`** — teraz je 10 `admin` (veľa). Pridať `editor` (CHECK na `users.role`), rozlíšiť obsahové vs. citlivé endpointy, `requireEditor` popri `requireAdmin`, gating admin UI per rola. Migrácia: preklasifikovať väčšinu adminov → `editor`, nechať 1–2 `admin`. _(Nie akútne.)_

### v11.3+ — október 2026
- [ ] **E-shop — medzinárodné poštovné** _(až keď sa e-shop spustí mimo SK)_ — teraz je poštovné **per-produkt, country-agnostické**. Pri expanzii: (a) per-produkt `shipping_cost_intl`, alebo (b) násobiteľ podľa skupiny krajín. Stačí pridať kód krajiny do `ALLOWED_COUNTRIES` + country zoznamov + doriešiť poštovné.

### v12.0+ 🎓 — Júl 2027
- [ ] **Inbox** — systém správ od administrátorov.
- [ ] **Teologické prehĺbenie (Magisterium AI)** — voliteľná sekcia pod Actio s AI-generovaným komentárom k dennému evanjeliu. Magisterium API (28 000+ dokumentov) + ChatGPT/Claude → 4 bloky: Teologické jadro, Cirkevní Otcovia, KKC, Dokumenty Cirkvi. 1× denne/jazyk, cache v DB, editovateľné adminom. *Nie chatbot.* Detaily: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`. Validácia teológom, budget na API, pilot 100–200 users.


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

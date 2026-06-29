# 📱 Audit projektu — Lectio Divina (Flutter aplikácia)

> **Obraz mobilnej aplikácie `lectio.one`** — čo appka je, ako je postavená, čo všetko obsahuje.
> Verzia: **v11.0.0+5000015** · Platformy: **iOS + Android** · Release: **14. júl 2026**
> Posledná aktualizácia auditu: **29. jún 2026**

Doplnkové dokumenty: roadmap a úlohy → [`PRODUCTION_CHECKLIST.md`](PRODUCTION_CHECKLIST.md) · testovací protokol → [`TESTING_CHECKLIST.md`](TESTING_CHECKLIST.md) · iOS widgety → [`IOS_WIDGETS_PLAN.md`](IOS_WIDGETS_PLAN.md).

---

## 1. Čo to je

Katolícka duchovná aplikácia pre **každodenné Lectio Divina** (modlitebné čítanie Božieho slova) a sprievodné pobožnosti. Multilingválna, súčasť pastoračného projektu Žilinskej diecézy (OZ Lectio.one). Appka je klientom k spoločnej platforme `lectio.one` (web + backend + obsahová pipeline).

- **Jazyky (UI):** SK, EN, ES, FR aktívne; pt-BR + DE „čoskoro".
- **Obsah (DB):** SK/EN/ES kompletné, **FR čiastočné** (UI hotové, časť obsahu padá na fallback).
- **Default jazyk:** EN (reťazený fallback obsahu *jazyk → EN → SK*).

---

## 2. Architektúra & tech stack

**Framework:** Flutter (Dart SDK `^3.8.0`).

**Architektonické piliere:**
- **DI / service locator:** `get_it` — services ako singletony (vzor `Service.instance`).
- **State management:** `provider` (`ThemeProvider` — téma, jazyk, font) + `ChangeNotifier` services (napr. `CartService`).
- **Lokalizácia:** `easy_localization` (`'key'.tr()`), zdroj `assets/translations/{sk,en,es,fr}.json` (**~1294 kľúčov**, identický set vo všetkých 4).
- **Backend:** **Supabase** (Postgres + PostgREST + RLS + Storage) priamo z appky (anon) + **Next.js API** (`www.lectio.one`) pre platby, webhooky, admin a citlivé operácie.
- **Platby:** **Mollie** (e-shop objednávky, dary, poplatok za duchovné cvičenia) — ceny a poštovné sa prepočítavajú **na serveri** (ochrana proti podvodom).
- **Bootstrap:** `bootstrap.dart` + `main.dart` — inicializácia DI, Supabase, lokalizácie, audio, notifikácií, Firebase; `env_error_app` pri chýbajúcom `.env`.

**Kľúčové subsystémy:**
- **Audio:** `just_audio` + `just_audio_background` + `audio_service` + `audio_session`; vlastný `MediaPlayerBus` / `BackgroundAudioManager` / `LectioAudioController`. Prehrávanie na pozadí, ovládanie na zamknutej obrazovke, artwork, auto-progresia krokov, globálny mini-player.
- **Notifikácie:** `firebase_messaging` (FCM) + `flutter_local_notifications` + `timezone`; deep-linky (`app_links`) na 10+ obrazoviek; témy, denné lectio, pripomienka modlitby, technické notifikácie.
- **Offline:** `connectivity_plus` + `shared_preferences` + `flutter_cache_manager`; `lectio_cache_service` (7 dní lectio), `audio_download_service` (stiahnuté audio + cover), `offline_banner`.
- **Home-screen widgety:** `home_widget` — Actio widget (iOS App Group).
- **Auth:** Supabase auth — email/heslo, **Google Sign-In**, **Apple Sign-In** (nonce; OAuth secret v Supabase rotovať každých 6 mes.), **guest** režim, Remember Me.

**Rozsah kódu:** **164 Dart súborov, ~62 000 riadkov** — 49 obrazoviek · 38 services · 18 modelov · 35 widgetov · 2 controllery · 1 provider · shared/utils/helpers/mixins.

---

## 3. Funkčné moduly (čo appka vie)

**Jadro — Lectio Divina**
- Denné Lectio s krokmi (Silencio, Lectio, Meditatio, Oratio, Contemplatio, Actio…), per-krok audio s progres prstencom.
- Výber prekladu Biblie (SSV / Jeruzalemská / Ekumenický), kopírovanie textu krokov.
- **Fullscreen čítačka** (swipe medzi krokmi), **offline stiahnutie (7 dní)**.
- Kombinované audio: celé Lectio v jednej nahrávke (*dlhé* s hudbou / *krátke* bez), voľba v nastaveniach.
- **Admin in-app**: úprava textu krokov + pregenerovanie audia, bez dátumových obmedzení.

**Domov (Home v2 — redizajn)**
- Hero (obrázok, avatar, zvonček), audio karta, výber dňa + kalendár, Actio karta, **featured carousel** (Duchovné cvičenie / Potulky / Kurz), horizontálne Aktuality, glass bottom-nav, pull-to-refresh.

**Pobožnosti & modlitby**
- **Ruženec** (kategórie → desiatky + audio), **Adorácia**, **Krížová cesta** (PageView, hero artwork, audio playlist), **Základné modlitby** (multijazyčné + audio), **Úmysly** (zoznam + zadanie; admin notifikácia + týždenný súhrn).

**Duchovné cvičenia (SK-only)**
- Zoznam → detail → registrácia; poplatok za DC platba **kartou (Mollie)** alebo **prevodom (VS)**; appka aj web.

**Obsah & komunita**
- **Aktuality** (detail, HTML, audio „Prečítať článok", komentáre, like, form embed), **Newslettery** (zoznam + detail + push), **Poznámky** (CRUD), **Dokumenty** (gated audioknihy — `pastoral_council`/`admin`).

**E-shop (SK-only)**
- Produkty, filter kategórií, vyhľadávanie, detail (slider fotiek, DPH, poštovné, „Skladom: X ks"), košík (perzistentný cez reštart), „Kúpiť hneď", checkout s predvyplnením adresy, **Mollie** platba, **Moje objednávky** (faktúra PDF s tokenom + tracking), **podporovateľská zľava** podľa tieru. Účtovníctvo: rad faktúr `OF`, CSV export (OMEGA), refundácie + dobropisy (`DF`).

**Podpora / dary**
- Donation tiery (jednorazovo/mesačne), „Náš príbeh" + míľniky + progress bar (backend kampaň), QR + prevod, **odmeny za dar** (Potulky/Kurz — poďakovacie darčeky cez Mollie donation, manuálny fulfillment), prezentačné stránky projektov (Potulky Bibliou, Kurz Lectio).

**Onboarding & systém**
- Onboarding (výber jazyka → 5 slidov nový user / „Čo je nové" pri update; verziovanie `onboarding_version`), intro kroky (Silencio…Actio), **Profil**, **Nastavenia** (jazyk, font, veľkosť písma, biblia, lectio audio mód, obrazovka nezhasína), **Pomoc/Návody** (coach marks, **per-OS** iOS/Android), Feedback, O aplikácii, Súkromie/GDPR, in-app zoznam notifikácií + nastavenia.

**Engagement & infra**
- App-rating prompt (po 5 otvoreniach, cooldown 90 dní), support/donation prompt (každé 10. otvorenie, cooldown 30 dní), notifikácia o novej verzii (force/soft update). **Umami Analytics**, **Firebase Crashlytics**, CI/CD (GitHub Actions), app ikony + splash, edge-to-edge.

---

## 4. Hodnotenie

### ✅ Silné stránky
- **Široká, dotiahnutá funkčnosť** — od denného lectio cez pobožnosti, e-shop, dary až po duchovné cvičenia; jeden konzistentný produkt.
- **Robustné audio** (pozadie, lock screen, offline, auto-progresia, mini-player) — technicky najnáročnejšia časť, zvládnutá.
- **Multilingválnosť** s reťazeným fallbackom a identickým setom kľúčov vo 4 jazykoch.
- **Bezpečné platby** — serverový prepočet cien/poštovného, webhook pre všetky terminálne stavy, faktúry/dobropisy s tokenom.
- **Offline-first prvky** (cache lectio, stiahnuté audio, banner) + **home-screen widgety**.
- **Konzistentný brand** (deep-purple paleta, Home v2 redizajn).

### ⚠️ Body na pozornosť
- **Veľké súbory** na refactor: `profile_screen` (~2551), `home_screen` (~2054), `lectio_screen`.
- **3 nelokalizované obrazovky** (Duchovné cvičenia — detail/registrácia/zoznam) — hardcoded SK, čaká externalizácia do `*.json`.
- **FR obsah** v DB čiastočný (UI hotové), `name_fr` chýba v notif. modeli → FR padá na EN.
- **Beta/blokované balíčky:** `flutter_html` (beta), `just_audio_background` (beta), `app_links` pin (blokuje `supabase_flutter`).
- **Bez automatizovaných testov** na strane mobilu.
- **Roly:** 10 `admin` (väčšina by mala byť `editor`).
- **Dočasne vypnuté:** DND (Nerušiť), Background Play nastavenia, Lectio dotazník.

### 📊 Celkové hodnotenie: **9 / 10**
Zrelý, produkčne pripravený klient s nadpriemernou šírkou funkcií a kvalitne riešeným audiom/offline. K desiatke chýba refactor pár veľkých obrazoviek, dokončenie FR obsahu, lokalizácia DC obrazoviek a mobilné testy.

---

## 5. Ďalšie kroky
- **Pred releasom (14. 7.):** release-build gates → [`PRODUCTION_CHECKLIST.md`](PRODUCTION_CHECKLIST.md) (SQL migrácie v prod, `flutter analyze`, version bump, store buildy, ikony/splash, zapnúť podporovateľskú zľavu).
- **v11.1+:** pt-BR (web/obsah/preklad), Inbox, accessibility (Semantics), Android 8/9 audio fallback, FCM token cleanup.
- **v11.2+:** refactor veľkých obrazoviek, medzinárodné poštovné, internacionalizačná infraštruktúra, streak & stats.
- **v11.3+:** Teologické prehĺbenie (Magisterium AI), rola `editor`.

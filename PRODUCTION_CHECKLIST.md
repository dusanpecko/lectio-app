# 📋 Production Checklist & Roadmap — Lectio Divina

> Zostávajúce úlohy pre mobil (Flutter) + backend (Next.js). **Hotový stav appky** → [`PROJECT_AUDIT.md`](PROJECT_AUDIT.md).
> V obchodoch: **v11.0.1+6000003** (manuálne publikovanie **14. júl 2026** 🎂) · Vo vývoji: **v11.1.1+6000005** · Aktualizované: **4. september 2026**

**Legenda:** `[ ]` = treba urobiť · `[x]` = hotové · ⚠️ = blokované / na overenie

---

# 🧪 Testovacie (staging) prostredie — pred ďalšou verziou

> **Dôvod (21.7.2026):** Creator Studio a tvorcovské moduly (série, deviatniky, adorácie, krížové cesty, duchovné cvičenia s prihláškami) posúvajú projekt tak ďaleko, že **v testovacej verzii už NESMIEME používať živé produkčné dáta**. Prihlášky obsahujú osobné údaje (meno, dátum narodenia, číslo OP, e-mail), obsah tvorcov ide na verejné subdomény, e-maily chodia reálnym ľuďom. Ďalšia verzia (web aj mobil) musí bežať na oddelenom staging prostredí s izolovanými, neprodukčnými dátami.

- [ ] **Samostatná Supabase inštancia (staging)** — vlastný projekt/DB, oddelené od produkcie; schéma cez migrácie, dáta anonymizované/seed (žiadne reálne prihlášky, e-maily, platby, overovacie dokumenty).
- [ ] **Web staging** — samostatný Vercel projekt/branch (napr. `staging.lectio.one` + `*.staging.lectio.one` wildcard pre subdomény tvorcov), vlastné env (staging Supabase, staging B2 bucket/prefix, **testovacie SMTP** — mailbox trap, nie reálne odosielanie), reCAPTCHA test kľúče.
- [ ] **Mobil staging build** — flavor/scheme mieriaci na staging API + staging Supabase (dev/staging/prod konfigurácia), oddelený bundle id (napr. `.staging`), TestFlight/interný track.
- [ ] **Izolácia médií** — staging B2 prefix (napr. `staging/`) alebo samostatný bucket; nikdy nezdieľať s produkciou.
- [ ] **E-maily v stagingu** — SMTP smerovať do zachytávača (napr. Mailtrap/Ethereal) alebo whitelist interných adries; žiadne e-maily reálnym účastníkom/tvorcom.
- [ ] **Platby** — Mollie test mód (test API kľúč), žiadne živé transakcie.
- [ ] **Seed dáta** — pripraviť seed skript (testovací tvorca `pecko`, ukážkové série/pobožnosti/DC) namiesto klonu produkcie.
- [ ] **Prístup** — staging za basic-auth/allowlist, aby sa neindexoval a nepomiešal s produkciou.

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

### v11.1+ — jul 2026 - ✅ vydané
- [x] **Deviatniky (Novény)** ✅ 11.7.2026 — kompletná funkcia, otestovaná E2E: DB (`novenas` + `novena_days` + kategórie, RLS), admin `/admin/novenas` (jazykové záložky, rich text, dni, TTS per úvod/deň/záver, ilustračný obrázok — zdieľaný jazykmi), mobil (menu Deviatniky, zoznam s progresom a náhľadmi, kalendárny progres od štartu — lokálny, denné pripomienky, slidy úvod/deň/záver, copy, jazykové čipy, obrázkový hero). + **jednotný zbaliteľný hero** (`CollapsibleHeroAppBar` — vzor krížové cesty) nasadený na KC + adorácie + ruženec + deviatniky. _Obsah deviatnikov = editorská práca v admine (texty + TTS + obrázky)._
- [x] **Spytovanie svedomia (spovedné zrkadlo)** — pridať do sekcie modlitieb (multijazyčne, aj s audiom).
- [x] **E-shop — platba na dobierku** ⚠️ _čaká na E2E test_ — dnes máme len Mollie (karta); doplnená dobierka ako platobná metóda (checkout voľba, príplatok za dobierku, objednávka bez online platby → stav `pending_cod`, fulfillment manuálne, faktúra pri odoslaní cez „Odoslať dobierku" v admine). Pred testom: spustiť `backend/sql/add_cod_and_company_to_orders.sql` v Supabase + v admin Účtovníctve zapnúť `cod_enabled` (master flag, default OFF).
- [x] **E-shop — objednávka pre firmy** ⚠️ _čaká na E2E test_ — fakturačné údaje firmy v checkoute (IČO, DIČ, IČ DPH, názov firmy) + prenesenie na faktúru/dobropis.
- [x] **Home — featured slidy pre duchovný obsah** ✅ 11.7.2026 — do featured carouselu (kde sú Potulky a Kurz) pridaných 6 slidov s overline „POBOŽNOSTI": Krížové cesty, Základné modlitby, Deviatniky, Spytovanie svedomia, Ruženec, Adorácie — vstupné body na duchovný obsah priamo z home. Náhodný štartovací slide rotuje cez všetky strany.
- [x] **Úmysly — notifikačný schvaľovací flow** ✅ 7.7.2026 — používateľ pošle úmysel → admin dostane push (`notify-admin`, INSERT webhook) → po schválení (`approved=true`) dostane odosielateľ lokalizovaný push „Váš úmysel bol schválený a zaradený medzi modlitby" (`notify-approved`, UPDATE webhook, podľa `intentions.lang`). Informačná notifikácia — otvára hlavnú stránku, bez deep-linku. _Pozn.: Supabase webhook URL musí byť `www.lectio.one` (apex 301-redirect pg_net nenasleduje)._
- [x] **Audio disk cache (`LockCachingAudioSource`)** ✅ 7.7.2026 — stream sa cachuje na disk (Caches/, OS-evictable) na 6 streamovacích miestach (lectio player track+interlude, MediaPlayerBus, modlitby, universal, adorácie, krížové cesty); offline súbory ostávajú `AudioSource.file`. + home seek bar (`daily_podcast_card._ProgressBar`) prerobený: drag-state + seek raz na `onChangeEnd` + spinner počas bufferovania (namiesto seeku pri každom pixeli). Seek do vypočutej časti a opakované prehratie sú okamžité. Overené iOS + Pixel. _Správu miesta cache zatiaľ rieši OS; limit/čistenie doplniť ak bude treba._
- [x] **Semantics labels pre screen reader** ✅ 7.7.2026 (zameraný prechod hlavnej cesty) — 15 `a11y_*` kľúčov (sk/en/es/fr). Audio ovládanie (play/pauza/stop/skip/seek — `lectio_audio_controls`, `lectio_floating_audio_player`, `audio_player_controls`, `lectio_step_card` Semantics per krok), lectio navigácia (chevrony sekcií, šípky dňa Semantics), home hero obrázok `excludeFromSemantics` (dekoratívny). _Úplný sweep zvyšných ~80 obrázkov/tlačidiel = neskôr, ak bude záujem (viď v11.2 poznámka)._
- [x] **FCM Token Cleanup Cron** ✅ 7.7.2026 — `/api/cron/fcm-token-cleanup` (Bearer CRON_SECRET, fail-closed) maže tokeny s `last_used_at` starším ako 90 dní; týždenne (ne 4:00, `vercel.json`). Neplatné tokeny sa deaktivujú už pri odosielaní (`sendPushNotificationWithCleanup`) — cron rieši vekovú očistu. _Aktivuje sa po deployi backendu._


### v11.2+ — september 2026

**Hotové 24.7.2026 — Pobožnosti v2 + Creator Studio audio + Deviatniky:**
- [x] **Pobožnosti — jednotný v2 dizajn + prehrávače** ✅ 24.7.2026 — krížové cesty, adorácie a kontemplatívny ruženec prepísané na `lectio_screen` štýl: hero (názov + biblický odkaz + autor) → karta „Celé audio" → PageView kariet sekcií (každá vlastná stopa cez zdieľaný `MediaPlayerBus` → presná dĺžka/seek, lock-screen, background, heartbeat) → fullscreen čítačka (`LectioReaderScreen` zovšeobecnená na HTML + ťuknutie/ikonka). „Celé audio" = backend spojí sekcie a **medzi ne vloží meditačnú hudbu** (ffmpeg) + uloží dĺžku; zdieľaný LD generátor pre adoráciu aj ruženec. Staré pole „Audio nahrávka" v ruženci skryté (dáta v DB ostávajú). **DEPLOY:** `add_adoration_interlude_full_duration.sql` ✅, `create_creator_music_gallery.sql` ✅, `add_rosary_full_audio.sql` ✅ (overené v DB 4.9.2026 — všetkých 5 stĺpcov existuje). _Mobil ide s ďalším buildom._
- [x] **Auto-meranie dĺžok sekcií (ffprobe)** ✅ 24.7.2026 — generátor „Celého audia" (adorácia + ruženec, admin aj creator) pri sťahovaní častí odmeria každú cez ffprobe a uloží do `audio_durations` (KC → `audio_duration` per zastavenie) → štítky času na kartách sa dopĺňajú automaticky, žiadny manuálny backfill.
- [x] **Hudobná galéria pre tvorcov** ✅ 24.7.2026 — kurátorská galéria licencovaných melódií (`creator_music_gallery`): admin `/admin/creator-music` (upload MP3 do B2 `music/`, dĺžka, kredit, aktivácia) + creator `MusicPicker` (obdoba galérie obrázkov) v editore adorácie + KC — tvorca **vyberie z galérie alebo nahrá vlastnú**. **DEPLOY:** `create_creator_music_gallery.sql` ✅.
- [x] **Bezpečné mazanie pobožností (súbory)** ✅ 24.7.2026 — mazanie adorácie/KC/ruženca (admin aj creator) čistí aj vlastné súbory (sekcie, zastavenia, spojené audio, obrázky) cez server; tvrdé pravidlo: zdieľaná galéria (`gallery/`, `music/`) sa NIKDY nemaže, z B2 len `creator-media/`. Nové admin DELETE endpointy (adoration/stations/rosary) + `devotionCleanup.ts`.
- [x] **Deviatnik — len jazyk aplikácie** ✅ 24.7.2026 — zoznam aj detail ukazujú deviatnik iba v jazyku appky (nie všetky jazykové verzie); prepínač jazykov sa skryje.
- [x] **Deviatnik — reštart** ✅ 24.7.2026 — „Modliť sa znova" po dokončení reštartuje na jeden ťuk na 1. deň (zachová pripomienku); počas rozmodleného deviatnika reštart s potvrdením v hlavičke (ikona ↻).
- [x] **Deviatnik — notifikácia otvorí deviatnik** ✅ 24.7.2026 — ťuknutie na dennú pripomienku otvorí konkrétny deviatnik (payload JSON `{type:novena,baseCode}` → `_openNovena` načíta variant v jazyku appky). _(Predtým plain-string payload, ktorý sa nespracoval.)_
- [x] **Admin — zrušenie predplatného používateľa** ✅ 24.7.2026 — v detaile používateľa admin zruší predplatné (Mollie), e-mail o zrušení chodí vždy; garantované „jeden user = jedno aktívne predplatné". Doplnený chýbajúci endpoint `/api/cancel-subscription` (mobil predtým dostával 404 HTML).

- [x] **HTML značky v textoch lectio** 🐞 ✅ opravené 4.9.2026 — používatelia videli v krokoch priamo `<p>`, `<br>`. **Príčina:** admin `lectio-sources/[id]` mal na štyroch krokoch (lectio/meditatio/oratio/contemplatio) `AITextField` s `enableRichText={true}` → tlačidlo „Rich formátovanie" ukladalo HTML, ale mobil (`LectioStepCard` → `Text`) aj web (`[locale]/lectio/page.tsx`, plain JSX) vykresľujú čistý text. **Rozsah:** 265 riadkov, ~1050× `<p>` + 31× `<br>`, **všetkých 23 dní viditeľného okna vo všetkých jazykoch** (preto tie telefonáty). TTS zasiahnuté nebolo — `api/text-to-speech` si HTML odstraňuje samo, audio netreba generovať znova. **Oprava v troch vrstvách:** (1) dáta — [`sql/fix_lectio_html_tags.sql`](../backend/sql/fix_lectio_html_tags.sql) spustená ✅, `</p>` → prázdny riadok (odstavce zachované), pôvodné hodnoty v `lectio_sources_html_backup` (265 riadkov, rollback v súbore); kontrola po spustení = 0 tagov; **funguje aj pre už vydanú v11.0.1, bez nového buildu**; (2) klienti — `lectio_screen._plainText()` (mobil, reuse `stripReaderHtml`) + `plainTextFields()` vo web lectio stránke, aby jeden zle uložený záznam už nikdy nepokazil obrazovku; (3) zdroj — `enableRichText` z tých štyroch polí odstránené (obyčajné pole ako `actio_text`; formátovanie sa reálne nepoužívalo — v celej DB 4× bold, 1× kurzíva). _Pozn.: `enableRichText={true}` sa už nikde v admine ani v /creator nepoužíva._

- [x] **🐞 FCM token sa po prihlásení nepripojí k účtu (RLS + upsert)** ✅ opravené 5.9.2026 _(nájdené pri teste na Pixeli)_ — pri každom štarte Androidu v logu: `PostgrestException(new row violates row-level security policy (USING expression) for table "user_fcm_tokens", code 42501)`.
  - **Príčina (zreprodukovaná v SQL, nie odhad):** `INSERT … ON CONFLICT DO UPDATE` vyžaduje, aby bol konfliktný riadok **viditeľný cez SELECT politiku**. Všetky SELECT politiky na `user_fcm_tokens` sú `user_id = auth.uid()`, takže anonymný riadok (`user_id IS NULL`, vytvorený verejným endpointom pre neprihlásených) prihlásený používateľ **nevidí** → upsert padne. Politika `fcm_update_claim` (`USING true`) bola pridaná práve na prevzatie anonymného tokenu a **obyčajný `UPDATE` naozaj prejde** — ale appka používa upsert, takže k prevzatiu nikdy nedôjde. Overené: po dočasnom pridaní SELECT politiky upsert prešiel.
  - **Dôsledok:** kto appku najprv používal neprihlásený a potom sa prihlásil, má token natrvalo `user_id = NULL`. Denné push notifikácie mu chodia (denný sender podľa `user_id` nefiltruje), ale **cielené osobné pushe** (napr. „váš úmysel bol schválený", ktoré hľadajú tokeny podľa `user_id`) mu neprídu. Dnes sú takto zaseknuté 3 tokeny — je to nová funkcia, ale leží to na ceste každej novej inštalácie.
  - **Možnosti opravy:** (a) v appke najprv `UPDATE … WHERE token = …` (prevzatie, funguje) a až potom upsert; (b) **odporúčam** — registrovať vždy cez `/api/public/fcm-token` s Bearer tokenom a nechať server (service-role) priradiť `user_id`; jedna cesta pre prihlásených aj neprihlásených, žiadna RLS gymnastika; (c) SELECT politika „authenticated vidí riadky s `user_id IS NULL`" — **neodporúčam**, sprístupní to všetky anonymné tokeny každému prihlásenému.
  - **Oprava (varianta b):** registrácia ide **vždy** cez `/api/public/fcm-token` — pre prihlásených aj neprihlásených. Endpoint prijíma `Authorization: Bearer` a `user_id` berie z **overeného** tokenu, nikdy z tela požiadavky; bez hlavičky uloží `user_id = NULL`. V mobile zmizlo dvojité vetvenie v `fcm_service.dart` (registrácia aj `onLanguageChanged`), priamy Supabase upsert je preč. Rate-limit per IP zostáva pre anonymné požiadavky, overený používateľ mu nepodlieha — inak by NAT sieť (fara, škola) vyčerpala limit za pár prihlásených zariadení.
  - **✅ Nasadené 5.9.2026:** backend na Verceli (commit `f12ca77`), overené volaním nového `GET /api/public/fcm-token`; APK na Pixeli. Po štarte appky **0 chýb v logu** (predtým 2 pri každom spustení) a počet zaseknutých anonymných tokenov klesol 3 → 2, čiže prevzatie funguje.
  - **⚠️ Poradie nasadenia:** najprv backend, potom mobil. Starý backend hlavičku ignoruje (token by ostal anonymný, bez chyby), takže sa nič nerozbije — ale prevzatie tokenu začne fungovať až po deployi.
  - **Overiť po nasadení:** prihlásiť sa v appke a skontrolovať, že riadok v `user_fcm_tokens` má `user_id` vyplnené (3 dnes zaseknuté anonymné tokeny sa priradia, keď tie zariadenia dostanú nový build).
  - **Doriešené v tom istom kole (5.9.2026):**
    - **Čas denného lectia pre neprihlásených** ✅ — `updatePreferredLectioTime` aj `getPreferredLectioTime` išli priamo do `user_fcm_tokens`, takže neprihlásenému ich RLS ticho odmietla (zápis 0 riadkov, čítanie prázdno) a čas si nenastavil — hoci obrazovka nastavení prihlásenie **nevyžaduje**. Oboje teraz cez endpoint; do `/api/public/fcm-token` pribudol `GET ?token=…` na čítanie.
    - **🔒 Odhlásenie nedeaktivovalo token** ✅ — `deactivateToken()` robil priamy UPDATE, lenže `AuthChangeEvent.signedOut` príde **až po zahodení session**, takže klient bežal ako `anon` a RLS update ticho zahodila (overené v SQL: **0 riadkov**, bez chyby → appka logovala úspech). Token tak ostal aktívny **aj priradený odhlásenému účtu** a ten dostával osobné notifikácie na telefóne, z ktorého sa odhlásil. Teraz `action: 'logout'` na endpointe: `is_active = false` + `user_id = NULL`; pri ďalšom otvorení sa zariadenie zaregistruje ako anonymné (denné lectio mu chodí ďalej).
    - **Politiky upratané** ✅ — [`sql/cleanup_fcm_token_policies.sql`](../backend/sql/cleanup_fcm_token_policies.sql) spustená: zrušená duplicitná sada `user_fcm_tokens_*_policy` a príliš široká `fcm_update_claim` (`USING true` dovoľovala prihlásenému prepísať `user_id` na ľubovoľnom riadku, ktorého token poznal) → nahradená prísnou `fcm_update_own`. Zostáva 5 politík namiesto 9.
    - **V appke je už 0 priamych zápisov do `user_fcm_tokens`** — registrácia, zmena jazyka, čas denného lectia aj odhlásenie idú cez endpoint; celý backend k tabuľke pristupuje cez service-role.

- [x] **🔒🐞 Biometria pri spovedi sa po aktualizácii sama vypla (regresia)** ✅ opravené 5.9.2026 — vo verzii z App Store fungovala, po 11.2 zmizla a ostal len PIN. **Príčina:** `migrateLegacyStorage()` sa volala pri **štarte appky** (`main.dart`) — presúva biometrickú kópiu DEK do úložiska viazaného na biometriu, lenže ten zápis si vyžiada systémový prompt. Ten sa preto pýtal na odtlačok **hneď na home screene**, mimo kontextu (presne to si všimol Dušan), a keď neprešiel (`Window{BiometricPrompt} does not have a surface`), `catch` **zmazal starú kópiu**. Nová sa nezapísala, stará zmizla → biometria nenávratne preč, a zapnúť sa dá len pri prvom nastavení PIN-u.
  - **Oprava:** migrácia sa pri štarte už nespúšťa (beží v `unlockWithPin`, kde je používateľ overený) · stará kópia sa maže **až po overenom** zápise novej (`containsKey`) · čítanie má fallback na starú kópiu, takže sa nikto o odomykanie neprosí · `resetOnError: false` na biometrickom úložisku — predvolené `true` mazalo dáta pri zlyhanom čítaní, a to zlyháva bežne (keystore log: `KEY_USER_NOT_AUTHENTICATED … timeout=5s`).
  - **iOS pýtal biometriu 4× pri otvorení spovede** — každý dotyk chráneného kľúča si na iOS žiada overenie zvlášť (2× kontrola stavu + `local_auth` + čítanie). Stav biometrie sa teraz drží ako **príznak v bežnom úložisku** (nie je to tajomstvo, kľúč ostáva chránený) a `local_auth` beží len na Androide, kde je nutný kvôli oknu platnosti keystore kľúča. Overené: iOS už pýta raz.
  - **Ostáva (nie blocker):** biometriu sa dá zapnúť len pri prvom nastavení PIN-u a vypnúť sa nedá vôbec — pri trezore na spoveď by prepínač mal existovať (napr. v paneli súkromia).

- [x] **Ruženec — dve rôzne písma v jednej pobožnosti** ✅ opravené 5.9.2026 — úvod mal iný font než ďalšie kroky. **Príčina nie je v kóde ruženca, ale v dátach:** 9 zo 60 úvodov (a 3 komentáre) je v DB uložených **bez `<p>` tagov**, a štýlová mapa `Html` widgetu nastavovala typografiu len na `p` — text bez tagov teda spadol na predvolený `body`. Opravené v štýle, nie v dátach (inak by sa to vrátilo pri prvom vložení textu bez tagov): `body` má rovnakú typografiu ako `p` a obidva dedia rodinu písma z témy, takže sa rešpektuje aj font zvolený v Nastaveniach. Rovnaký latentný problém opravený aj v **adorácii a krížovej ceste**.

- [x] **Inbox sa zobrazoval v jazyku, pre ktorý nemá obsah** ✅ opravené a **nasadené** 5.9.2026 (commit `c38a226`) — správa s vyplnenou len `sk` sa ukázala aj v EN verzii appky, lebo endpoint mal fallback `content[lang] ?? content[default_lang]`. Inbox je per-jazyk: keď admin jazyk nevyplnil, tých ľudí osloviť nechcel. Podmienka je vo **výbere kandidátov**, nie až za ním — inak by správa bez prekladu „zabrala" miesto tej, ktorá preklad má. Overené na produkcii po nasadení: `en`/`es`/`fr` → `{"message":null}`, `sk` → správa sa vráti (oprava teda nezhasla ani slovenskú verziu).

- [x] **Nastavenia notifikácií bez prihlásenia** ✅ opravené 5.9.2026 — obrazovka prihlásenie nevyžaduje, ale online (topic) preferencie bez účtu API nevráti: na iOS sa preto zbalila celá obrazovka („chyba načítania") a používateľ si nenastavil ani lokálnu pripomienku modlitby. Teraz sa online preferencie bez prihlásenia **vôbec nesťahujú**, nehlási sa chyba a zobrazí sa lokálna časť. Prepínač denného lectia je topic viazaný na účet → odhlásenému ukáže výzvu na prihlásenie namiesto tichého nič.

- [x] **🐞 Čierne ikony systémových líšt v tmavom režime** ✅ opravené 5.9.2026 _(nájdené pri edge-to-edge sweepe)_ — v tmavom režime boli hodiny, wifi a signál **čierne na tmavom pozadí**. `home_screen`, `lectio_screen` a `about_screen` mali `statusBarIconBrightness: Brightness.dark` **natvrdo** — teda čierne ikony bez ohľadu na tému. Zvyšných 49 obrazoviek to má podľa témy, preto to vyzeralo náhodne; zasiahnuté boli práve tie najpoužívanejšie. Pri oprave sa našlo to isté o poschodie nižšie: `systemNavigationBarIconBrightness` sa nastavovalo **raz pri štarte** natvrdo na tmavé, takže v tmavom režime boli čierne aj ikony navigačnej lišty (vidno pri 3-tlačidlovej navigácii). Teraz sa nastavuje v `MaterialApp.builder`, ktorý sa prekresľuje pri zmene témy — obrazovky si cez `AnnotatedRegion` prepisujú len stavový riadok, polia navigačnej lišty nechávajú `null`, takže sa to nebije.

- [ ] **Mŕtve FAB menu — 3 súbory na zmazanie** _(po vydaní)_ — rozbaľovacie FAB menu bolo z appky odstránené, ale zostali po ňom súbory s **nulou importov**: `widgets/app_floating_menu.dart` (220 r.), `widgets/speed_dial_fab.dart` (292 r.), `widgets/lectio_speed_dial_fab.dart` (272 r.) — spolu **784 riadkov**. Rovnaký prípad ako legacy audio pár; zmazanie je overiteľné jedným `flutter analyze`. _(V appke ostávajú štyri obyčajné FAB tlačidlá — úmysly, poznámky, admin inbox, uloženie v nastaveniach notifikácií.)_

- [ ] **Kontrola prekladu v lectio pipeline** 🌍 _(malá vec, nie blocker — pôvodne som to nahlásil ako chybu, nie je to chyba)_ — pipeline najprv skopíruje SK text do ostatných jazykov a preklad prichádza až pri príprave toho mesiaca; **obsah sa tvorí mesiac pred termínom**, takže slovenský text v riadku `lang<>'sk'`, ktorého deň je ešte ďaleko, je normálny rozpracovaný stav. Overené 4.9.2026: vo viditeľnom okne **0 zasiahnutých dní**, prvé dni so slovenčinou sú 2.–4. 10. 2026 (t. j. ~mesiac dopredu = presne v pracovnom okne). Adventný blok (od 29. 11., cyklus B: EN 9/23, ES 27/33) sa prekladá koncom októbra.
  - **Čo naozaj doplniť:** kontrolu, ktorá spadne, len keď slovenčina zostane v riadku, **ktorého deň sa blíži** (≤2 týždne) — nie pri generovaní, tam je slovenčina očakávaná. Heuristika na slovenské slová/diakritiku + `lang <> 'sk'`. Ušetrí to ručné prechádzanie pred každým mesiacom.
  - **Pri každej takej kontrole najprv overiť `rok` a aktívny cyklus** (`liturgical_years`) — cyklus, ktorý nie je na rade (C až 2028), sa vôbec neservíruje a inak z toho vyjde falošný poplach.

- [ ] **⚠️ targetSDK → Android 16 (API 36)** — **DEADLINE 31. 8. 2026 (Google Play, tvrdý)**. Google Play od 31.8.2026 nedovolí aktualizovať appku, ktorá necieli na API level vydaný max. rok pred najnovším Androidom. Bez toho sa **žiadny ďalší update nedá vydať** po deadline. _(Súvisí s edge-to-edge sweepom nižšie — API 36 edge-to-edge vynucuje ešte prísnejšie.)_
  - **✅ Kód nastavený (23.7.2026):** `targetSdk = 36` + `compileSdk = 36` v `android/app/build.gradle.kts`. Prostredie OK: Flutter 3.44.6, AGP 8.11.1, Gradle 8.14.3, SDK 36/36.1 nainštalované. Edge-to-edge už vyriešené (`SystemUiMode.edgeToEdge` v main.dart + `values-v35/styles.xml` platí aj pre API 36, žiadny `windowOptOutEdgeToEdgeEnforcement`). **Debug build overený** (`flutter build apk --debug` OK). Pozn.: build hlásil, že plugin `jni` chce NDK 28.2 (projekt má default 27.0) — nie je to blocker, dá sa zladiť cez `ndkVersion`.
  - **Stav 4.9.2026:** deadline **už uplynul** — kým sa nevydá build s API 36, na Google Play sa nedá publikovať aktualizácia. Kód je pripravený (`targetSdk = 36`) a verzia nabumpovaná na **11.1.1+6000005**, takže build prejde. **Ostáva:** `flutter build appbundle --release` → interné/uzavreté testovanie → otestovať na reálnom Androide 16 → povýšiť do produkcie. Žiadny AAB zatiaľ nie je zbuildený.
- [x] **Inbox — Fáza 1** ✅ nasadené 24.7.2026 — in-app popup správy (web+mobil): popup po otvorení appky, per jazyk, cielené (platforma/verzia pre všetkých; publikum registrovaný/neregistrovaný + rola/darca/predplatné pre prihlásených). Backend: migrácia `create_inbox_messages.sql` + `/api/admin/inbox` CRUD + `/api/inbox/active` (cielenie) + `/api/inbox/seen`. Web admin `/admin/inbox` (editor per jazyk, obrázok, tlačidlá→screen, plán, náhľad). Mobil: popup z `home_screen` (obrázok/nadpis/text/tlačidlá→screen), frekvencia once/until_dismissed/every_open, Umami eventy. **DEPLOY:** `create_inbox_messages.sql` ✅ spustená. **Fáza 2** ✅ hotová (overené 4.9.2026) — admin compose priamo v appke: `screens/admin/inbox_admin_list_screen.dart` + `inbox_admin_editor_screen.dart`, dostupné z profilu (`profile_screen.dart:1829`).
- [x] **Push tokeny pre neprihlásených** ✅ nasadené 24.7.2026 (web+mobil): (1) migrácia `backend/sql/allow_anonymous_fcm_tokens.sql` — `user_id` → NULLABLE (bez nej sa anon token nedá vložiť, NOT NULL constraint); (2) verejný endpoint `backend/.../api/public/fcm-token` — service-role upsert bez `user_id` (nový = NULL, existujúci prihlásený si ho ponechá), dedikovaný rate-limit 30/10min per IP (NIE zdieľaný payment limiter); (3) mobil `fcm_service.dart` — pri `userId == null` registrácia + zmena jazyka idú cez endpoint namiesto priameho Supabase zápisu. Overené: denný sender (`send-daily-lectio`) tokeny podľa `user_id` NEFILTRUJE a opt-out filter anon (NULL) ponecháva → netreba meniť. **DEPLOY:** `allow_anonymous_fcm_tokens.sql` ✅ + backend nasadený; mobil ide s ďalším buildom. _(Používa existujúci `SUPABASE_SERVICE_ROLE_KEY` — žiadna nová env.)_
- [x] **Edge-to-edge QA sweep** ✅ 5.9.2026 — prešlo na **Androide 17 (Pixel 9a)**, teda na prísnejšom systéme, než pre ktorý bol bod písaný. Overené: plávajúce prehrávače, formuláre s klávesnicou, onboarding, PIN obrazovka spovede. Neaplikovateľné: dotazník lectio (vypnutý), otočenie na šírku (appka je zamknutá na portrét), FAB menu (v appke už nie je). **Nález:** ikony systémových líšt boli v tmavom režime čierne — opravené, viď bod nižšie. _Pôvodné znenie:_ **Edge-to-edge QA sweep (Android 15 / SDK 35)** — appka už edge-to-edge zapína (`SystemUiMode.edgeToEdge` v main.dart) + rieši insety (SafeArea + viewPadding); Google Play upozornenie je plošné pre všetky SDK 35 appky, nie reálny bug (overené na Pixel 9a / Android 15+). **Code audit 18.7.2026:** obsah nikde nie je za lištami (top `padding.top` + bottom `viewPadding.bottom` adaptívne, 40 obrazoviek prebíja overlay cez `AnnotatedRegion`, app-wide mini player + FAB rátajú s lištou, žiadny `extendBody`). Jediný nález — 4 obrazovky bez `AnnotatedRegion` na svetlom pozadí → biele status-bar ikony zle čitateľné; **opravené** (`AnnotatedRegion` s `isDark` farbou): `confession_gate`, `lectio_reader`, `lectio_survey`, `onboarding`. **Ostáva:** vizuálny sweep na Androide 15 (tie 4 obrazovky, spodné floating playery, FAB rozbalené menu, formuláre s klávesnicou).
- [ ] **Internacionalizácia** — infraštruktúra pre FR, PT, DE, PL, IT, CZ + export textov.
- [x] **Upratať print/debugPrint** ✅ 18.7.2026 — 16 živých `debugPrint` → `appLogger` (errory `.e(error:)`/`.w()`, UI/debug `.d()`); 6 zvyšných zmizlo so zmazaným mŕtvym audio zhlukom (nižšie). `flutter analyze lib/` = 0 nových hlásení (ostávajú len 3 predexistujúce deprecations). V `lib/` už 0 raw `print`/`debugPrint`.
- [ ] **Nová testovacia sada pre v2** — staré testy (pred-v2 HomeScreen, starý audio stack, widget_test s reálnym .env/Supabase) boli 2.7.2026 vymazané ako zastarané; ostal len `test/utils/ui_helpers_test.dart`. Napísať unit/widget testy pre v2 obrazovky a services (mocknúť Supabase, bez siete).
- [x] **Roly & oprávnenia — rola `editor` (foundation)** ✅ nasadené 24.7.2026 — per-user matica oprávnení (stránky + funkčné vlajky publish/delete/ai/translate). `users.permissions` JSONB, `permissions.ts` katalóg, `requireAccess({page,flag})` helper, `/api/admin/users/[id]/permissions` + `/api/admin/me`, matica v detaile používateľa (`EditorPermissionsSection`), sidebar skrýva nepovolené stránky, admin layout púšťa editora. **DEPLOY:** `add_editor_permissions.sql` ✅. **Ostáva (premerané 4.9.2026):** migrácia je z väčšej časti hotová — **92 súborov** už používa `requireAccess`, ale **62 ešte `requireAdmin`**; z nich sú obsahové (editor tam dostane 403): `adoration`, `rosary`, `stations-of-cross`, `programs`, `podcast-episodes`, `creator-*` moderácia, `creator-gallery`, `creator-music`. Zvyšok (`users`, `subscriptions`, `ai-credits`, `feature-flags`, `access`, `app-versions`, `send-notification`, `campaign-rewards`) má zostať admin-only. Ďalej: editor landing (dashboard prázdny) + preklasifikovať adminov — v DB je stále **9 adminov a 1 editor**. Detaily: memory `project_editor_permissions`.
- [ ] **Refactoring** — `profile_screen` (~2551), `home_screen` (~2054), `lectio_screen` rozdelenie. + dokončiť mazanie mŕtveho audio kódu. **Čiastočne hotové 18.7.2026:** zmazaný mŕtvy zhluk `lectio_audio_mixin` + `lectio_audio_controller` + `mini_audio_player` (overené 0 použití). **Premerané 4.9.2026:** `home_screen` 2054 → **1343** riadkov (rozdelenie hotové), `lectio_screen` **1324**, ale `profile_screen` 2551 → **2901** (narástol, rozdelenie ostáva). **Mŕtvy pár zmazaný ✅ 5.9.2026** — `floating_audio_player.dart` (441 r.) + `audio_player_service.dart` (180 r.), spolu 621 riadkov pred-v2 audio stacku, nahradené `LectioFloatingAudioPlayer`/`MediaPlayerBus`. Pred zmazaním overené 0 referencií (vrátane barrelu a testov), po zmazaní `flutter analyze` = 0. `background_audio_manager` NIE je mŕtvy — stále sa inicializuje v `bootstrap.dart`, jeho refactor si vyžaduje odviazať bootstrap.
- [x] **Ruženec — kompletný v2 rework** ✅ 24.7.2026 — kontemplatívny ruženec prepísaný na jednotný `lectio_screen` štýl + `MediaPlayerBus`: per-sekcia audio karty, „Celé audio" s meditačnou hudbou, background playback, app-wide mini player, lock-screen, fullscreen čítačka, ffprobe dĺžky (viď v11.2). _Ostáva len: **záložky a zdieľanie** (zakomentované, parkované — nízka priorita)._
- [ ] ⏸️ **Android — media notifikácia po zatvorení appky (8/9)** _(on-hold, opraviť len ak sa ozvú používatelia)_ — nie je bug, ale UX rozhodnutie. Dnes `main.dart:87` má `androidStopForegroundOnPause: false` (notifikácia ostáva cez pauzu → resume z lock screenu; nevýhoda: na Androide 8/9 môže po force-close visieť). Jednoriadkový „fix" = `true` (Spotify-like: pauza → notifikácia zmietnuteľná, zavretie appky → player zmizne; nevýhoda: po pauze+zamknutí sa nedá pustiť späť z notifikácie). Mení správanie na VŠETKÝCH Androidoch → nemeniť bez spätnej väzby. _(Pozn. 18.7.2026: mŕtvy audio zhluk `lectio_audio_mixin`+`lectio_audio_controller`+`mini_audio_player` už zmazaný; `BackgroundAudioManager` ostáva ako kompat. obálka nad `LectioAudioPlayer`, volaná z `bootstrap.dart`+`lectio_screen`.)_

### v11.3+ — október - november 2026
- [ ] **Creator Studio** 🎙️ — externí tvorcovia (biskup/biblista) pripravujú zamyslenia (video/audio/text/obrázky) cez samostatný portál `lectio.one/creator`; všetko cez schvaľovanie adminom. Stavia na `/admin/programs` (séria→sessions→media; verejný web už existuje), `/admin/articles` parkuje. Rola `creator` (vidí len svoje, ownership server-side), video len YouTube embed. **Fáza 1** = backend + /creator (admin 2.0) · **Fáza 2** = mobil sekcia (v11.3/11.4) · **Fáza 3** = štatistiky pre tvorcov. **Návrh (draft na prepracovanie): [`docs/CREATOR_STUDIO.md`](../docs/CREATOR_STUDIO.md).** **Pozn. (4.9.2026):** prvá veľká funkcia, ktorá pôjde podporovateľom skôr — Fáza 2 (mobil) sa vydá cez stav `supporters` prepínača `creator_studio_mobile` (viď bod o skoršom prístupe nižšie).
- [ ] **E-shop — medzinárodné poštovné** _(až keď sa e-shop spustí mimo SK)_ — teraz je poštovné **per-produkt, country-agnostické**. Pri expanzii: (a) per-produkt `shipping_cost_intl`, alebo (b) násobiteľ podľa skupiny krajín. Stačí pridať kód krajiny do `ALLOWED_COUNTRIES` + country zoznamov + doriešiť poštovné.

- [ ] **Podporovateľská bránka (`SupporterService`)** 🔑 — _základ pre bonusy pre podporovateľov nižšie, robiť ako prvé._ Dnes sa „je podporovateľ?" počíta na dvoch miestach a **inak**: mobil `app_engagement_service.dart:_isActiveSupporter` (whitelist tierov + `status='active'`, ale **nekontroluje `current_period_end`** → prepadnuté predplatné prejde) vs. backend `supporterDiscount.ts:activeSupporterTier` (`status='active' AND current_period_end >= now()`). Pred gatingom zjednotiť: jeden mobilný `SupporterService` (tier + dokedy, cache v pamäti, refresh po prihlásení/platbe) + jeden server helper; **gate vždy overiť aj server-side** (klienta sa dá obísť). Riadené jedným **master flagom** (vzor `cod_enabled` / supporter zľava) — default OFF, aby sa dal vypnúť bez buildu. _Jeden helper, nie kopírovaný `if` na piatich miestach._

- [ ] **„Páči sa mi" pri Lectio Divina + archív podľa evanjelistov a kapitol** 💜 _(len pre podporovateľov)_ — srdiečko na karte lectio (mobil, vedľa copy/expand v `lectio_step_card`) → nová tabuľka `lectio_likes (user_id, lectio_source_id, created_at)` + `/api/lectio/like` (GET → `{count, liked}`, POST → toggle; vzor `api/creator-content/follow/route.ts`, service-role + Bearer user). Na to naviazaný **archív**: prehľad všetkých lectio zoradených podľa evanjelistu a kapitoly (Mt / Mk / Lk / Jn → kapitola → perikopy) + záložka „Moje obľúbené". Dnes je lectio viditeľné len ±pár dní — archív túto bránu otvára, preto je celá funkcia (like aj archív) pre podporovateľov; nepodporovateľ vidí pozvanie na podporu. _Ak by sme like chceli pre všetkých, gate ostane len na archíve._ **Prekrýva sa s rozšíreným dátumovým oknom nižšie** — okno je lacnejší prvý krok (rok dozadu cez existujúci `DateLimitsConfig`), archív pridáva navigáciu podľa kníh a kapitol.
  - **Dátový problém:** `lectio_sources.suradnice_pismo` je voľný text („Mt 5, 1–12") — na zoskupenie treba parser + **štruktúrované polia** (`bible_book`, `chapter`, `verse_from/verse_to`) doplnené migráciou a backfillom. Pozor: v cykloch B/C sú v súradniciach preklepy (`Mt` namiesto `Mk`/`Lk`) → backfill ich odhalí; opravuje sa **obsah**, nie parser.
  - **Domyslieť:** mobil vs. web (`/[locale]/lectio` má dnes len dnešný deň) — endpoint navrhnúť tak, aby poslúžil obom; per-jazyk (EN medzery sú historické, nie bug).

- [ ] **Creator Studio — „páči sa mi" pri obsahu** — sledovanie tvorcu už beží (`creator_follows` + `/api/creator-content/follow`, počet v `creator/me`). Doplniť like **na obsah** (session / séria / pobožnosť), nie na profil: `creator_content_likes (user_id, content_type, content_id, created_at)`, endpoint podľa vzoru follow, srdiečko v mobile v detaile obsahu + počet v štatistikách tvorcu (Creator Studio Fáza 3). Pre **všetkých prihlásených** (nie len podporovateľov) — je to spätná väzba pre tvorcu, nie benefit.

> **Bonusy pre podporovateľov — rozhodnuté 4. 9. 2026.** Pravidlo: bonus **nesmie nikomu nič odobrať** — vždy len niečo naviac. Zamietnuté: gatovanie copy pri lectio (odobranie funkcie, pri Božom slove neprijateľné — copy zostáva otvorený všetkým), ďalšie **odznaky podporovateľa** a **sledovanie pokroku / gamifikácia** v appke. Bez kódu: žurnál pre Zakladateľov ide manuálne poštou (zatiaľ žiadny Zakladateľ); „krátky ročný report" — ešte neprešiel rok.

- [ ] **Rozšírené dátumové okno pri lectio** 📅 _(bonus pre podporovateľov)_ — [`date_limits_config.dart`](lib/shared/date_limits_config.dart) dnes púšťa bežného užívateľa **15 dní dozadu / 7 dopredu** (`daysBack`/`daysForward`), admin bez limitu (`lectio_screen.dart:311-312`, `_isAdmin || …`). Podporovateľ dostane **365 dní dozadu / 30 dopredu** — nikomu sa nič neberie a obsah v DB už je (korektúra beží pol mesiaca dopredu). Namiesto pribúdajúcich `||` vetiev prerobiť na jedno `DateLimits.forRole({isAdmin, isSupporter})` → `(minDate, maxDate)` a použiť v `_canPrev`/`_canNext` **aj** v date pickeri (`_showDatePicker`). **Splní sľub „Skorší prístup k novému obsahu" (`tier_patron_f2`)** cez obsah, nie cez držanie funkcií v šuflíku.

- [ ] **Hlasovanie o funkciách + navrhovanie tém** 🗳️ _(splnenie sľubov `tier_patron_f4` „možnosť hlasovať" a `tier_patron_plus_f3` „navrhovať témy")_ — dnes neexistuje nič: `feedback_screen` je otvorený formulár pre všetkých a podnety sa netriedia podľa tieru. Doplniť `polls` (otázka, možnosti, obdobie, jazyk) + `poll_votes (poll_id, user_id)` s unique kľúčom, admin `/admin/polls`, v mobile karta „Hlasovanie" pre podporovateľov (výsledky vidno po odhlasovaní). **Cielenie netreba stavať** — Inbox už cieli publikum na darcu/predplatné, tú istú logiku použiť na viditeľnosť ankety. Druhá časť: k podnetu z `feedback_screen` ukladať tier odosielateľa, aby sa dali čítať prednostne.

- [ ] **Offline sťahovanie lectio — voľba 7 / 30 dní** _(bonus pre podporovateľov)_ — dnes je `lectio_screen.dart:78` `_offlineDays = 7` fixne. Podporovateľ dostane v nastaveniach **voľbu 7 alebo 30 dní**, **default zostáva 7** — 30 dní audia zaberie na telefóne veľa miesta, takže to musí byť vedomé rozhodnutie užívateľa, nie automat. Pred sťahovaním zobraziť odhad veľkosti; celkové úložisko už vie `AudioDownloadService.formattedStorageSize` + `downloadedFilesCount`.

- [ ] **Skorší prístup pre podporovateľov — stav `supporters` v `app_feature_flags`** 🎁 _(splnenie sľubov `tier_patron_f2` „skorší prístup k novému obsahu a funkciám" a `tier_patron_f3` „early access k pripravovaným kurzom")_ — **mechanizmus z 90 % existuje**: `app_feature_flags.state` má dnes `off | preview | on`, kde `preview` = len testeri ([`creator_studio_gating.sql`](../backend/sql/creator_studio_gating.sql), [`featureFlags.ts`](../backend/src/app/lib/featureFlags.ts)). Stačí pridať **štvrtú priečku rebríka**: `off → preview (testeri) → supporters (testeri + podporovatelia) → on (všetci)`.
  - **Zmeny:** (a) migrácia — rozšíriť `app_feature_flags_state_check` o `'supporters'`; (b) `featureFlags.ts` — typ `FeatureState` + parsovanie stavu a v poslednej vetve `visible = tester || jeAktívnyPodporovateľ(token)` (server helper `activeSupporterTier` už existuje v [`supporterDiscount.ts`](../backend/src/app/lib/shop/supporterDiscount.ts)); (c) prepínač stavu v admine.
  - **Pozor na cache:** v stave `supporters` závisí odpoveď od používateľa → routy musia dať `private, no-store` (rovnako ako pri `preview`); CDN cache sa vracia až v stave `on`. Presne preto `featureAccess` vracia `state` — routy si podľa neho volia hlavičky.
  - **Bez nového buildu appky:** prepínače vyhodnocuje server (appka posiela len `app_version`), takže „teraz to uvidia aj ostatní" je zmena jedného riadku v admine — žiadne App Store review.
  - **Kde to použiť:** Creator Studio Fáza 2 (mobil) · **Potulky s Bibliou** (launch pôst 2027, `screens/projects/potulky_bibliou_screen.dart`) · **Kurz Lectio Divina** (`screens/projects/kurz_lectio_screen.dart`). Každé veľké vydanie ide najprv `supporters`, po dohodnutom čase `on` — **pri každom novom module na to pamätať už pri návrhu**, nie dodatočne. _Domyslieť: ako dlho (14 alebo 30 dní?) a či to oznámiť cieleným Inboxom („máte to ako prví"), aby o výhode vôbec vedeli._

- [ ] **Omša za podporovateľov + automatická pripomienka** 🙏 — mesačná svätá omša za podporovateľov. Technická časť: termíny omší v admine + cron, ktorý **deň predtým** pošle podporovateľom cielenú notifikáciu/Inbox („zajtra bude slúžená omša za podporovateľov"). Cielenie na darcu/predplatné už Inbox vie, odosielanie rieši `cron/send-scheduled-notifications`. **Zároveň naplnenie sľubov „Prednostné info o novinkách" (`tier_friend_plus_f3`) a „rozšírené projektové aktualizácie" (`tier_patron_mini_f3`)** — kanál je postavený, treba ho reálne používať. _Domyslieť: či môže podporovateľ vložiť do omše vlastný úmysel (existujúce úmysly by to uniesli)._

- [ ] **Admin — manuálne nastavenie darcovského programu (od–do)** 🧩 _(ešte domyslieť)_ — dôvod: darca pošle jednorazovo vyšší dar mimo predplatného a admin mu za to prizná program (Priateľ / Patrón / Zakladateľ) na dohodnuté obdobie. V detaile používateľa (`/admin/users/[id]`) pribudne: tier + **platnosť od–do** + dôvod/poznámka + kto a kedy nastavil (audit).
  - **Otvorené: kde to uložiť.** (a) riadok v `subscriptions` (`status='active'`, `current_period_end` = „do", nové polia `source='manual'` + `granted_by` + `note`) — automaticky funguje všade, kde sa dnes číta predplatné (zľava v e-shope, bránka vyššie, odznak v profile, `activeSupporterTier`), ale mieša sa s Mollie predplatnými a s pravidlom „jeden user = jedno aktívne predplatné" + so zrušením predplatného v admine. (b) samostatná tabuľka `supporter_grants` — čisté oddelenie, ale treba prejsť **všetky** miesta, ktoré čítajú `subscriptions` (mobil aj backend). **Odporúčam (a) s `source`** — menej miest na zmenu, ale zrušenie predplatného aj cron/webhook musia manuálne granty ignorovať.
  - Doriešiť ešte: čo po expirácii (bez auto-obnovenia — e-mail/notifikácia?), či sa grant počíta do podporovateľskej zľavy v e-shope, a ako sa zobrazí v profile (rovnaký odznak ako predplatné vs. „darcovský program do …").

- [x] **Lokalizovať DC obrazovky** ✅ 24.7.2026 — všetky tri DC obrazovky lokalizované cez `tr()`: `registration_screen` (~60), `spiritual_exercise_detail_screen` (16 `tr()` — sekcie, chyby, termíny, FAB) + `spiritual_exercises_list_screen` (8 `tr()` — hero, filter, prázdny stav, počet, „Viac informácií"). 20 nových `se_*` kľúčov (sk/en/es/fr) + reuse `spiritual_exercises`/`back_to_list`. 0 hardcoded SK literálov, `flutter analyze` = 0.

### v11.4+ — december 2026
- [ ] **O aplikácii — Sponzori** — pridať sekciu sponzorov/podporovateľov do obrazovky O aplikácii (`about_screen`).
- [ ] **Brazílska portugalčina (pt-BR)** — web + marketing · obsah (kalendár, lectio-sources, krížové cesty, adorácie, modlitby) · preklad aplikácie (lokalizácia stringov).

### v11.5+ — január 2027


### v12.0+ 🎓 — Júl 2027
- [ ] **Teologické prehĺbenie (Magisterium AI)** — voliteľná sekcia pod Actio s AI-generovaným komentárom k dennému evanjeliu. Magisterium API (28 000+ dokumentov) + ChatGPT/Claude → 4 bloky: Teologické jadro, Cirkevní Otcovia, KKC, Dokumenty Cirkvi. 1× denne/jazyk, cache v DB, editovateľné adminom. *Nie chatbot.* Detaily: `docs/TEOLOGICKE_PREHLBENIE_MAGISTERIUM.md`. Validácia teológom, budget na API, pilot 100–200 users.
- [ ] **Prémiové témy + alternatívna ikona appky** 🎨 _(bonus pre podporovateľov — odložené z v11.3 na v12)_ — vzhľad má dnes každý (`settings_screen`: téma system/light/dark, font family + veľkosť). Pridať 2–3 témy **len pre podporovateľov** (napr. sépia, nočná modrá — brand paleta) + **alternatívnu ikonu appky** so zlatým akcentom (`#D4A853`): iOS `setAlternateIconName` (ikony musia byť v Info.plist `CFBundleAlternateIcons`), Android `activity-alias` s prepínaním `enabled`. Čisto kozmetické — nulový dopad na funkcionalitu, nič sa nikomu neberie.

- [ ] **Streak & Stats** — sledovanie pokroku, kalendár aktivity. _Pozn. (4.9.2026): pôvodný zámer NIE je klasická gamifikácia/streak, ale **sebarozvoj** — presnú podobu treba ešte ujasniť. Nemiešať s odmietnutými odznakmi a osobnými štatistikami čítania (viď pravidlo bonusov v v11.3)._
- [ ] **Liturgický kalendár** — svätec dňa na home screene.

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
- [ ] **AGP 9.0+ upgrade** ⚠️ _(Play R8 odporúčanie, nie bloker)_ — teraz AGP 8.11.1 + Gradle 8.14.3. Major upgrade: vyžaduje JDK 17+, breaking Gradle DSL/namespace/variant API, musí sadnúť s Flutter Gradle pluginom (podľa verzie Fluttera môže rozbiť build). Robiť MIMO release cyklu, spolu s upgrade Fluttera + release build test. _Play build aj bez toho prijíma. (Shrink resources = odporúčanie #1 už zapnuté 18.7.2026 v `app/build.gradle.kts`.)_
- [ ] `app_links` 6.4.1 → 7.0.0 ⚠️ (blokované `supabase_flutter`)
- [ ] `flutter_html` ^3.0.0-beta.2 ⚠️ beta
- [ ] `just_audio_background` 0.0.1-beta.17 ⚠️ beta
- [ ] **Deprecations** (audit 2.7.2026, len info) — `ConcatenatingAudioSource` v adoration_detail + stations_of_cross_detail **odstránený 24.7.2026** (obe prepísané na `MediaPlayerBus`); ostáva `onReorder` (lectio_survey — beztak vypnutý). Riešiť pri upgrade `just_audio` / Fluttera.

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

**5) Nelokalizované obrazovky** — ✅ **žiadne** (24.7.2026). Všetky tri DC obrazovky (`spiritual_exercise_detail/registration/list_screen`) sú lokalizované cez `tr()` (`se_*` kľúče v sk/en/es/fr).

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

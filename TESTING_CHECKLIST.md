# 🧪 Testovací checklist — Lectio Divina v11.0

> Pred releasom **14. 7. 2026** prejdi na **iPhone (iOS)**, **iPade** a **Androide**.
> Klikaj stĺpce a píš poznámky pri tom, čo nefunguje.

**Legenda:** `☐` = netestované · `✅` = OK · `❌` = nefunguje (napíš poznámku) · `—` = netýka sa / nedostupné

> Tip: každú sekciu otestuj ideálne aj v **2 jazykoch** (SK + ešte jeden) a v **svetlej aj tmavej** téme. Globálne veci (jazyk, téma, písmo, offline) sú v sekcii 0.

---

## 0. Cross-cutting (otestovať raz dôkladne na každej platforme)

| Oblasť | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Fresh install (čistá inštalácia) | ✅ | ✅ | ✅ | |
| Upgrade z predošlej verzie (dáta/login zostali) | ✅ | ✅ | ✅ | |
| Verzia v *O aplikácii* je správna (v11.0.0) | ✅ | ✅ | ✅ | _pozor na starý cache na iPade_ |
| Dark mode — všetky obrazovky čitateľné | ✅ | ✅ | ✅ | |
| Light mode | ✅ | ✅ | ✅ | |
| Jazyk SK — texty sedia, nič nepretečie | ✅ | ✅ | ✅ | |
| Jazyk EN | ✅ | ✅ | ✅ | |
| Jazyk ES | ✅ | ✅ | ✅ | |
| Jazyk FR | ✅ | ✅ | ✅ | |
| Offline režim — banner + skryté sieťové sekcie | ✅ | ✅ | ✅ | |
| Návrat online — obnovenie obsahu | ✅ | ✅ | ✅ | |
| Veľkosť písma (Nastavenia) sa prejaví **všade** (lectio, home, modlitby) | ✅ | ✅ | ✅ | |
| Veľkosť písma sa NErozbíja nav bar / prepínač dní | ✅ | ✅ | ✅ | |
| iPad — layout (nič roztiahnuté/rozbité na šírku) | — | ✅ | — | |

---

## 1. Onboarding & prihlásenie

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Nový používateľ — výber jazyka | ✅ | ✅ | ✅ | |
| Nový používateľ — plný onboarding (5 slidov) | ✅ | ✅ | ✅ | |
| „Čo je nové" (onboarding update) po update | ✅ | ✅ | ✅ | |
| Registrácia (email) | ✅ | ✅ | ✅ | |
| Prihlásenie (email/heslo) | ✅ | ✅ | ✅ | |
| Sign in with Apple | ✅ | ✅ | — | ⚠️ Apple OAuth **Secret Key** v Supabase expiruje po 6 mes. — pregenerovať |
| Zabudnuté heslo | ✅ | ✅ | ✅ | bez zmien, OK |
| Odhlásenie | ✅ | ✅ | ✅ | |
| Používanie bez prihlásenia (guest) | ✅ | ✅ | ✅ | |

---

## 2. Domov (Home)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Hero (obrázok, avatar, zvonček notifikácií) | ✅ | ✅ | ✅ | |
| Audio karta — prehrať cez **tlačidlo** | ✅ | ✅ | ✅ | |
| Audio karta — prehrať cez **obrázok** | ✅ | ✅ | ✅ | |
| Audio karta — Spotify tlačidlo | ✅ | ✅ | ✅ | |
| Výber dňa (date selector) → otvorí Lectio | ✅ | ✅ | ✅ | |
| Kalendár (ikona) → výber dátumu | ✅ | ✅ | ✅ | |
| Actio karta → dialóg | ✅ | ✅ | ✅ | |
| Featured duchovné cvičenie → detail | ✅ | ✅ | ✅ | |
| Aktuality (horizontálny zoznam) → detail / Zobraziť všetko | ✅ | ✅ | ✅ | |
| Spodná navigácia — všetkých 5 položiek (vrátane **Viac**) | ✅ | ✅ | ✅ | |
| Pull-to-refresh | ✅ | ✅ | ✅ | |
| Spodný priestor po karte aktualít (nie príliš veľký) | ✅ | ✅ | ✅ | |

---

## 3. Lectio

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Otvorenie dnešného Lectio | ✅ | ✅ | ✅ | |
| Prepínanie dní — šípky ‹ › (dajú sa pohodlne trafiť) | ✅ | ✅ | ✅ | |
| Prepínanie dní — kalendár (ťuk na dátum) | ✅ | ✅ | ✅ | |
| Admin — bez obmedzenia dátumov (minulosť/budúcnosť) | ✅ | ✅ | ✅ | |
| Výber biblie — **SSV / Jeruzalemská / Ekumenický** (správne názvy aj text) | ✅ | ✅ | ✅ | |
| Audio karta — „celé Lectio" dlhé (s hudbou) | ✅ | ✅ | ✅ | |
| Audio — krátke (bez hudby) podľa Nastavení | ✅ | ✅ | ✅ | krátke vygenerované až od 1.7; predtým fallback na dlhé (správne) |
| Per-krok play (Biblia/Lectio/Meditatio…) + progres prstenec | ✅ | ✅ | ✅ | |
| **Prepnutie dňa zastaví staré audio**, nový deň od začiatku | ✅ | ✅ | ✅ | |
| V rámci dňa pauza → pokračovanie | ✅ | ✅ | ✅ | |
| Kopírovať text kroku | ✅ | ✅ | ✅ | |
| **Fullscreen čítačka** — ťuk na kartu / ikonu ⤢ | ✅ | ✅ | ✅ | |
| Čítačka — swipe medzi krokmi | ✅ | ✅ | ✅ | |
| Čítačka — biela karta, play s prstencom, kopírovať | ✅ | ✅ | ✅ | |
| Čítačka — admin úprava textu / pregenerovanie audia | ✅ | ✅ | ✅ | |
| Offline — stiahnuť (7 dní), prehrať bez siete | ✅ | ✅ | ✅ | |
| Obrazovka nezhasína (keep awake) | ✅ | ✅ | ✅ | |
| Admin — in-app úprava textu kroku na karte | ✅ | ✅ | ✅ | |

---

## 4. Modlitby & Úmysly

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Modlitby — zoznam + detail | ✅ | ✅ | ✅ | SK, EN OK |
| Modlitby — audio nahrávka | ✅ | ✅ | ✅ | SK, EN OK |
| Úmysly — zoznam | ✅ | ✅ | ✅ | SK, EN OK |
| Úmysly — pridať nový (prihlásený) | ✅ | ✅ | ✅ | SK, EN OK |

---

## 5. Pobožnosti

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Ruženec — kategórie | ✅ | ✅ | ✅ | |
| Ruženec — desiatok + audio | ✅ | ✅ | ✅ | |
| Adorácia — zoznam + detail + audio | ✅ | ✅ | ✅ | |
| Krížové cesty — zoznam + detail + audio | ✅ | ✅ | ✅ | |
| Pobožnosti — FR jazyk (obsah/lang) | ✅ | ✅ | ✅ | |

---

## 6. Duchovné cvičenia

> Pozn.: DC sú **SK-only** (obsah aj reálne pobytové akcie na SK). V EN/ES/FR sa karta nezobrazí — očakávané, nie chyba.

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Zoznam cvičení | ✅ | ✅ | ✅ | len SK; light/dark OK |
| Detail cvičenia | ✅ | ✅ | ✅ | len SK; light/dark OK |
| Registrácia — formulár | ✅ | ✅ | ✅ | dark fix (izby, sumár, platby, tlačidlo) |
| Platba kartou (Mollie) — poplatok bez DPH | ✅ | ✅ | ✅ | |
| Platba bankovým prevodom (údaje na úhradu) | ✅ | ✅ | ✅ | |
| Návrat po platbe (deep link) → potvrdenie | ✅ | ✅ | ✅ | |

---

## 7. Aktuality (News)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Zoznam aktualít | ✅ | ✅ | ✅ | |
| Detail — obrázok + HTML text | ✅ | ✅ | ✅ | |
| **„Prečítať článok"** — audio prehrávač (ak má audio) | ✅ | ✅ | ✅ | |
| Komentáre — pridať | ✅ | ✅ | ✅ | |
| Komentáre — zmazať (admin) | ✅ | ✅ | ✅ | |
| Like / odlajkovanie | ✅ | ✅ | ✅ | |
| Vložený formulár (form embed) → otvorí sa | ✅ | ✅ | ✅ | |

---

## 8. Newsletter & Dokumenty

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Newsletter — zoznam + detail | ✅ | ✅ | ✅ | |
| Dokumenty — viditeľné len pre oprávnených (pastoral_council/admin) | ✅ | ✅ | ✅ | |
| Dokument — audiokniha (kapitoly, ďalšia kapitola) | ✅ | ✅ | ✅ | |

---

## 9. E-shop (len SK mutácia)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| E-shop dlaždica viditeľná len v SK | ✅ | ✅ | ✅ | |
| Zoznam produktov | ✅ | ✅ | ✅ | |
| Filter kategórií (chips) | ✅ | ✅ | ✅ | |
| Vyhľadávanie produktu | ✅ | ✅ | ✅ | |
| Detail — **slider viacerých fotiek** | ✅ | ✅ | ✅ | |
| Detail — DPH drobným písmom (s DPH / neuplatňuje sa) | ✅ | ✅ | ✅ | |
| Detail — poštovné a balné | ✅ | ✅ | ✅ | |
| Detail — „Skladom: X ks" / Vypredané | ✅ | ✅ | ✅ | |
| Množstvo (stepper, max sklad) | ✅ | ✅ | ✅ | |
| Do košíka / Kúpiť hneď | ✅ | ✅ | ✅ | |
| Košík — zmena množstva / odstránenie | ✅ | ✅ | ✅ | |
| Košík — rozpis (tovar + poštovné + spolu) | ☐ | ☐ | ☐ | |
| **Košík prežije reštart appky** | ✅ | ✅ | ✅ | |
| Checkout — validácia (PSČ 5 číslic, telefón, email) | ✅ | ✅ | ✅ | |
| Checkout — len Slovensko | ✅ | ✅ | ✅ | |
| Platba úspešná → potvrdenie + košík vyčistený | ✅ | ✅ | ✅ | |
| Platba **zrušená** v Mollie → „Platba neprebehla", košík zostane | ☐ | ☐ | ☐ | |
| Zatvorenie prehliadača → „Overiť platbu" funguje | ✅ | ✅ | ✅ | |
| Moje objednávky — stav, faktúra (PDF), tracking | ✅ | ✅ | ✅ | |

---

## 10. Podpora / Dar

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Donation — tiery (jednorazovo / mesačne) | ✅ | ✅ | ✅ | |
| „Náš príbeh" (rozbaľovacie) | ✅ | ✅ | ✅ | fix: cache, už nenačítava zakaždým |
| Platba daru (Mollie) → potvrdenie | ✅ | ✅ | ✅ | |
| Kampaň — vyzbieraná suma / počet podporovateľov | ✅ | ✅ | ✅ | |

---

## 11. Poznámky (Notes)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Zoznam poznámok (prihlásený) | ✅ | ✅ | ✅ | |
| Vytvoriť / upraviť / zmazať | ✅ | ✅ | ✅ | |

---

## 12. Notifikácie

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Povolenie notifikácií (prompt) | ✅ | ✅ | ✅ | |
| Push prijatý — appka v popredí | ✅ | ✅ | ✅ | |
| Push prijatý — appka na pozadí | ✅ | ✅ | ✅ | |
| Push prijatý — appka zatvorená (cold start) | ✅ | ✅ | ✅ | |
| Ťuk na push → otvorí správnu obrazovku | ✅ | ✅ | ✅ | |
| Obrazovka Notifikácie (in-app zoznam) | ✅ | ✅ | ✅ | |
| Nastavenia notifikácií — prepínače | ✅ | ✅ | ✅ | |

---

## 13. Profil & Nastavenia

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Profil — avatar, meno, supporter status | ✅ | ✅ | ✅ | |
| Profil — Moje objednávky (SK) | ✅ | ✅ | ✅ | |
| Profil — zmazať účet | ✅ | ✅ | ✅ | |
| Nastavenia — zmena jazyka (prejaví sa všade) | ✅ | ✅ | ✅ | |
| Nastavenia — font (Default/Serif/Mono) | ✅ | ✅ | ✅ | |
| Nastavenia — veľkosť písma | ✅ | ✅ | ✅ | |
| Nastavenia — výber biblie | ✅ | ✅ | ✅ | |
| Nastavenia — Lectio audio (dlhé/krátke) | ✅ | ✅ | ✅ | |
| Nastavenia — obrazovka nezhasína | ✅ | ✅ | ✅ | |

---

## 14. Audio (cez celú appku)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Prehrávanie na pozadí (appka v pozadí) | ✅ | ✅ | ✅ | |
| Ovládanie na zamknutej obrazovke (play/pause/seek) | ✅ | ✅ | ✅ | |
| Audio pokračuje pri prepnutí appky | ✅ | ✅ | ✅ | |
| Starší Android (8/9) — media player po zatvorení | — | — | ☐ | _známy problém_ |

---

## 15. Pomoc / Spätná väzba / O aplikácii / Súkromie

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Pomoc / Návody | ✅ | ✅ | ✅ | |
| Spätná väzba — odoslanie | ✅ | ✅ | ✅ | |
| O aplikácii (verzia, copyrighty biblií) | ✅ | ✅ | ✅ | |
| Súkromie / GDPR | ✅ | ✅ | ✅ | |

---

## 16. Projekty (Slovo bez hraníc — viditeľné pre všetkých)

| Funkcia | iOS | iPad | Android | Poznámka |
|---|---|---|---|---|
| Potulky Bibliou | ✅ | ✅ | ✅ | funding bar + Podporiť |
| Kurz Lectio | ✅ | ✅ | ✅ | funding bar + Podporiť |

---

## 🚦 Pred buildom releasu (14. 7.) — release gates

| Úloha | Hotové | Poznámka |
|---|---|---|
| `_kTestCheckout = false` (shop/checkout_screen.dart) | ✅ | vypnuté |
| `kForceOnboardingUpdate = false` (main.dart) | ✅ | vypnuté |
| `_kCoachAlwaysShow = false` (home_screen.dart) | ✅ | vypnuté |
| Vercel — `ALLOW_TEST_CHECKOUT` odstránený/false | ✅ | zmazané |
| SQL migrácie spustené v produkcii | ☐ | |
| `flutter analyze` 0 errors | ☐ | |
| Verzia/build number navýšený | ☐ | |
| Release build iOS (App Store) | ☐ | |
| Release build Android (Play) | ☐ | |
| App ikony + splash OK | ☐ | |

---

### 🐞 Súhrn chýb (doplň pri testovaní)

| # | Obrazovka | Platforma | Popis chyby | Stav |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |


# Test 11.2
Čo otestovať na Androide (Pixel 9a, Android 17)
1. Nové v tomto builde — najvyššia priorita
Toto ide do buildu prvýkrát, takže tu je najväčšia šanca, že sa niečo ukáže.

 ## Update screen — päť kariet v11.2 hore, pod oddeľovačom v11.1. Prejsť aj v EN/ES/FR (nemá tam byť prázdny riadok ani anglický text v slovenčine). Po zavretí sa už nemá zobraziť pri ďalšom štarte. 
 - android -  ok
 - ios - ok

 ## Lectio — HTML tagy — prejsť kroky (Lectio, Meditatio, Oratio, Contemplatio) vo všetkých štyroch jazykoch. Nikde <p>, <br>. Skontrolovať aj, či odstavce ostali oddelené — text sa čistil hromadne, tak sa oplatí pozrieť, či nie je zliaty do jedného bloku. Aj vo fullscreen čítačke.
  - android -  ok
 - ios - ok

 ## „Celé audio" pri ruženci, adorácii a krížovej ceste — prehrá sa celé, medzi sekciami je hudba, sedí dĺžka a posúvanie, funguje lock-screen a prehrávanie na pozadí. Mobilná časť sa testuje prvýkrát.
 - android -  ok
 - ios - ok

 ## Deviatnik — „Modliť sa znova" po dokončení; reštart s potvrdením počas rozmodleného; ťuknutie na dennú pripomienku otvorí konkrétny deviatnik, nie hlavnú stránku.
 - android -  ok
 - ios - ok 

 ## Inbox — popup po studenom štarte (nie po návrate z pozadia, tam sa zámerne nekontroluje). Plus admin compose v appke: profil → Inbox, vytvoriť a odoslať správu.

 - android -  ok
 - ios - ok

 - je tam problem prepol som na en verziu a aj tak mi ukazalo inbox aj ked je nastaveny len na en

2. FCM — celá cesta sa prepísala, treba ju prejsť
 ## Odhlásenie — odhlás sa a nechaj telefón chvíľu. Osobné notifikácie (napr. schválený úmysel) už chodiť nemajú, denné lectio áno. Toto je úplne nová cesta cez server.
 odhlasil som sa. na stavil som notifikacie - pri androide sa dalo zmenit ale ukazalo aj online nastavenia pri ios nie (vypisalo chyba nacitania)
 - spravne spravanie v nastaveniach - ma otvorit nastavenie notifikacii le ukazat len lokalne nie ktore sa nastavuju online 
  - android -  ok 
 - ios - ok 

 ## Prihlásenie — po prihlásení sa token priradí k účtu. V logu nemá byť žiadna chyba (predtým tam boli dve pri každom štarte).
  - android -  odhlasil som sa a prihlasil neviem ci to priradilo spravne neviem ale odoslal som notifikaciu na prihlaseneho uzivatela a prislo
 - ios - dhlasil som sa a prihlasil neviem ci to priradilo spravne neviem ale odoslal som notifikaciu na prihlaseneho uzivatela a prislo

 ## Čas denného lectia bez prihlásenia — Nastavenia → Notifikácie, nastav čas odhlásený. Predtým to ticho zlyhalo, teraz sa má uložiť aj zobraziť po návrate na obrazovku.
 odhlasil som sa. na stavil som notifikacie - pri androide sa dalo zmenit ale ukazalo aj online nastavenia pri ios nie (vypisalo chyba nacitania)
 - spravne spravanie v nastaveniach - ma otvorit nastavenie notifikacii le ukazat len lokalne nie ktore sa nastavuju online 
  - android -  
 - ios - 

 ## Zmena jazyka appky — token si má prebrať nový jazyk (denné lectio potom chodí v tom jazyku).
  - android -  
 - ios - ok

3. Android 17 — systémové veci

 ### Edge-to-edge sweep — spodné plávajúce prehrávače, rozbalené FAB menu, formuláre s klávesnicou, a najmä štyri obrazovky na svetlom pozadí: spovedná brána, čítačka lectio, dotazník lectio, onboarding (ikony v stavovom riadku majú byť čitateľné).

- android -  
- ios - ok

 ### Notifikácie a povolenia, deep linky, prehrávanie na pozadí po zamknutí.
- android -  
- ios - ok


4. Visí to z v11.1, stále neotestované
 ### E-shop — dobierka (cod_enabled musí byť zapnutý v admin Účtovníctve).
to bolo otestovane

 ### E-shop — objednávka pre firmu (IČO, DIČ, IČ DPH na faktúre).
to bolo otestovane



Keby čokoľvek spadlo alebo sa zaseklo, povedz — z Pixelu viem stiahnuť logcat a pozrieť sa na to hneď.
pri spovedi nefunguje ani na androide a ani na ios odomykanie tvarou/prstom
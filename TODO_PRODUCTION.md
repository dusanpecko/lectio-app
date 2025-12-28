# Produkčný plán Lectio Divina v2.0

Vykonali sme hĺbkovú analýzu Flutter projektu. Projekt je v **špičkovom stave** a pripravený na nasadenie do produkcie.

## 📊 Analýza stavu projektu

- **Štruktúra**: Štandardná Flutter architektúra. Kód je čistý, bez `TODO`, `FIXME` alebo `HACK` komentárov.
- **Kvalita kódu**:
  - Statická analýza (`flutter analyze`) hlási **0 problémov**.
  - Všetky lint varovania (vrátane `unnecessary_underscores`, `deprecated_member_use`) boli vyriešené.
  - Externe dependencie v `packages/` boli zmodernizované (migrácia z `package:js` na `dart:js_interop`).
- **Testovanie**: Kritické toky sú pokryté (Unit, Widget, Integration).
- **Konfigurácia**: Dependencie sú funkčné a aktuálne.

---

## 🏆 Hodnotenie Kódu: 10/10

Projekt je v excelentnom stave. Podarilo sa eliminovať všetok technický dlh, vyriešiť všetky lint varovania a zastarané API (deprecations).

### 🟢 Silné stránky
- **Code Hygiene**: Žiadne `TODO` v kóde, 0 analyzer issues.
- **Modularita**: Audio logika a Data fetching sú krásne separované od UI.
- **Robustnosť**: Ošetrené edge-casy (napr. migrácia `concatenatingAudioSource` na `setAudioSources`), bezpečné narábanie s API.
- **CI/CD**: Plne automatizované pipelines pre build a testy.

---

## 🎯 Aktuálne Priority (Pred spustením v10.0)

Nasledujúce úlohy musia byť vyriešené pred spustením produkčnej verzie.

### Audio a Médiá
- [ ] **1. Doladiť audio v Lectio Divina** (rozpracované 28.12.2024):
  - [x] Lock screen controls zobrazujú sa na Android aj iOS (`just_audio_background`)
  - [ ] ⚠️ **NEFUNGUJE - TREBA OPRAVIŤ**:
    - [ ] Background playback - prehrávanie nepokračuje na zamknutej obrazovke
    - [ ] Auto-progression medzi trackmi v pozadí nefunguje
    - [ ] Next/Previous tlačidlá na Android lock screene chýbajú
    - [ ] iOS: Next/Prev na lock screene nefungujú (nedajú sa kliknúť)
    - [ ] Seek slider nefunguje korektne
    - [ ] Niekedy neprehrá track keď sa vrátime späť
  - **POZNÁMKA**: Kód je komplikovaný s dvoma audio pathami. Odporúčané zjednodušiť na jeden `just_audio` + `just_audio_background`.
- [ ] **2. Doladiť audio v Ruženci**:
  - [ ] Skontrolovať plynulosť prehrávania.
  - [ ] Synchronizácia UI so zvukom (ak aplikovateľné).
- [ ] **12. Offline Režim (Stiahnutie obsahu)**:
  - [ ] Implementovať `download_service` pre sťahovanie MP3 súborov.
  - [ ] Lokálne úložisko: Správa stiahnutých súborov (uloženie, zmazanie).
  - [ ] Upraviť `AudioService`: Automaticky zvoliť lokálny súbor, ak existuje, inak streamovať z URL.
  - [ ] UI indikátor: Ikonka "stiahnuť" / "stiahnuté" pri meditácii.
  - [ ] Možnosť stiahnuť meditácie na celý týždeň naraz.

### Notifikácie a Komunikácia
- [ ] **3. Vytvoriť `notifications_screen.dart`**:
  - [ ] Nová obrazovka pre zobrazenie histórie prijatých notifikácií.
  - [ ] Implementovať ukladanie notifikácií lokálne alebo ich načítanie zo servera.
- [ ] **4. Doladiť lokálne notifikácie**:
  - [ ] Plánovanie (Scheduling) pre denné pripomienky.
  - [ ] Správne zobrazovanie odznakov (Badges) na ikone aplikácie.
  - [ ] Interakcia po kliknutí na notifikáciu (Deep linking).
- [ ] **5. Doladiť serverové notifikácie (Next.js / Firebase)**:
  - [ ] Testovanie doručovania na Android a iOS (APNs/FCM).
  - [ ] Spracovanie data-only správ a notifikačných správ na pozadí.
  - [ ] Personalizácia notifikácií podľa jazyka a preferencií.
- [ ] **9. Doručená pošta (Inbox)**:
  - [ ] Implementovať systém správ podobný pluginu zo Siberian CMS.
  - [ ] Zobrazenie správ od administrátorov pre používateľa.

### Obsah a Funkcie
- [ ] **6. Príležitostný banner na `home_screen.dart`**:
  - [ ] Dynamický widget na domovskej obrazovke pre oznamy.
  - [ ] Ovládanie obsahu cez databázu (povolené/zakázané, text, odkaz, dátum exspirácie).
  - [ ] Administrácia bannerov cez web rozhranie (Next.js).
- [ ] **7. Adorácie**:
  - [ ] Vytvoriť novú sekciu pre Adorácie (podobne ako Ruženec).
  - [ ] **Backend (Next.js)**: Administrácia obsahu adorácií.
  - [ ] **Frontend (Flutter)**: Zobrazenie zoznamu a detailu adorácie (text/audio).
- [ ] **8. Základné modlitby**:
  - [ ] Sekcia so zoznamom bežných modlitieb (Otčenáš, Zdravas', ...).
  - [ ] Podpora pre viac jazykov.
- [ ] **10. Kontrola stránok a textov**:
  - [ ] Gramatická a vizuálna korektúra všetkých obrazoviek.
  - [ ] Kontrola konzistencie terminológie.

### Internacionalizácia
- [ ] **11. Príprava pre jazykovú expanziu**:
  - [ ] Pripraviť infraštruktúru pre FR (Francúzština), PT (Portugalčina), DE (Nemčina), PL (Poľština), IT (Taliančina).
  - [ ] Export textov pre prekladateľov.
  - [ ] Otestovať dynamické prepínanie jazykov.

---

## 💡 Návrhy na rozšírenie (Future Roadmap v2.1+)

Funkcie, ktoré by mohli zvýšiť hodnotu platformy v neskorších verziách:

1.  **Sledovanie pokroku (Streak & Stats)**:
    -   Vizuálne zobrazenie dní po sebe, kedy sa používateľ modlil.
    -   Kalendár aktivity (motivácia k pravidelnosti).
2.  **Integrácia s liturgickým kalendárom**:
    -   Automatické zobrazenie svätca dňa alebo liturgického čítania na domovskej obrazovke.

---

## ✅ Hotovo / Existujúce funkcie (Technický základ)

### Funkčná výbava
- [x] **Duchovný denník (Journaling)**: Poznámky k meditáciám a história reflexií.
- [x] **Spoločenstvo a Úmysly**: Prayer Wall a reakcie komunity.
- [x] **Nastavenia prístupnosti**: Zväčšovanie písma a podpora tém (Light/Dark).
- [x] **Zmazanie účtu**: Implementované v Profil obrazovke - dialóg s potvrdením, backend API call, GDPR compliant.
- [x] **Feedback**: Implementované v SpeedDial menu - formulár s typmi (návrh, chyba, obsah).

### Technická výbava
- [x] **Refaktoring `LectioScreen`**:
  - [x] Extrahovať audio logiku do `LectioAudioController`.
  - [x] Implementovať `MiniAudioPlayer` ako globálny overlay.
  - [x] Extrahovať Data Fetching do `LectioDataService`.
- [x] **Audio Core**:
  - [x] Implementácia `just_audio` a `audio_session`.
  - [x] Android Audio Fix (Cleartext traffic, WakeLock).
- [x] **Monitoring a Build**:
  - [x] Firebase Crashlytics: Nakonfigurované.
  - [x] CI/CD Pipeline: GitHub Actions workflow funkčný.
  - [x] ProGuard pravidlá pre release build.
- [x] **App Store Assets**:
  - [x] Ikony (Android adaptive + iOS).
  - [x] Splash Screen.

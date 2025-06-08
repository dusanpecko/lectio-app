# 📖 Lectio Divina (Flutter App)

Mobilná aplikácia vytvorená vo Flutteri ako súčasť projektu *Lectio Divina*.

- 📲 Používa Flutter na frontend
- 🔐 Autentifikácia cez Supabase (email & heslo)
- 🗾 Obsah: denné čítania, zamyslenia, modlitby, Biblia a ďalšie moduly
- ☁️ Backend: Supabase (databáza, autentifikácia, API)

## 🔧 Požiadavky

- Flutter SDK (min. 3.19+)
- Dart
- Supabase CLI (voliteľne)
- `.env` súbor s API kľúčmi

## ⚙️ Konfigurácia `.env`

V koreňovom adresári vytvor súbor `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Lectio Divina - Flutter Aplikácia

## Úvod

Lectio Divina je moderná duchovná aplikácia zameraná na každodenné zamyslenia nad Božím slovom podľa tradičnej kresťanskej metódy Lectio Divina. Aplikácia ponúka možnosť čítať, meditovať, modliť sa a kontemplovať nad biblickými textami, viesť si vlastné poznámky, sledovať aktuálne správy a využívať podporu viacerých jazykov a tmavého/svetlého režimu.

Aplikácia je naprogramovaná v prostredí Flutter a je vhodná pre mobilné platformy (Android/iOS). Kód je členený podľa najlepších architektonických zásad s dôrazom na prehľadnosť, modularitu a škálovateľnosť.

## Adresárová štruktúra

```
/lib
  /screen      # Všetky obrazovky aplikácie (UI, navigácia, logika)
  /shared      # Zdieľané témy, farby, pozície a utility
  /widgets     # Znovupoužiteľné UI komponenty (karty, menu...)
  /services    # Servisy (napr. audio handler)
  main.dart    # Štartovací súbor aplikácie
/assets
  slide1.jpg, slide2.jpg, ...   # Obrázky pre slider, hlavičku, grafiku
  lectio_header.png             # Hlavný obrázok pre Lectio
  sk.json, en.json              # Lokalizačné súbory
/pubspec.yaml                   # Konfigurácia balíčkov a assetov
```

---

## Popis hlavných častí aplikácie

### 1. Hlavné obrazovky (`/screen`)

- **home_screen.dart** – Hlavná obrazovka s navigáciou na jednotlivé moduly (Lectio divina, Aktuality, Poznámky, Podpora atď.), carousel/slider obrázkov a prehľad dňa.
- **lectio_screen.dart** – Základná obrazovka Lectio divina s navigáciou cez kroky Lectio, Meditatio, Oratio, Contemplatio, Actio. Zobrazuje biblický text, modlitby, poznámky a možnosť prehrávať audio.
- **news_list_screen.dart** & **news_detail_screen.dart** – Zoznam aktualít a detail aktuality s komentármi, lajkami a dátumom publikácie.
- **notes_list_screen.dart** & **note_detail_screen.dart** – Vlastné poznámky používateľa, možnosť vytvárať, upravovať a mazať poznámky, filtrovať a vyhľadávať.
- **settings_screen.dart** – Nastavenia aplikácie (jazyk, téma, pozícia plávajúceho menu, výber biblického prekladu).
- **support_screen.dart** – Obrazovka podpory fungovania aplikácie, info a výzva na podporu.
- **auth_screen.dart** – Prihlásenie/registrácia/obnova hesla používateľa.
- **slider_detail_screen.dart** – Detail obrázka alebo modulu po kliknutí na slider v hlavnej obrazovke.

### 2. Widgety (`/widgets`)

- **app_card.dart** – Univerzálny widget pre zobrazovanie kariet (napr. články, poznámky, aktuality, atď.), možnosť zobraziť obrázok, nadpis, obsah a ďalšie elementy.
- **app_floating_menu.dart** – Plávajúce akčné menu s možnosťou voľby pozície na obrazovke (dole vľavo/vpravo/stred, hore...).

### 3. Zdieľané komponenty (`/shared`)

- **app_theme.dart** – Nastavenie tmavého/svetlého režimu, štýly, fonty, primaryColor atď.
- **app_colors.dart** – Centrálne definované farby používané v aplikácii.
- **fab_menu_position.dart** – Definícia a logika možných pozícií plávajúceho menu (FAB menu).

### 4. Servisy (`/services`)

- **audio_handler.dart** – Handler na prehrávanie audia, správa audio súborov pre Lectio divina (prehrávanie úvodnej modlitby, Lectio, Meditatio atď.), interakcia s UI.

### 5. Štartovací súbor (`main.dart`)

- Inicializácia aplikácie, nastavenie tém, jazykov, routovanie na úvodnú obrazovku, správa stavu aplikácie.

### 6. Assety a lokalizácia (`/assets`)

- **slide1.jpg, slide2.jpg, ...** – Obrázky použité v slideri a rôznych častiach aplikácie.
- **lectio_header.png** – Hlavný obrázok Lectio divina modulu.
- **sk.json, en.json** – Lokalizačné súbory, plná jazyková mutácia aplikácie (SK/EN).
- **pubspec.yaml** – Konfigurácia assetov, závislostí, popis aplikácie, platformy.

---

## Hlavná funkcionalita a logika aplikácie

### **Lectio divina**

- Štruktúra: Lectio (čítanie), Meditatio (rozjímanie), Oratio (modlitba), Contemplatio (kontemplácia), Actio (konanie), Silencio (ticho)
- Každý krok obsahuje vlastný obsah, otázky na zamyslenie, modlitby, prípadne audio sprievod.
- Užívatelia môžu prechádzať jednotlivými krokmi, prehrávať si úseky audia a robiť si poznámky.
- Základné texty a otázky sú lokalizované, audio prehrávač je súčasťou obrazovky.

### **Poznámky**

- Vlastný jednoduchý poznámkový systém.
- Možnosť vytvárať, upravovať, mazať a vyhľadávať poznámky.
- Poznámky môžu byť viazané na biblický text, deň alebo ľubovoľný obsah.
- Filtrovanie podľa názvu alebo obsahu, triedenie podľa dátumu vytvorenia.

### **Aktuality (News)**

- Zoznam najnovších aktualít a článkov.
- Každá aktualita má vlastný detail, možnosť komentovať a hodnotiť (like).
- Komentáre sú viazané na používateľa, môžu byť filtrované a radené podľa dátumu.
- Základné CRUD operácie pre komentáre (pridať, zmazať, zobraziť viac...)

### **Podpora**

- Sekcia pre podporu projektu.
- Prehľad možností podpory, informácie, odkazy na podporu a pod.

### **Nastavenia**

- Zmena jazyka aplikácie (SK/EN).
- Zmena témy (tmavý/svetlý režim).
- Výber polohy plávajúceho akčného menu (FAB menu: vľavo/vpravo/stred/hore...)
- Výber biblického prekladu pre čítanie.
- Správa účtu, možnosť vymazať účet, zmeniť heslo a pod.

### **Prihlásenie / Registrácia**

- Užívatelia môžu vytvoriť účet, prihlásiť sa alebo použiť aplikáciu ako hosť.
- Obnova hesla cez email.
- Správa používateľských údajov a ochrana osobných údajov.

### **Slider & obrázky**

- Úvodný carousel/slider na domovskej obrazovke s obrázkami a krátkym popisom.
- Po kliknutí detailný prehľad modulu/obrázka.

### **Audio prehrávač**

- Prehrávanie rôznych audio sekcií Lectio divina.
- Výber medzi úvodom, čítaním, meditáciou, modlitbou, kontempláciou, záverom...
- Ovládanie prehrávania priamo na obrazovke Lectio.

---

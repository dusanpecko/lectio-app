# 📱 Lectio Divina Mobile# 📖 Lectio Divina (Flutter App)



Flutter mobilná aplikácia pre iOS a Android.Mobilná aplikácia vytvorená vo Flutteri ako súčasť projektu *Lectio Divina*.



## 🚀 Spustenie- 📲 Používa Flutter na frontend

- 🔐 Autentifikácia cez Supabase (email & heslo)

```bash- 🗾 Obsah: denné čítania, zamyslenia, modlitby, Biblia a ďalšie moduly

# Inštalácia závislostí- ☁️ Backend: Supabase (databáza, autentifikácia, API)

flutter pub get

## 🔧 Požiadavky

# Spustenie v development mode

flutter run- Flutter SDK (min. 3.19+)

- Dart

# Build pre Android- Supabase CLI (voliteľne)

flutter build apk --release- `.env` súbor s API kľúčmi



# Build pre iOS## ⚙️ Konfigurácia `.env`

flutter build ios --release

```V koreňovom adresári vytvor súbor `.env`:



## 📁 Štruktúra```env

SUPABASE_URL=https://your-project.supabase.co

```SUPABASE_ANON_KEY=your-anon-key

mobile/```

├── lib/

│   ├── main.dart              # Entry point# Lectio Divina - Flutter Aplikácia

│   ├── screens/               # UI obrazovky

│   ├── services/              # Backend služby## Úvod

│   │   ├── fcm_service.dart   # Push notifications

│   │   └── notification_api.dartLectio Divina je moderná duchovná aplikácia zameraná na každodenné zamyslenia nad Božím slovom podľa tradičnej kresťanskej metódy Lectio Divina. Aplikácia ponúka možnosť čítať, meditovať, modliť sa a kontemplovať nad biblickými textami, viesť si vlastné poznámky, sledovať aktuálne správy a využívať podporu viacerých jazykov a tmavého/svetlého režimu.

│   ├── models/                # Data modely

│   ├── providers/             # State managementAplikácia je naprogramovaná v prostredí Flutter a je vhodná pre mobilné platformy (Android/iOS). Kód je členený podľa najlepších architektonických zásad s dôrazom na prehľadnosť, modularitu a škálovateľnosť.

│   └── utils/                 # Utility funkcie

│## Adresárová štruktúra

├── android/                   # Android konfigurácia

├── ios/                       # iOS konfigurácia```

├── assets/                    # Obrázky, fonty/lib

└── pubspec.yaml              # Dependencies  /screen      # Všetky obrazovky aplikácie (UI, navigácia, logika)

```  /shared      # Zdieľané témy, farby, pozície a utility

  /widgets     # Znovupoužiteľné UI komponenty (karty, menu...)

## 🔧 Konfigurácia  /services    # Servisy (napr. audio handler)

  main.dart    # Štartovací súbor aplikácie

### Environment Variables/assets

  slide1.jpg, slide2.jpg, ...   # Obrázky pre slider, hlavičku, grafiku

Vytvor `.env` súbor:  lectio_header.png             # Hlavný obrázok pre Lectio

  sk.json, en.json              # Lokalizačné súbory

```env/pubspec.yaml                   # Konfigurácia balíčkov a assetov

SUPABASE_URL=your_supabase_url```

SUPABASE_ANON_KEY=your_anon_key

API_BASE_URL=https://your-backend-url.com# Popis hlavných častí aplikácie

FLUTTER_MOCK_NOTIFICATIONS=false

```## 1. Hlavné obrazovky (`/screen`)

---

### Firebase Setup

- **home_screen.dart** – Hlavná obrazovka s navigáciou na jednotlivé moduly (Lectio divina, Aktuality, Poznámky, Podpora atď.), carousel/slider obrázkov a prehľad dňa.

1. **Android:** Stiahni `google-services.json` z Firebase Console- **lectio_screen.dart** – Základná obrazovka Lectio divina s navigáciou cez kroky Lectio, Meditatio, Oratio, Contemplatio, Actio. Zobrazuje biblický text, modlitby, poznámky a možnosť prehrávať audio.

   - Umiestni do: `android/app/google-services.json`- **news_list_screen.dart** & **news_detail_screen.dart** – Zoznam aktualít a detail aktuality s komentármi, lajkami a dátumom publikácie.

- **notes_list_screen.dart** & **note_detail_screen.dart** – Vlastné poznámky používateľa, možnosť vytvárať, upravovať a mazať poznámky, filtrovať a vyhľadávať.

2. **iOS:** Stiahni `GoogleService-Info.plist` z Firebase Console- **settings_screen.dart** – Nastavenia aplikácie (jazyk, téma, pozícia plávajúceho menu, výber biblického prekladu).

   - Umiestni do: `ios/Runner/GoogleService-Info.plist`- **support_screen.dart** – Obrazovka podpory fungovania aplikácie, info a výzva na podporu.

- **auth_screen.dart** – Prihlásenie/registrácia/obnova hesla používateľa.

## 🔗 Deep Linking- **slider_detail_screen.dart** – Detail obrázka alebo modulu po kliknutí na slider v hlavnej obrazovke.

---

Aplikácia podporuje deep linking z push notifikácií.## 2. Widgety (`/widgets`)



**Podporované obrazovky:**- **app_card.dart** – Univerzálny widget pre zobrazovanie kariet (napr. články, poznámky, aktuality, atď.), možnosť zobraziť obrázok, nadpis, obsah a ďalšie elementy.

- `home` - Domovská obrazovka- **app_floating_menu.dart** – Plávajúce akčné menu s možnosťou voľby pozície na obrazovke (dole vľavo/vpravo/stred, hore...).

- `lectio` - Lectio Divina

- `rosary` - Ruženec## 3. Zdieľané komponenty (`/shared`)

- `article` - Detail článku (vyžaduje `articleId`)

- `program` - Detail programu (vyžaduje `programId`)- **app_theme.dart** – Nastavenie tmavého/svetlého režimu, štýly, fonty, primaryColor atď.

- `calendar` - Kalendár- **app_colors.dart** – Centrálne definované farby používané v aplikácii.

- `profile` - Profil používateľa- **fab_menu_position.dart** – Definícia a logika možných pozícií plávajúceho menu (FAB menu).



**Príklad notifikácie s deep linking:**### 4. Servisy (`/services`)

```json

{- **audio_handler.dart** – Handler na prehrávanie audia, správa audio súborov pre Lectio divina (prehrávanie úvodnej modlitby, Lectio, Meditatio atď.), interakcia s UI.

  "screen": "article",

  "screen_params": "{\"articleId\":\"123\"}"## 5. Štartovací súbor (`main.dart`)

}

```- Inicializácia aplikácie, nastavenie tém, jazykov, routovanie na úvodnú obrazovku, správa stavu aplikácie.



📚 **Dokumentácia:** `../docs/DEEP_LINKING_FLUTTER_GUIDE.md`## 6. Assety a lokalizácia (`/assets`)



## 📦 Hlavné balíky- **slide1.jpg, slide2.jpg, ...** – Obrázky použité v slideri a rôznych častiach aplikácie.

- **lectio_header.png** – Hlavný obrázok Lectio divina modulu.

- `firebase_messaging` - Push notifications- **sk.json, en.json** – Lokalizačné súbory, plná jazyková mutácia aplikácie (SK/EN).

- `flutter_local_notifications` - Lokálne notifikácie- **pubspec.yaml** – Konfigurácia assetov, závislostí, popis aplikácie, platformy.

- `supabase_flutter` - Backend API

- `provider` - State management---

- `dio` - HTTP requesty

- `logger` - Logging# Hlavná funkcionalita a logika aplikácie



## 🧪 Testovanie## **Lectio divina**



```bash- Štruktúra: Lectio (čítanie), Meditatio (rozjímanie), Oratio (modlitba), Contemplatio (kontemplácia), Actio (konanie), Silencio (ticho)

# Unit testy- Každý krok obsahuje vlastný obsah, otázky na zamyslenie, modlitby, prípadne audio sprievod.

flutter test- Užívatelia môžu prechádzať jednotlivými krokmi, prehrávať si úseky audia a robiť si poznámky.

- Základné texty a otázky sú lokalizované, audio prehrávač je súčasťou obrazovky.

# Integration testy

flutter test integration_test/## **Poznámky**



# Test coverage- Vlastný jednoduchý poznámkový systém.

flutter test --coverage- Možnosť vytvárať, upravovať, mazať a vyhľadávať poznámky.

```- Poznámky môžu byť viazané na biblický text, deň alebo ľubovoľný obsah.

- Filtrovanie podľa názvu alebo obsahu, triedenie podľa dátumu vytvorenia.

## 🔒 Bezpečnosť

## **Aktuality (News)**

- Všetky API klúče v `.env` (nikdy commituj!)

- SSL pinning pre API requesty- Zoznam najnovších aktualít a článkov.

- Secure storage pre tokeny- Každá aktualita má vlastný detail, možnosť komentovať a hodnotiť (like).

- Certificate transparency- Komentáre sú viazané na používateľa, môžu byť filtrované a radené podľa dátumu.

- Základné CRUD operácie pre komentáre (pridať, zmazať, zobraziť viac...)

## 🚢 Deployment

## **Podpora**

### Google Play Store (Android)

- Sekcia pre podporu projektu.

```bash- Prehľad možností podpory, informácie, odkazy na podporu a pod.

# Build signed APK

flutter build appbundle --release## **Nastavenia**



# Upload na Play Console- Zmena jazyka aplikácie (SK/EN).

# https://play.google.com/console- Zmena témy (tmavý/svetlý režim).

```- Výber polohy plávajúceho akčného menu (FAB menu: vľavo/vpravo/stred/hore...)

- Výber biblického prekladu pre čítanie.

### Apple App Store (iOS)- Správa účtu, možnosť vymazať účet, zmeniť heslo a pod.



```bash## **Prihlásenie / Registrácia**

# Build IPA

flutter build ipa --release- Užívatelia môžu vytvoriť účet, prihlásiť sa alebo použiť aplikáciu ako hosť.

- Obnova hesla cez email.

# Upload cez Xcode alebo Transporter- Správa používateľských údajov a ochrana osobných údajov.

# https://appstoreconnect.apple.com

```## **Slider & obrázky**



## 🐛 Debugging- Úvodný carousel/slider na domovskej obrazovke s obrázkami a krátkym popisom.

- Po kliknutí detailný prehľad modulu/obrázka.

### Logs

```bash## **Audio prehrávač**

# Sledovanie logov

flutter logs- Prehrávanie rôznych audio sekcií Lectio divina.

- Výber medzi úvodom, čítaním, meditáciou, modlitbou, kontempláciou, záverom...

# Android Logcat- Ovládanie prehrávania priamo na obrazovke Lectio.

adb logcat | grep -i flutter



# iOS Console
xcrun simctl spawn booted log stream --predicate 'processImagePath endswith "Runner"'
```

### Common Issues

**Issue:** Build failed - dependencies missing
```bash
flutter clean
flutter pub get
flutter run
```

**Issue:** Firebase not working
- Skontroluj `google-services.json` / `GoogleService-Info.plist`
- Overiť Bundle ID / Package Name

**Issue:** Push notifications nedostávam
- Skontroluj FCM token v databáze
- Testuj cez Firebase Console
- Overiť permissions na zariadení

---

**Tech Stack:** Flutter 3.x, Dart 3.x, Firebase FCM, Supabase

**Posledná aktualizácia:** 12. október 2025

# 📴 Stratégia Offline/Online Režimu - Lectio Divina Mobile

## 🎯 Cieľ
Umožniť používateľom plnohodnotne používať aplikáciu aj bez internetového pripojenia, s automatickou synchronizáciou keď je pripojenie obnovené.

---

## ✅ Implementovaný Stav (Hybridná Stratégia)

### Implementované komponenty:

#### 1. ConnectivityService ✅
**Súbor**: `lib/services/connectivity_service.dart`
- Singleton služba pre detekciu online/offline stavu
- Stream pre reaktívne sledovanie zmien pripojenia
- Inicializovaná v `main.dart`

#### 2. LectioCacheService ✅
**Súbor**: `lib/services/lectio_cache_service.dart`
- SharedPreferences-based cache pre Lectio dáta
- Automatický cache dnes + zajtra (autoCache)
- Manuálny download na 7 dní (downloadLectioForDays)
- TTL 24h pre cache validitu
- Fallback na cache pri chybách

#### 3. OfflineBanner Widget ✅
**Súbor**: `lib/widgets/offline_banner.dart`
- Animovaný banner pri offline stave
- "Pripojenie obnovené" feedback
- NoOfflineDataScreen pre prípad bez cache

#### 4. LectioScreen Integrácia ✅
**Súbor**: `lib/screens/lectio_screen.dart`
- Download button v AppBar (ikona ⬇️)
- Cache-first logika pri načítavaní dát
- Progress indicator počas sťahovania
- Automatické ukladanie do cache

#### 5. Preklady ✅
**Súbory**: `assets/translations/sk.json`, `en.json`, `es.json`
- Kompletné preklady pre offline funkcie

---

## 📊 Analýza Súčasného Stavu

### Existujúce caching mechanizmy:
- **SharedPreferences**: Notifikácie, nastavenia, preferencie
- **CachedNetworkImage**: Obrázky (už implementované)
- **NotificationPreferencesCache**: TTL cache pre notifikácie (5 min)

### Chýbajúce:
- ❌ Detekcia stavu pripojenia
- ❌ Lokálna databáza pre offline dáta (SQLite/Drift)
- ❌ Sync queue pre offline akcie
- ❌ UI indikátor offline stavu
- ❌ Cache pre hlavný obsah (Lectio, News, Calendar)

---

## 🏗️ Architektúra Riešenia

### Fáza 1: Detekcia Konektivity (Základ)
**Priorita: VYSOKÁ** | **Odhadovaný čas: 2-3 hodiny**

```
┌─────────────────────────────────────────────────────────────┐
│                    ConnectivityService                       │
├─────────────────────────────────────────────────────────────┤
│  - Stream<ConnectivityStatus>                               │
│  - bool isOnline                                            │
│  - checkConnection()                                        │
│  - onConnectivityChanged callback                           │
└─────────────────────────────────────────────────────────────┘
```

**Balíček**: `connectivity_plus` ^6.0.0

### Fáza 2: Lokálna Databáza (Core)
**Priorita: VYSOKÁ** | **Odhadovaný čas: 4-6 hodín**

```
┌─────────────────────────────────────────────────────────────┐
│                      Drift Database                          │
├─────────────────────────────────────────────────────────────┤
│  Tables:                                                    │
│  - cached_lectio (hlava, datum, locale, content, synced_at) │
│  - cached_news (id, title, content, image_url, synced_at)   │
│  - cached_calendar (datum, locale, data, synced_at)         │
│  - sync_queue (id, action, table, data, created_at)         │
│  - cache_metadata (key, last_sync, ttl)                     │
└─────────────────────────────────────────────────────────────┘
```

**Balíček**: `drift` ^2.21.0 + `sqlite3_flutter_libs`

### Fáza 3: Repository Pattern
**Priorita: STREDNÁ** | **Odhadovaný čas: 4-6 hodín**

```
┌───────────────────────────────────────────────────────────────────────┐
│                          LectioRepository                              │
├───────────────────────────────────────────────────────────────────────┤
│  getLectioContent(date, locale):                                      │
│    1. Skontroluj online stav                                          │
│    2. Ak ONLINE:                                                      │
│       - Načítaj z Supabase                                            │
│       - Ulož do lokálnej DB                                           │
│       - Vráť dáta                                                     │
│    3. Ak OFFLINE:                                                     │
│       - Načítaj z lokálnej DB                                         │
│       - Ak nie je v cache, zobraz "Offline - dáta nie sú dostupné"    │
└───────────────────────────────────────────────────────────────────────┘
```

### Fáza 4: UI Indikátory
**Priorita: STREDNÁ** | **Odhadovaný čas: 2-3 hodiny**

- **Offline Banner**: Horný banner keď je offline
- **Sync Indicator**: Ikona synchronizácie pri obnovení pripojenia
- **Cache Age**: Zobrazenie ako staré sú dáta
- **Pull-to-Refresh**: Vylepšený s offline stavom

---

## 📋 Dáta na Cachovanie

### Kritické (Fáza 1):
| Dáta | Priorita | TTL | Poznámka |
|------|----------|-----|----------|
| Dnešné Lectio Divina | VYSOKÁ | 24h | Hlavná funkcia aplikácie |
| Liturgický kalendár (dnešok) | VYSOKÁ | 24h | Potrebné pre Lectio |
| Denný citát (Actio) | VYSOKÁ | 24h | Domovská obrazovka |

### Dôležité (Fáza 2):
| Dáta | Priorita | TTL | Poznámka |
|------|----------|-----|----------|
| Posledných 10 News | STREDNÁ | 6h | Offline čítanie |
| Ruženec (text modlitieb) | STREDNÁ | 7 dní | Statický obsah |
| Profilové dáta | STREDNÁ | 1h | Len read-only offline |

### Voliteľné (Fáza 3):
| Dáta | Priorita | TTL | Poznámka |
|------|----------|-----|----------|
| Liturgický kalendár (7 dní dopredu) | NÍZKA | 24h | Pre plánovanie |
| Lectio pre nasledujúce dni | NÍZKA | 24h | Premium feature? |
| Audio súbory | NÍZKA | Manuálne | Vyžaduje veľa miesta |

---

## 🔄 Sync Queue (Offline Akcie)

Akcie ktoré môžu byť vykonané offline a synchronizované neskôr:

```dart
enum SyncAction {
  updateNotificationPreferences,  // Zmena notifikácií
  markNewsAsRead,                 // Označenie prečítanej novinky
  saveNote,                       // Uloženie poznámky
  saveIntention,                  // Uloženie úmyslu
}
```

---

## 📁 Štruktúra Súborov

```
lib/
├── services/
│   └── connectivity_service.dart      # Nové - detekcia pripojenia
├── database/
│   ├── app_database.dart              # Nové - Drift databáza
│   ├── app_database.g.dart            # Generované
│   └── tables/                        # Nové - definície tabuliek
│       ├── cached_lectio_table.dart
│       ├── cached_news_table.dart
│       ├── cached_calendar_table.dart
│       └── sync_queue_table.dart
├── repositories/                       # Nové
│   ├── lectio_repository.dart
│   ├── news_repository.dart
│   └── calendar_repository.dart
└── widgets/
    └── offline_banner.dart            # Nové - UI indikátor
```

---

## 🚀 Implementačný Plán

### Krok 1: Connectivity Service (30 min)
1. Pridať `connectivity_plus` do pubspec.yaml
2. Vytvoriť `ConnectivityService` singleton
3. Integrovať do `main.dart`

### Krok 2: Offline Banner Widget (30 min)
1. Vytvoriť `OfflineBanner` widget
2. Pridať do hlavného Scaffold wrapperu
3. Testovať v airplane mode

### Krok 3: Drift Databáza (2-3 hodiny)
1. Pridať `drift` a súvisiace balíčky
2. Definovať tabuľky
3. Vytvoriť migrácie
4. Generovať kód (`dart run build_runner build`)

### Krok 4: Repository pre Lectio (2 hodiny)
1. Vytvoriť `LectioRepository`
2. Implementovať cache-first stratégiu
3. Refaktorovať `home_screen.dart` a `lectio_screen.dart`

### Krok 5: Repository pre News (1.5 hodiny)
1. Vytvoriť `NewsRepository`
2. Cachovať posledných 10 noviniek

### Krok 6: Sync Queue (2 hodiny)
1. Implementovať sync queue pre offline akcie
2. Background sync pri obnovení pripojenia

---

## ✅ Akceptačné Kritériá

### Základné:
- [ ] Aplikácia sa spustí bez internetu
- [ ] Offline banner sa zobrazí správne
- [ ] Dnešné Lectio je dostupné offline (ak bolo načítané online)
- [ ] Novinky sú čitateľné offline

### Rozšírené:
- [ ] Zmeny nastavení sa synchronizujú po obnovení pripojenia
- [ ] Používateľ vidí vek cached dát
- [ ] Pull-to-refresh funguje správne v oboch stavoch
- [ ] Žiadne crashes pri prepínaní online/offline

---

## 📦 Potrebné Balíčky

```yaml
dependencies:
  connectivity_plus: ^6.1.0      # Detekcia pripojenia
  drift: ^2.21.0                 # SQLite ORM
  sqlite3_flutter_libs: ^0.5.24  # SQLite knižnice
  path_provider: ^2.1.4          # Už máme
  path: ^1.9.0                   # Pre databázovú cestu

dev_dependencies:
  drift_dev: ^2.21.0             # Generátor kódu
  build_runner: ^2.4.0           # Už máme
```

---

## 🎯 Odporúčaný Postup

**Minimálny Viable Product (MVP):**
1. ✅ Connectivity Service + Offline Banner
2. ✅ Cache pre dnešné Lectio (SharedPreferences JSON)
3. ✅ Cache pre dnešný Actio/Citát

**Rozšírená verzia (v2):**
1. Drift databáza pre komplexnejšie caching
2. News caching
3. Sync queue

---

*Vytvorené: 12. januára 2026*
*Autor: Copilot*

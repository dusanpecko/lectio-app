# Flutter Environment Variables - Mock Mode

## 📋 Prehľad

Mock mode v `NotificationAPI` je teraz riadený cez **environment variable** namiesto hardcoded konstant.

---

## 🚀 Použitie

### Development (Mock Mode ON)

```bash
# Spustenie s mock dátami
flutter run --dart-define=USE_MOCK_DATA=true

# Debug build s mock dátami
flutter build apk --debug --dart-define=USE_MOCK_DATA=true

# iOS simulator s mock dátami
flutter run -d "iPhone 15 Pro" --dart-define=USE_MOCK_DATA=true
```

### Production (Mock Mode OFF - default)

```bash
# Normálne spustenie (mock mode vypnutý)
flutter run

# Release build (mock mode automaticky vypnutý)
flutter build apk --release
flutter build ios --release
```

---

## 💻 Implementácia

### Kód (notification_api.dart)

```dart
// PRED (hardcoded):
static const bool _useMockData = false;

// PO (environment variable):
static const bool _useMockData = bool.fromEnvironment(
  'USE_MOCK_DATA',
  defaultValue: false,
);
```

### Výhody:

1. ✅ **Žiadne code changes** pre prepínanie módu
2. ✅ **Production-safe** - defaultne vypnuté
3. ✅ **CI/CD friendly** - ľahko ovládateľné v pipelines
4. ✅ **Žiadne commity** s `_useMockData = true` omylom

---

## 🎯 Use Cases

### 1. Development bez backendového pripojenia

```bash
# Vývojár pracuje offline alebo backend nie je dostupný
flutter run --dart-define=USE_MOCK_DATA=true
```

**Správanie:**
- Všetky API calls vrátia mock dáta
- Žiadne reálne volania na Supabase
- Rýchle testovanie UI bez závislosti na backendu

### 2. UI Testing

```bash
# Testovanie UI s konzistentnými dátami
flutter test --dart-define=USE_MOCK_DATA=true
```

**Výhody:**
- Konzistentné testové dáta
- Žiadne flaky testy kvôli network issues
- Rýchlejšie testy (bez API delay)

### 3. Demo / Presentation

```bash
# Demo app pre stakeholderov bez reálnych dát
flutter run --release --dart-define=USE_MOCK_DATA=true
```

**Výhody:**
- Nepotrebuje Supabase credentials
- Funguje offline
- Kontrolované demo dáta

### 4. Production (automaticky)

```bash
# Normálny production build
flutter build apk --release
# Mock mode je automaticky false
```

---

## 📱 VS Code / Android Studio konfigurácia

### VS Code (launch.json)

Vytvor `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Production)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart"
    },
    {
      "name": "Flutter (Mock Mode)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=USE_MOCK_DATA=true"
      ]
    },
    {
      "name": "Flutter (Mock + Debug)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=USE_MOCK_DATA=true",
        "--dart-define=DEBUG_MODE=true"
      ]
    }
  ]
}
```

**Použitie:**
1. V VS Code: Run → Start Debugging (F5)
2. Vyber konfiguráciu z dropdown menu
3. Spusti aplikáciu

### Android Studio (Run Configuration)

1. Run → Edit Configurations
2. Pridaj novú Flutter configuration
3. V "Additional run args" pridaj:
   ```
   --dart-define=USE_MOCK_DATA=true
   ```
4. Save as "Flutter (Mock Mode)"

---

## 🧪 Verifikácia

### Ako overiť že mock mode funguje:

#### 1. Check logov po spustení:

```dart
// Mock mode ON - uvidíš:
🚧 Development Mode: Using mock notification data
🚧 Development Mode: Mock FCM token registration

// Mock mode OFF - uvidíš:
Fetching notification preferences from Supabase...
Registering FCM token in Supabase...
```

#### 2. V kóde (debug):

```dart
// Pridaj do main.dart pre verifikáciu:
void main() {
  const useMock = bool.fromEnvironment('USE_MOCK_DATA');
  print('🔍 Mock mode: $useMock');
  
  runApp(MyApp());
}
```

#### 3. Test v runtime:

```dart
// V notification_settings_screen.dart
@override
void initState() {
  super.initState();
  
  // Debug print
  const isMock = bool.fromEnvironment('USE_MOCK_DATA');
  _logger.i('📊 Loading notifications (mock: $isMock)');
  
  _initializeNotificationSettings();
}
```

---

## 📋 Mock Dáta

### Čo mock mode vracia:

#### Topics (8 kusov):
```dart
[
  NotificationTopic(
    id: 'mock-1',
    nameSk: 'Denné čítania',
    nameEn: 'Daily Readings',
    nameCs: 'Denní čtení',
    nameEs: 'Lecturas diarias',
    emoji: '📖',
    sortOrder: 1,
  ),
  // ... ďalších 7 topics
]
```

#### Preferences (2 enabled):
```dart
[
  NotificationPreference(
    topicId: 'mock-1',
    isEnabled: true,
  ),
  NotificationPreference(
    topicId: 'mock-2',
    isEnabled: true,
  ),
  // ... ostatné false
]
```

---

## 🔐 CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      # Test s mock dátami (rýchle)
      - name: Run tests with mock data
        run: |
          flutter test --dart-define=USE_MOCK_DATA=true
      
      # Build production (bez mock)
      - name: Build APK
        run: |
          flutter build apk --release
          # Mock mode je automaticky false
```

### GitLab CI Example

```yaml
stages:
  - test
  - build

test_mock:
  stage: test
  script:
    - flutter test --dart-define=USE_MOCK_DATA=true

build_production:
  stage: build
  script:
    - flutter build apk --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/
```

---

## ⚙️ Rozšírené environment variables

### Možné ďalšie variables:

```dart
// notification_api.dart
class NotificationAPI {
  // Mock mode
  static const bool _useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );
  
  // API timeout
  static const int _apiTimeout = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
  
  // Cache duration
  static const int _cacheDuration = int.fromEnvironment(
    'CACHE_DURATION_MINUTES',
    defaultValue: 5,
  );
  
  // Debug mode
  static const bool _debugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: false,
  );
}
```

### Použitie:

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=true \
  --dart-define=DEBUG_MODE=true \
  --dart-define=CACHE_DURATION_MINUTES=1 \
  --dart-define=API_TIMEOUT_SECONDS=60
```

---

## 🎯 Best Practices

### ✅ DO:

1. **Vždy používaj environment variables pre feature flags**
   ```dart
   static const bool _useMockData = bool.fromEnvironment('USE_MOCK_DATA');
   ```

2. **Nastav bezpečné default values**
   ```dart
   defaultValue: false, // Production-safe!
   ```

3. **Dokumentuj všetky environment variables**
   ```dart
   // Environment Variables:
   // - USE_MOCK_DATA: Enable mock data mode (default: false)
   ```

4. **Pridaj debug logging**
   ```dart
   _logger.i('🚧 Mock mode: $_useMockData');
   ```

### ❌ DON'T:

1. **Nepoužívaj hardcoded values**
   ```dart
   // ❌ BAD
   static const bool _useMockData = true;
   ```

2. **Nezabudni na default value**
   ```dart
   // ❌ BAD (null if not set)
   static const bool? _useMockData = bool.fromEnvironment('USE_MOCK_DATA');
   
   // ✅ GOOD
   static const bool _useMockData = bool.fromEnvironment(
     'USE_MOCK_DATA',
     defaultValue: false,
   );
   ```

3. **Nespoliehaj sa na mock mode v production**
   ```dart
   // ❌ BAD
   if (_useMockData) {
     return hardcodedData;
   }
   // No fallback - app crashes if API fails!
   
   // ✅ GOOD
   try {
     return await fetchFromAPI();
   } catch (e) {
     if (_useMockData) {
       return mockData;
     }
     throw e; // Let caller handle error
   }
   ```

---

## 📊 Porovnanie

| Aspekt | Hardcoded | Environment Variable |
|--------|-----------|---------------------|
| Prepínanie módu | ✏️ Zmena kódu | ✅ CLI parameter |
| Risk commitu mock=true | ⚠️ Vysoký | ✅ Žiadny |
| CI/CD integration | ❌ Zložité | ✅ Jednoduché |
| Production safety | ⚠️ Manuálne | ✅ Automatické |
| Flexibilita | ❌ Nízka | ✅ Vysoká |
| Git history | ❌ Znečistený | ✅ Čistý |

---

## 🎉 Záver

Environment variable prístup poskytuje:

- ✅ **Bezpečnosť** - production je default
- ✅ **Flexibilitu** - ľahké prepínanie bez code changes
- ✅ **CI/CD friendly** - ovládanie v pipelines
- ✅ **Čistý git** - žiadne mock=true commity
- ✅ **Developer friendly** - jednoduché použitie

**Hodnotenie: Production-ready! 🚀**

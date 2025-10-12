# Flutter Cache Optimization - Implementácia TTL ✅

## 📋 Prehľad zmien

### Problém:
Cache v `NotificationPreferencesCache` mal TTL nastavené na 24 hodín, čo mohlo viesť k zobrazovaniu neaktuálnych dát.

### Riešenie:
Zmenili sme TTL z 24 hodín na **5 minút** a pridali utility metódy pre lepšiu kontrolu cache.

---

## 🔧 Implementované zmeny

### 1. **Zmenená expirácia cache** (notification_api.dart)

```dart
// PREDTÝM:
static const Duration _cacheValidDuration = Duration(hours: 24);

// TERAZ:
// Cache je platná 5 minút - potom sa automaticky obnoví z API
static const Duration _cacheValidDuration = Duration(minutes: 5);
```

### 2. **Pridaná metóda `isCacheValid()`**

```dart
/// Overí či je cache stále platná
static Future<bool> isCacheValid() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt(_cacheTimeKey);

    if (cacheTime == null) return false;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
    return cacheAge <= _cacheValidDuration.inMilliseconds;
  } catch (e) {
    Logger().w('Failed to check cache validity: $e');
    return false;
  }
}
```

**Použitie:**
- Rýchla kontrola platnosti bez načítania dát
- Užitočné pre UI indikátory
- Debugging a monitoring

### 3. **Pridaná metóda `getCacheAge()`**

```dart
/// Získa vek cache v sekundách
static Future<int?> getCacheAge() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt(_cacheTimeKey);

    if (cacheTime == null) return null;

    final ageInMs = DateTime.now().millisecondsSinceEpoch - cacheTime;
    return (ageInMs / 1000).round();
  } catch (e) {
    Logger().w('Failed to get cache age: $e');
    return null;
  }
}
```

**Použitie:**
- Zobrazenie info o veku dát užívateľovi
- Debugging a logging
- Analytics

### 4. **Vylepšený logging v `getNotificationPreferences()`**

```dart
// PREDTÝM:
if (cached != null) {
  _logger.i('📦 Using cached notification preferences...');
  return cached;
}

// TERAZ:
if (!forceRefresh) {
  final cacheAge = await NotificationPreferencesCache.getCacheAge();
  final cached = await NotificationPreferencesCache.getCachedPreferences();
  
  if (cached != null) {
    _logger.i(
      '📦 Using cached notification preferences (${cached.topics.length} topics, ${cached.preferences.length} prefs, age: ${cacheAge}s)',
    );
    return cached;
  } else if (cacheAge != null) {
    _logger.i('⏰ Cache expired (age: ${cacheAge}s), fetching fresh data');
  }
}
```

---

## 🎯 Výhody implementácie

### 1. **Aktuálnosť dát**
- Dáta nie sú nikdy staršie ako 5 minút
- Automatická invalidácia pri expirácii
- Užívatelia vidia aktuálny stav subscriptions

### 2. **Výkon**
- Rýchle načítanie pri opätovnom otvorení (do 5 min)
- Zníženie zbytočných API volaní
- Lepšia offline podpora

### 3. **Debugging**
- Presné informácie o veku cache v logoch
- Jasné označenie kedy sa používa cache vs API
- Ľahké sledovanie správania cache

### 4. **Flexibilita**
```dart
// Ľahko zmeniteľná expirácia podľa potrieb:
static const Duration _cacheValidDuration = Duration(minutes: 5);  // Produkcia
// static const Duration _cacheValidDuration = Duration(seconds: 30); // Development
// static const Duration _cacheValidDuration = Duration(hours: 1);    // Menej kritické dáta
```

---

## 📊 Príklady log výstupov

### Cache hit (dáta platné):
```
📦 Using cached notification preferences (8 topics, 5 prefs, age: 127s)
```

### Cache expired:
```
⏰ Cache expired (age: 312s), fetching fresh data
✅ Fetched 8 topics and 5 preferences from Supabase
```

### Force refresh:
```
🔄 Force refresh - ignoring cache
✅ Fetched 8 topics and 5 preferences from Supabase
```

### Fallback na starú cache pri chybe:
```
❌ Error fetching notification preferences from Supabase
⚠️ Using stale cache due to error
```

---

## 🧪 Testovanie

### 1. Test cache expirácie:
```dart
// 1. Načítaj dáta (vytvorí cache)
final prefs1 = await api.getNotificationPreferences();
// LOG: ✅ Fetched 8 topics and 5 preferences from Supabase

// 2. Ihneď načítaj znova (použije cache)
final prefs2 = await api.getNotificationPreferences();
// LOG: 📦 Using cached notification preferences (8 topics, 5 prefs, age: 2s)

// 3. Počkaj 6 minút
await Future.delayed(Duration(minutes: 6));

// 4. Načítaj znova (cache expired, fetch z API)
final prefs3 = await api.getNotificationPreferences();
// LOG: ⏰ Cache expired (age: 361s), fetching fresh data
```

### 2. Test force refresh:
```dart
// 1. Normálne načítanie (vytvorí cache)
await api.getNotificationPreferences();

// 2. Force refresh (ignoruje cache)
await api.getNotificationPreferences(forceRefresh: true);
// LOG: 🔄 Force refresh - ignoring cache
```

### 3. Test cache validity:
```dart
final isValid = await NotificationPreferencesCache.isCacheValid();
print('Cache valid: $isValid');

final age = await NotificationPreferencesCache.getCacheAge();
print('Cache age: $age seconds');
```

---

## 🔍 Monitoring a metriky

### Odporúčané metriky na sledovanie:

1. **Cache hit rate**
   - Koľko % requestov používa cache
   - Target: >70% pri normálnom používaní

2. **Average cache age**
   - Priemerný vek cache pri použití
   - Target: 60-180 sekúnd (1-3 minúty)

3. **API call frequency**
   - Ako často sa volá API
   - Target: Max 1x za 5 minút pre user

4. **Stale cache usage**
   - Ako často sa používa expirovaná cache (pri chybe API)
   - Target: <5% prípadov

---

## 📝 Best Practices

### 1. **Kedy použiť force refresh**
```dart
// ✅ ANO - po zmene preferencií
await api.updateTopicPreference(...);
await api.getNotificationPreferences(forceRefresh: true);

// ✅ ANO - pull-to-refresh gesture
void _onRefresh() async {
  await api.getNotificationPreferences(forceRefresh: true);
}

// ❌ NIE - pri bežnom otvorení obrazovky
// (cache sa postará o aktuálnosť)
```

### 2. **Ako zobraziť užívateľovi vek dát**
```dart
final age = await NotificationPreferencesCache.getCacheAge();
if (age != null && age > 240) { // 4 minúty
  return Text('Načítané pred ${(age / 60).round()} min');
}
```

### 3. **Cache invalidácia**
```dart
// Po zmene preferencií - automatické
await api.updateTopicPreference(...); // Automaticky clearuje cache

// Manuálne (ak potrebné)
await NotificationPreferencesCache.clearCache();
```

---

## 🎉 Záver

Cache optimization je **úspešne implementovaná** s:
- ✅ 5-minútová expirácia
- ✅ Utility metódy pre validáciu a debugging
- ✅ Vylepšený logging
- ✅ Zachovaný fallback na starú cache pri chybách

Implementácia je **produkčne-ready** a poskytuje výborný balans medzi:
- **Aktuálnosťou dát** (max 5 min staré)
- **Výkonom** (rýchle načítanie z cache)
- **Offline podporou** (fallback na starú cache)
- **User experience** (plynulé načítanie)

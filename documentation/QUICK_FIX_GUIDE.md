# Quick Fix Guide - Notification Issues

## ✅ Práve Opravené

### 1. **Duplicate Key Error** - FIXED
**Problém**: `duplicate key value violates unique constraint "user_notification_preferences_user_id_topic_id_key"`

**Riešenie**: 
- Pridaný `onConflict: 'user_id,topic_id'` parameter do upsert calls
- Lokácia: `lib/services/notification_api.dart` lines 158, 207

```dart
await _supabase.from('user_notification_preferences').upsert(
  data,
  onConflict: 'user_id,topic_id', // ← FIX
);
```

### 2. **Cache Synchronizácia** - FIXED ✅
**Problém**: Zmeny z webu sa nezobrazujú v app, stále načítava staré dáta

**Riešenie**:
- ✅ Cache sa automaticky mazá po každom update
- ✅ Pull-to-refresh na notification settings screen
- ✅ Force refresh parameter v `getNotificationPreferences()`
- ✅ **VŽDY načíta fresh data pri otvorení settings screen**
- ✅ Po save automaticky refresh z databázy

**Stratégia**:
1. Pri otvorení screen → `forceRefresh: true` (vždy fresh z DB)
2. Pull-to-refresh → `forceRefresh: true` (bypass cache)
3. Po save → automatický refresh → vidíte aktuálne dáta
4. Cache sa používa len pri offline/error fallback

### 3. **Permission Denied na Users Table** - NEEDS DB MIGRATION
**Problém**: `PostgrestException: permission denied for table users`

**Riešenie**: Aplikujte SQL migráciu
```bash
# V Supabase SQL Editor spustite:
supabase/migrations/20251011_users_rls_policies.sql
```

---

## 🚀 Deploy Steps - DO THIS NOW

### Krok 1: Aplikujte Users RLS Policy (NOVÉ)

1. Otvorte **Supabase Dashboard** → SQL Editor
2. Skopírujte obsah: `supabase/migrations/20251011_users_rls_policies.sql`
3. Vložte a kliknite **"Run"**
4. Overte:
   ```sql
   SELECT tablename, policyname 
   FROM pg_policies 
   WHERE tablename = 'users';
   ```

### Krok 2: Hot Restart Flutter App

```bash
# V terminále kde beží `flutter run`:
# Stlačte: R (capital R) pre hot restart
```

alebo

```bash
flutter run
```

### Krok 3: Test v App

1. **Otvorte notification settings**
2. **Skúste toggle tému** - malo by fungovať bez errors
3. **Otvorte web** → upravte preferencie
4. **V app pull-to-refresh** (potiahnite nadol) - mali by sa zobraziť web zmeny

---

## 🔍 Ako Otestovať Synchronizáciu Web ↔ App

### Test 1: App → Web

1. **V App**: Profile → Notification Settings
2. Zapnite tému "Denné zamyslenia"
3. Kliknite Save (FAB button)
4. **V Web**: Otvorte notification settings
5. ✅ "Denné zamyslenia" by malo byť zapnuté

### Test 2: Web → App

1. **V Web**: Vypnite tému "Modlitby"
2. Uložte zmeny
3. **V App**: Otvorte notification settings
4. **Pull-to-refresh** (potiahnite obrazovku nadol)
5. ✅ "Modlitby" by malo byť vypnuté

---

## 🐛 Debugging Tipy

### Ak stále vidíte "duplicate key error":

**Check 1**: Overte že máte najnovší kód
```bash
# V notification_api.dart na riadku ~207:
.upsert(upsertData, onConflict: 'user_id,topic_id')
```

**Check 2**: Hot restart namiesto hot reload
```bash
# V terminále kde beží flutter run, stlačte:
R  # (capital R)
```

### Ak nevidíte zmeny z webu:

**Solution 1**: Zavrite a znova otvorte notification settings
- Screen sa VŽDY načíta fresh z databázy (už opravené)
- Nie je potrebný manuálny refresh

**Solution 2**: Pull-to-refresh (alternatíva)
- Otvorte notification settings
- Potiahnite obrazovku nadol
- Počkajte na loading

**Solution 3**: Vyčistite app cache (ak stále problém)
```bash
# iOS Simulator:
Device → Erase All Content and Settings

# Android Emulator:
Settings → Apps → Lectio Divina → Storage → Clear Data
```

### Ak vidíte "permission denied for table users":

1. **Aplikujte SQL migráciu** (viď Krok 1 vyššie)
2. Alebo dočasne vypnite RLS na users:
   ```sql
   ALTER TABLE users DISABLE ROW LEVEL SECURITY; -- ⚠️ LEN PRE TESTING!
   ```

### Ak vidíte "User not authenticated":

**Check**: Overte že ste prihlásení
```dart
// V debug console by ste mali vidieť:
final userId = _supabase.auth.currentUser?.id;
print('User ID: $userId'); // Nesmie byť null!
```

**Fix**: Odhláste sa a prihláste znova

---

## 📊 Expected Console Logs

### ✅ SUCCESS Logs:

```
💡 Fetching notification preferences from Supabase...
✅ Fetched 8 topics and 3 preferences from Supabase
💡 Bulk updating 1 topic preferences in Supabase
✅ Bulk updated 1 preferences successfully
```

### ❌ ERROR Logs (po fix by mali zmiznúť):

```
❌ Failed to bulk update preferences
⛔ duplicate key value violates unique constraint...  ← FIXED
⛔ permission denied for table users  ← NEEDS DB MIGRATION
```

---

## 📱 User Experience After Fix

### Before Fix:
- ❌ Toggle nefunguje
- ❌ Duplicate key error
- ❌ Zmeny z webu sa nezobrazia
- ❌ Permission denied errors

### After Fix:
- ✅ Toggle funguje smooth
- ✅ Žiadne errors
- ✅ Pull-to-refresh synchronizuje s webom
- ✅ Cache sa automaticky čistí po update
- ✅ Real-time updates medzi app/web

---

## 🎯 Checklist

- [ ] Aplikovaná users RLS migration
- [ ] Flutter app hot restart
- [ ] Test toggle témy - funguje bez errors
- [ ] Test web → app sync (pull-to-refresh)
- [ ] Test app → web sync (check web dashboard)
- [ ] Žiadne červené error logy v console
- [ ] Pull-to-refresh UI indicator sa zobrazuje

---

## 📞 Ak Niečo Stále Nefunguje

1. **Pošlite console logs** - celý výstup z `flutter run`
2. **Skúste mock mode**:
   ```dart
   // lib/services/notification_api.dart
   static const bool _useMockData = true; // ← Dočasne pre testing
   ```
3. **Check Supabase Dashboard**:
   - Table Editor → user_notification_preferences
   - Logs → Postgres Logs
   - Filters: errors, permissions

---

**Last Updated**: 11. október 2025, 22:10  
**Status**: 🔧 Ready to test after DB migration  
**Critical**: Apply `20251011_users_rls_policies.sql` FIRST!

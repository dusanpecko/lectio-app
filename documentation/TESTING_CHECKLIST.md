# Testing Checklist - Notification Settings

## ✅ Pred Testovaním

### 1. Aplikujte SQL Migrácie

**V Supabase SQL Editore spustite**:

1. ✅ `supabase/migrations/20251011_notification_rls_policies.sql`
2. ✅ `supabase/migrations/20251011_sample_notification_topics.sql`
3. ✅ `supabase/migrations/20251011_users_rls_policies.sql` (NOVÉ)

### 2. Hot Restart Flutter App

```bash
# V terminále kde beží `flutter run`:
R  # (capital R)
```

---

## 🧪 Test Cases

### Test 1: Základné Načítanie ✅

**Kroky**:
1. Otvorte app
2. Prihláste sa
3. Profile → Nastavenia notifikácií

**Expected**:
- ✅ Loading indicator sa zobrazí
- ✅ Načíta sa 8 tém z databázy
- ✅ Zobrazí sa 4 kategórie (Spiritual, Educational, News, Reminders)
- ✅ Emoji ikony sa zobrazujú správne
- ✅ Žiadne error logy v console

**Console Logs**:
```
💡 Fetching notification preferences from Supabase...
✅ Fetched 8 topics and 3 preferences from Supabase
```

---

### Test 2: Toggle Preference (App → Database) ✅

**Kroky**:
1. Na notification settings screen
2. Zapnite tému "Denné zamyslenia"
3. Kliknite FAB "Save changes"
4. Počkajte na success message

**Expected**:
- ✅ Switch sa zmení na ON
- ✅ FAB button sa zobrazí (pending changes)
- ✅ Po save: zelená snackbar "Preferences saved"
- ✅ FAB button zmizne (no pending changes)
- ✅ Switch ostane ON (data persisted)

**Console Logs**:
```
💡 Bulk updating 1 topic preferences in Supabase
✅ Bulk updated 1 preferences successfully
🔄 Force refreshing notification preferences from database
✅ Fetched 8 topics and 4 preferences from Supabase
```

**Verify v Supabase**:
- Table Editor → `user_notification_preferences`
- Malo by existovať: `user_id: YOUR_ID, topic_id: 1, is_enabled: true`

---

### Test 3: Web → App Sync ✅

**Kroky**:
1. **V Web Dashboard**: Zmeňte preference (napr. vypnite "Modlitby")
2. **V App**: Zavrite notification settings screen
3. **V App**: Znova otvorte notification settings

**Expected**:
- ✅ App načíta FRESH data z databázy (nie cache)
- ✅ "Modlitby" je vypnuté (syncované s webom)
- ✅ Console: `🔄 Force refresh - ignoring cache`

**Alternative Method** - Pull-to-Refresh:
1. Na notification settings screen
2. Potiahnite obrazovku nadol (pull-to-refresh)
3. Počkajte na loading

**Expected**:
- ✅ Refresh indicator sa zobrazí
- ✅ Data sa načítajú z DB
- ✅ Zmeny z webu sú viditeľné

---

### Test 4: Bulk Update ✅

**Kroky**:
1. Zmeňte viacero tém naraz (napr. 3 témy)
2. Kliknite Save

**Expected**:
- ✅ Všetky zmeny sa uložia naraz (bulk upsert)
- ✅ Success message sa zobrazí
- ✅ Po refresh sú všetky zmeny persisted

**Console Logs**:
```
💡 Bulk updating 3 topic preferences in Supabase
✅ Bulk updated 3 preferences successfully
```

---

### Test 5: Offline Mode ✅

**Kroky**:
1. Vypnite WiFi/Data
2. Otvorte notification settings
3. Skúste toggle preference

**Expected**:
- ✅ Načíta sa CACHED verzia (ak existuje)
- ✅ Console: `📦 Using cached notification preferences`
- ⚠️ Toggle nebude fungovať (no internet)
- ❌ Red snackbar: "Failed to save"

**Po obnovení internetu**:
1. Pull-to-refresh
2. ✅ Fresh data z DB

---

### Test 6: Error Handling ✅

**Scenario A: Permission Denied** (ak RLS nie je nastavené)
**Expected**:
- ❌ Error screen sa zobrazí
- 🔄 "Retry" button
- Console: `⚠️ Using stale cache due to error` (fallback)

**Scenario B: User Not Authenticated**
**Expected**:
- ❌ Error: "User not authenticated"
- 🔄 Automatický redirect na login

---

### Test 7: First Time User (No Preferences) ✅

**Kroky**:
1. Nový user sa prihlási
2. Otvorte notification settings

**Expected**:
- ✅ Všetky 8 tém sa zobrazia
- ✅ Všetky sú OFF (default state)
- ✅ User môže zapnúť témy a uložiť
- ✅ Po save sa vytvorí nový záznam v DB

**Console Logs**:
```
✅ Fetched 8 topics and 0 preferences from Supabase
```

---

### Test 8: Cache Invalidation After Update ✅

**Kroky**:
1. Toggle preference a save
2. Pozrite console logs

**Expected**:
- ✅ Po save: automatický `forceRefresh: true`
- ✅ Fresh data z DB (nie stará cache)
- ✅ Console: `🔄 Force refreshing notification preferences from database`

---

## 📊 Success Criteria

### ✅ All Tests Pass:
- [ ] Test 1: Základné načítanie - OK
- [ ] Test 2: Toggle preference - OK
- [ ] Test 3: Web → App sync - OK
- [ ] Test 4: Bulk update - OK
- [ ] Test 5: Offline mode - OK
- [ ] Test 6: Error handling - OK
- [ ] Test 7: First time user - OK
- [ ] Test 8: Cache invalidation - OK

### ✅ Console Logs Clean:
- [ ] Žiadne červené error logy (❌)
- [ ] Len success logy (✅) a info logy (💡)
- [ ] `forceRefresh` logika funguje

### ✅ Database Verification:
- [ ] `user_notification_preferences` obsahuje správne záznamy
- [ ] `is_enabled` hodnoty matchujú UI
- [ ] Žiadne duplicate záznamy (unique constraint funguje)

---

## 🐛 Known Issues (FIXED)

### ❌ Duplicate Key Error - FIXED ✅
- **Fix**: `onConflict: 'user_id,topic_id'` v upsert
- **Status**: Resolved

### ❌ Stará Cache Data - FIXED ✅
- **Fix**: `forceRefresh: true` pri otvorení screen
- **Status**: Resolved

### ❌ Permission Denied (users table) - FIXED ✅
- **Fix**: RLS policies migration
- **Status**: Requires DB migration

---

## 📱 User Flow

### Happy Path:
1. User otvorí notification settings → **fresh data z DB**
2. User zmení preferences → **pending changes** (visual feedback)
3. User klikne Save → **bulk update do DB**
4. **Auto-refresh** → aktuálne dáta z DB
5. Success message → UI aktuálny

### Edge Cases:
- **Offline**: Cached data + error na save
- **Permission denied**: Error screen + retry
- **No preferences**: Všetky témy OFF (default)
- **Web changes**: Pull-to-refresh alebo re-open screen

---

## 🚀 Production Readiness

### Before Release:
- [ ] All tests pass (8/8)
- [ ] All SQL migrations applied
- [ ] RLS policies verified
- [ ] Cache strategy tested (fresh on open, cache on error)
- [ ] Error handling tested (offline, permission denied)
- [ ] Web ↔ App sync verified

### Performance:
- [ ] Load time < 2 seconds
- [ ] Pull-to-refresh smooth
- [ ] No unnecessary DB queries (cache on error only)

---

**Last Updated**: 11. október 2025, 22:30  
**Status**: 🟢 READY FOR TESTING  
**Critical Path**: Apply users RLS migration → Hot restart → Test all 8 cases

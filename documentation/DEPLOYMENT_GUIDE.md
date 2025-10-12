# Deployment Guide - Notifikačný Systém

## 📋 Prehľad

Tento dokument popisuje **kompletný postup nasadenia** notifikačného systému po refaktore z WordPress API na priamu Supabase integráciu.

---

## 🎯 Čo Bolo Zmenené

### ❌ PRED Refaktorom
```
Flutter App → HTTP REST API → WordPress Backend → Database
              (404 error)      (neexistuje)
```

### ✅ PO Refaktore  
```
Flutter App → Supabase Client → PostgreSQL Database
              (priamo)           (už existuje)
```

### Hlavné Zmeny v Kóde

1. **`lib/services/notification_api.dart`**
   - ❌ Odstránené: `_httpClient`, HTTP requesty, `baseUrl`
   - ✅ Pridané: Priame Supabase query volania
   - ✅ Zmenené: `_useMockData = false` (production mode)

2. **`lib/models/notification_models.dart`**
   - ✅ Field mapping: `icon` → `emoji`, `display_order` → `sortOrder`
   - ✅ Null safety defaults pre všetky fieldy

3. **`lib/services/fcm_service.dart`**
   - ✅ Aktualizovaný `registerFCMToken()` signature
   - ✅ Nová signatúra: `(fcmToken, deviceType, appVersion, deviceId)`
   - ✅ Odstránený `dispose()` method

4. **Nové Migračné Súbory**
   - ✅ `supabase/migrations/20251011_notification_rls_policies.sql`
   - ✅ `supabase/migrations/20251011_sample_notification_topics.sql`

---

## 🚀 Deployment Steps

### Krok 1: Aplikovať RLS Polícy

1. **Otvorte Supabase Dashboard**:
   ```
   https://supabase.com/dashboard/project/YOUR_PROJECT
   ```

2. **Prejdite na SQL Editor**:
   - Ľavé menu → "SQL Editor"
   - Kliknite "New query"

3. **Skopírujte a spustite RLS migration**:
   - Otvorte súbor: `supabase/migrations/20251011_notification_rls_policies.sql`
   - Skopírujte celý obsah
   - Vložte do SQL Editora
   - Kliknite **"Run"**

4. **Overte výsledok**:
   ```sql
   -- Skontrolujte či RLS je povolené
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE schemaname = 'public' 
   AND tablename IN ('notification_topics', 'user_notification_preferences', 'user_fcm_tokens');
   
   -- Výsledok by mal byť:
   -- notification_topics          | true
   -- user_notification_preferences | true  
   -- user_fcm_tokens               | true
   ```

### Krok 2: Vložiť Sample Dáta

1. **V Supabase SQL Editore**:
   - Kliknite "New query"

2. **Skopírujte a spustite sample data migration**:
   - Otvorte súbor: `supabase/migrations/20251011_sample_notification_topics.sql`
   - Skopírujte celý obsah
   - Vložte do SQL Editora
   - Kliknite **"Run"**

3. **Overte výsledok**:
   ```sql
   -- Skontrolujte vložené témy
   SELECT id, name_sk, icon, category, is_active 
   FROM notification_topics 
   ORDER BY display_order;
   
   -- Malo by sa zobraziť 8 tém:
   -- 1 | Denné zamyslenia     | 🙏 | spiritual   | true
   -- 2 | Modlitby             | 🕊️ | spiritual   | true
   -- 3 | Biblické výklady     | 📖 | educational | true
   -- ... atď
   ```

### Krok 3: Overiť Flutter Aplikáciu

1. **Skontrolujte production mode**:
   ```dart
   // lib/services/notification_api.dart - riadok 24
   static const bool _useMockData = false;  // ← Musí byť FALSE
   ```

2. **Clean build** (voliteľné, ale odporúčané):
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Spustite aplikáciu**:
   ```bash
   flutter run
   ```

4. **Testujte Notification Settings**:
   - Prihláste sa do aplikácie
   - Prejdite na: **Profile → Nastavenia notifikácií**
   - Malo by sa načítať 8 tém z Supabase databázy
   - Skúste zapnúť/vypnúť tému → zmena by sa mala uložiť do DB

### Krok 4: Overiť Funkčnosť

#### ✅ Test Checklist

**UI Zobrazenie**:
- [ ] Načítajú sa všetky 4 kategórie (Spiritual, Educational, News, Reminders)
- [ ] Zobrazujú sa emoji ikony správne
- [ ] Slovenské a anglické názvy sa zobrazujú podľa jazyka
- [ ] Loading state sa zobrazí pri načítavaní

**CRUD Operácie**:
- [ ] Toggle jednotlivej témy sa uloží (update preference)
- [ ] FAB "Enable All" / "Disable All" funguje (bulk update)
- [ ] Po reštarte aplikácie sa preferencie načítajú z DB
- [ ] Chybové stavy sa správne zobrazujú (offline, auth error)

**FCM Token**:
- [ ] Pri prihlásení sa token zaregistruje do `user_fcm_tokens`
- [ ] Pri odhlásení sa token deaktivuje (`is_active = false`)
- [ ] V Supabase Table Editor skontrolujte `user_fcm_tokens` tabuľku

**RLS Security**:
- [ ] Používateľ vidí iba svoje preferencie
- [ ] Používateľ nemôže čítať cudzie preferencie iného usera
- [ ] Všetci používatelia vidia aktívne témy

---

## 🔍 Debugging

### Problém: Žiadne témy sa nezobrazujú

**Možné príčiny**:
1. Sample data neboli vložené do databázy
2. RLS policies blokujú SELECT queries
3. Používateľ nie je autentifikovaný

**Riešenie**:
```sql
-- Skontrolujte či existujú témy
SELECT COUNT(*) FROM notification_topics WHERE is_active = true;

-- Skontrolujte RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename = 'notification_topics';

-- Vypnite RLS dočasne pre debug (NESMIE byť v produkcii!)
ALTER TABLE notification_topics DISABLE ROW LEVEL SECURITY;
```

### Problém: Toggle nefunguje

**Možné príčiny**:
1. RLS policies pre `user_notification_preferences` blokujú INSERT/UPDATE
2. Nesprávny `user_id` (nematchuje autentifikovaného usera)

**Riešenie**:
```sql
-- Skontrolujte či existujú policies pre preferences
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'user_notification_preferences';

-- Manuálne vložte test preferenciu
INSERT INTO user_notification_preferences (user_id, topic_id, is_enabled)
VALUES ('YOUR_AUTH_USER_ID', 1, true);
```

### Problém: FCM token sa nezaregistruje

**Možné príčiny**:
1. RLS policies pre `user_fcm_tokens` blokujú INSERT
2. Firebase Messaging nie je správne inicializované

**Riešenie**:
```sql
-- Skontrolujte user_fcm_tokens tabuľku
SELECT user_id, device_type, is_active, created_at 
FROM user_fcm_tokens 
ORDER BY created_at DESC 
LIMIT 5;

-- Skontrolujte RLS policies
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'user_fcm_tokens';
```

### Ak Nič Nefunguje

**Emergency Rollback** - vráťte sa na mock mode:
```dart
// lib/services/notification_api.dart
static const bool _useMockData = true;  // ← Development mode
```

Spustite `flutter hot restart` a aplikácia pôjde na mock dáta.

---

## 📊 Monitoring a Logy

### Flutter Console Logy

**Očakávané logy pri production móde**:
```
💡 Fetching notification preferences from backend...
📡 Loaded 8 topics from Supabase
📋 Loaded 3 user preferences
✅ Successfully updated preference for topic 5
```

**Neočakávané logy (error)**:
```
❌ Failed to fetch notification preferences: ...
❌ Supabase error: JWT expired
❌ PostgresException: permission denied for table ...
```

### Supabase Dashboard Logs

1. Prejdite na: **Logs → Postgres Logs**
2. Filtrujte podľa:
   - `notification_topics`
   - `user_notification_preferences`
   - `user_fcm_tokens`

---

## 🎓 Best Practices

### Bezpečnosť

- ✅ **Vždy používajte RLS policies** - žiadny table bez RLS!
- ✅ **JWT token expiry** - Supabase auth tokeny expirujú po 1 hodine
- ✅ **User isolation** - každý user vidí iba svoje dáta
- ❌ **NIKDY nevypínajte RLS v produkcii**

### Performance

- ✅ **Indexy** - migration obsahuje indexy na `user_id`, `topic_id`
- ✅ **Caching** - preferences sú cachované 24 hodín
- ✅ **Batch updates** - použite `updateMultipleTopicPreferences()` namiesto loopu

### Maintenance

- ✅ **Backup databázy** - Supabase robí automatické backupy
- ✅ **Migration tracking** - uchovajte všetky `.sql` súbory v `supabase/migrations/`
- ✅ **Dokumentácia** - tento súbor a `DEVELOPMENT_MODE.md`

---

## 📱 Production Release Checklist

### Pred Releasom

- [ ] Všetky RLS policies sú aplikované
- [ ] Sample/production dáta sú v databáze
- [ ] `_useMockData = false` v kóde
- [ ] Flutter tests prechádzajú (`flutter test`)
- [ ] Manuálne testovanie všetkých feature
- [ ] Error handling je implementovaný všade

### Release Build

```bash
# iOS
flutter build ios --release
open ios/Runner.xcworkspace  # Pre App Store upload

# Android  
flutter build appbundle --release
# Upload .aab to Google Play Console
```

### Po Release

- [ ] Monitoring Supabase logovs
- [ ] Crashlytics monitoring (Firebase)
- [ ] User feedback tracking
- [ ] Performance metrics (load times)

---

## 🆘 Support

### Dokumentácia
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Supabase Plugin](https://pub.dev/packages/supabase_flutter)
- `DEVELOPMENT_MODE.md` - development vs production mode
- `FCM_IMPLEMENTATION.md` - Firebase Cloud Messaging setup

### Database Schema
Všetky tabuľky a ich stĺpce sú zdokumentované v:
- `supabase/migrations/20251011_notification_rls_policies.sql` (comments)

---

**Posledná aktualizácia**: 11. október 2025  
**Version**: 1.0  
**Status**: ✅ Production Ready

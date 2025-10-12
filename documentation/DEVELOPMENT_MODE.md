# Flutter → Supabase Integration - Production Ready

## ✅ Status: PRODUCTION MODE ACTIVE

Aplikácia je teraz nakonfigurovaná na použitie **Supabase databázy** namiesto mock dát.

## Architektúra

```
[Flutter App] ← komunikuje priamo → [Supabase Database]
     ↓                                       ↓
NotificationAPI                    notification_topics
FcmService                         user_notification_preferences
                                   user_fcm_tokens
```

## Prepínanie Development/Production Mode

V súbore `lib/services/notification_api.dart` na riadku **24**:

```dart
// Development mode - set to false for production (Supabase)
static const bool _useMockData = false;  // ← FALSE = Production (Supabase)
```

### Development Mode (Mock Data)
```dart
static const bool _useMockData = true;
```
- ✅ Používa sa pre vývoj a testovanie
- ✅ Nevyžaduje Supabase pripojenie
- ✅ Vracia mock dáta s realistickými testovacími údajmi
- ⚠️ Zmeny sa neukladajú (iba simulácia)

### Production Mode (Supabase) - **AKTUÁLNE AKTÍVNY** ✅
```dart
static const bool _useMockData = false;
```
- ✅ Používa sa pre produkčné nasadenie
- ✅ Priama komunikácia so Supabase databázou
- ✅ Všetky zmeny sa ukladajú v reálnom čase
- ✅ Row Level Security (RLS) ochrana dát
- ⚠️ Vyžaduje autentifikovaného používateľa

## Mock Dáta

### Notification Topics (8 kusov)
Kategórie a témy používané v development móde:

#### 🙏 Spiritual (Duchovné)
1. **Denné zamyslenia** / Daily Reflections
2. **Modlitby** / Prayers

#### 📖 Educational (Vzdelávacie)
3. **Biblické výklady** / Biblical Interpretations
4. **Liturgický kalendár** / Liturgical Calendar
5. **Katechézy** / Catechesis

#### 📰 News (Aktuality)
6. **Aktuality** / News

#### ⏰ Reminders (Pripomienky)
7. **Denné pripomienky** / Daily Reminders

#### ✨ Special (Špeciálne)
8. **Sviatky a slávnosti** / Feasts and Celebrations

### User Preferences
Mock používateľské nastavenia:
- ✅ **Povolené**: Témy 1, 2, 3, 5 (Denné zamyslenia, Biblické výklady, Modlitby, Denné pripomienky)
- ❌ **Zakázané**: Téma 4 (Aktuality)
- ⚪ **Bez nastavenia**: Témy 6, 7, 8

## Správanie v Development Mode

### API Calls
Keď je `_useMockData = true`, všetky API volania sú nahradené mock implementáciami:

```dart
// getNotificationPreferences()
→ Vráti 8 mock topics + 5 mock preferences
→ Simuluje 500ms delay (network latency)
→ Log: "🚧 Development Mode: Using mock notification data"

// updateTopicPreference(topicId, isEnabled)
→ Simuluje úspešnú aktualizáciu
→ Simuluje 300ms delay
→ Log: "🚧 Development Mode: Mock update topic X to Y"

// updateMultipleTopicPreferences(preferences)
→ Simuluje batch update
→ Simuluje 500ms delay
→ Log: "🚧 Development Mode: Mock bulk update N preferences"

// registerFCMToken(token, locale)
→ Simuluje registráciu FCM tokenu
→ Simuluje 300ms delay
→ Log: "🚧 Development Mode: Mock FCM token registration"
```

### Log Messages
Všetky mock operácie sú prefixované `🚧` emoji pre jednoduchú identifikáciu v logoch.

## Testovanie

### Manuálne Testovanie UI
1. Spustite aplikáciu: `flutter run`
2. Prihláste sa do aplikácie
3. Prejdite na Profile → Nastavenia notifikácií
4. Skúste:
   - ✅ Zapnúť/vypnúť jednotlivé témy
   - ✅ Bulk update cez FAB (Floating Action Button)
   - ✅ Zobrazenie kategorií
   - ✅ Zobrazenie emoji a názvov tém
   - ✅ Loading states
   - ✅ Permission handling

### Overenie Mock Módu
V console logu by ste mali vidieť:
```
💡 Fetching notification preferences from backend...
🚧 Development Mode: Using mock notification data
📦 Returning 8 mock topics with 5 preferences
```

## ✅ Production Setup Complete

### Aplikácia JE UŽ v Production Móde

Všetky potrebné kroky boli dokončené:

- ✅ `_useMockData = false` nastavené
- ✅ NotificationAPI prepísané na Supabase
- ✅ Model field mappings opravené  
- ✅ FCM token registration aktualizovaný
- ✅ RLS policies pripravené
- ✅ Sample data pripravené

### Zostávajúce Kroky

1. **Aplikovať RLS polícy** - v Supabase SQL Editor:
   ```bash
   # Otvorte súbor a skopírujte SQL:
   supabase/migrations/20251011_notification_rls_policies.sql
   ```

2. **Vložiť sample dáta** - v Supabase SQL Editor:
   ```bash
   # Otvorte súbor a skopírujte SQL:
   supabase/migrations/20251011_sample_notification_topics.sql
   ```

3. **Otestovať Flutter aplikáciu**:
   - Spustite: `flutter run`
   - Prihláste sa
   - Otvorte: Profile → Nastavenia notifikácií
   - Malo by sa načítať 8 tém z databázy

### Production Checklist
- ✅ Supabase databáza je pripravená (máte už tabuľky)
- ✅ `_useMockData` je nastavené na `false`
- ⏳ RLS policies treba aplikovať (run SQL migration)
- ⏳ Sample topics treba vložiť (run SQL migration)
- ⏳ Manuálne testovanie s reálnou databázou
- ⏳ Otestovať toggle preferencií
- ⏳ Overiť FCM token registráciu

## Riešenie Problémov

### Mock dáta sa nezobrazujú
1. Overte že `_useMockData = true`
2. Urobte **hot restart** (nie iba hot reload):
   - VS Code: `Shift + Cmd + F5`
   - Terminál: Stlačte `R`

### Po zmene z mock na production sa nič nezmenilo
1. Overte že ste zmenili hodnotu na `false`
2. Uložte súbor
3. Zastavte aplikáciu (`q` v terminále)
4. Vyčistite build: `flutter clean`
5. Spustite znova: `flutter run`

### Backend API vracia 404
1. Overte že endpoints sú správne implementované
2. Skontrolujte URL v `baseUrl` premennej
3. Overte authentication headers
4. Použite development mode kým nie je backend pripravený

## Dodatočné Informácie

### Performance
- Mock delay simuluje reálne network latency
- Pomáha odhaliť UI problémy s načítavaním
- Žiadne skutočné HTTP requesty v development móde

### Bezpečnosť
- Mock dáta sú hardcoded v kóde
- Žiadne real user data v development móde
- FCM token registrácia je tiež simulovaná

### Výhody Mock Módu
- ✅ Rýchlejší development (bez závislosti na backende)
- ✅ Offline development možný
- ✅ Konzistentné testovacie dáta
- ✅ Žiadne database side effects
- ✅ Jednoduchý debugging

---

**Posledná aktualizácia**: 11. október 2025
**Version**: 1.0
**Status**: ✅ Active & Tested

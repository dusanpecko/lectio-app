# iOS Background Audio - Manuálny Test Checklist

## Príprava
- [ ] Build aplikácie pre iOS zariadenie
- [ ] Nainštalovať aplikáciu na fyzické iOS zariadenie (simulátor nepodporuje background audio správne)
- [ ] Uistiť sa, že zariadenie má pripojenie na internet (pre streamovanie audio)

## Test 1: Základné prehrávanie v pozadí
1. [ ] Otvoriť aplikáciu
2. [ ] Prejsť na Lectio screen
3. [ ] Vybrať audio režim (short/long)
4. [ ] Spustiť prvý audio track
5. [ ] Počkať kým sa track začne prehrávať (aspoň 5 sekúnd)
6. [ ] **Zamknúť obrazovku** (stlačiť power button)
7. [ ] **Očakávaný výsledok**: Audio pokračuje v prehrávaní
8. [ ] Počkať kým sa track dokončí
9. [ ] **Očakávaný výsledok**: Automaticky začne interlude hudba
10. [ ] Počkať kým sa interlude dokončí
11. [ ] **Očakávaný výsledok**: Automaticky začne ďalší track
12. [ ] Odomknúť obrazovku
13. [ ] **Očakávaný výsledok**: UI zobrazuje správny track a pozíciu

## Test 2: Lock screen controls
1. [ ] Spustiť audio track
2. [ ] Zamknúť obrazovku
3. [ ] Otvoriť Control Center / Lock screen media controls
4. [ ] **Očakávaný výsledok**: Zobrazuje sa správny názov tracku
5. [ ] Stlačiť **Next** button
6. [ ] **Očakávaný výsledok**: Preskočí na ďalší track
7. [ ] Stlačiť **Previous** button
8. [ ] **Očakávaný výsledok**: Vráti sa na predchádzajúci track
9. [ ] Stlačiť **Pause** button
10. [ ] **Očakávaný výsledok**: Audio sa pozastaví
11. [ ] Stlačiť **Play** button
12. [ ] **Očakávaný výsledok**: Audio pokračuje

## Test 3: Prechod medzi aplikáciami
1. [ ] Spustiť audio track
2. [ ] Prejsť do inej aplikácie (napr. Safari)
3. [ ] **Očakávaný výsledok**: Audio pokračuje v prehrávaní
4. [ ] Počkať kým sa track dokončí
5. [ ] **Očakávaný výsledok**: Automaticky začne interlude a potom ďalší track
6. [ ] Vrátiť sa do Lectio Divina aplikácie
7. [ ] **Očakávaný výsledok**: UI zobrazuje správny stav

## Test 4: Celý playlist v pozadí
1. [ ] Otvoriť Lectio screen s viacerými trackmi (napr. 4-5 trackov)
2. [ ] Nastaviť audio režim na "short" alebo "long"
3. [ ] Spustiť prvý track
4. [ ] **Okamžite zamknúť obrazovku**
5. [ ] Nechať zariadenie zamknuté počas celého playlistu
6. [ ] **Očakávaný výsledok**: 
   - Všetky tracky sa prehrávajú v správnom poradí
   - Medzi trackami sa prehráva interlude hudba
   - Po poslednom tracku sa prehráva finálna meditačná hudba
7. [ ] Odomknúť obrazovku po skončení
8. [ ] **Očakávaný výsledok**: UI zobrazuje, že playlist sa dokončil

## Test 5: Prerušenie telefonátom
1. [ ] Spustiť audio track
2. [ ] Zamknúť obrazovku
3. [ ] Zavolať na zariadenie z iného telefónu
4. [ ] **Očakávaný výsledok**: Audio sa automaticky pozastaví
5. [ ] Prijať hovor
6. [ ] Ukončiť hovor
7. [ ] **Očakávaný výsledok**: Audio sa automaticky obnoví (alebo je možné ho obnoviť cez lock screen controls)

## Test 6: Režim Nerušiť (Do Not Disturb)
1. [ ] Aktivovať DND režim v aplikácii
2. [ ] Spustiť audio track
3. [ ] Zamknúť obrazovku
4. [ ] **Očakávaný výsledok**: 
   - Audio pokračuje v prehrávaní
   - Žiadne notifikácie neprerušujú prehrávanie
5. [ ] Deaktivovať DND režim
6. [ ] **Očakávaný výsledok**: Audio stále hrá

## Test 7: Nízka batéria
1. [ ] Počkať kým batéria klesne pod 20% (alebo použiť simuláciu)
2. [ ] Spustiť audio track
3. [ ] Zamknúť obrazovku
4. [ ] **Očakávaný výsledok**: Audio pokračuje aj pri nízkej batérii
5. [ ] Aktivovať Low Power Mode
6. [ ] **Očakávaný výsledok**: Audio stále pokračuje

## Známe problémy a očakávané správanie

### ✅ Správne správanie
- Audio pokračuje v pozadí aj pri zamknutej obrazovke
- Všetky tracky v playliste sa prehrávajú v správnom poradí
- Interlude hudba sa prehráva medzi trackami
- Lock screen controls fungujú správne
- UI sa aktualizuje po odomknutí obrazovky

### ⚠️ Možné problémy
- Ak je slabé internetové pripojenie, môže dôjsť k buffering pauzám
- Pri veľmi dlhých interlude môže iOS ukončiť session (riešené v kóde)
- Pri prerušení iným audio zdrojom (napr. Siri) sa môže audio pozastaviť

## Debugging
Ak audio prestane hrať v pozadí:
1. Skontrolovať Xcode console logs pre chybové hlášky
2. Hľadať "❌" alebo "⚠️" v logoch
3. Overiť, že `Info.plist` obsahuje `UIBackgroundModes` s `audio`
4. Overiť, že audio session je aktívna: hľadať "🎵 AudioSession configured for background playback"

## Reportovanie problémov
Pri reportovaní problému uveďte:
- [ ] iOS verzia
- [ ] Model zariadenia
- [ ] Ktorý test zlyhal
- [ ] Xcode console logs (ak sú dostupné)
- [ ] Kroky na reprodukciu

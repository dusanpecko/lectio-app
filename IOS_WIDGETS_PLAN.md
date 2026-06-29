# iOS Widgety — Actio & Audio Lectio (implementačný plán)

> ## ✅ STAV: Actio widget — kód hotový (Android + Dart), iOS čaká na Xcode kroky
> **Hotové v kóde:**
> - `home_widget: ^0.7.0` v pubspec
> - `lib/services/home_widget_service.dart` (init, pushActio, tap → dnešné Lectio)
> - `main.dart` (init v deferred services), `home_screen.dart` (push po `_loadActio`)
> - **Android (kompletné, build prešiel):** `ActioWidgetProvider.kt`, `res/layout/actio_widget.xml`,
>   `res/xml/actio_widget_info.xml`, `res/drawable/actio_widget_bg.xml`, farby light+dark,
>   receiver v `AndroidManifest.xml`
> - **iOS Swift:** `ios/LectioWidgets/ActioWidget.swift` (pripravený)
>
> **Zostáva (iOS, v Xcode UI — robíš ty):**
> 1. App Group `group.sk.dpapp.app.ios604688a889d93` (Developer portál + capability na Runner aj widget target)
> 2. `File → New → Target → Widget Extension` → obsah nahradiť `ActioWidget.swift`
> 3. Build number widgetu = Runner
>
> Deep-link tap: na iOS sa reuse existujúci scheme `lectio-divina://actio` (žiadna zmena Info.plist).
> Android tap ide cez explicitný intent `lectiowidget://actio`. Handler v Dart kontroluje `host == "actio"`.



> Stav projektu (overené): `home_widget` **nie je**, žiadny widget target neexistuje,
> ale **background audio beží** (`UIBackgroundModes: audio` + `just_audio_background`),
> deep-link scheme **`lectio-divina://`** + balík `app_links` už fungujú,
> bundle ID = `sk.dpapp.app.ios604688a889d93`.
> Actio/audio dáta sú v dennom Lectio (`actio_text`, `actio_audio`).

---

## 1. Cieľ a rozsah

| Widget | Čo robí | Fáza |
|---|---|---|
| **Actio** | Home-screen widget s dnešným actio textom (brand štýl), ťuknutie → dnešné Lectio | 1 |
| **Now Playing** | Lock screen / Control Center ovládanie audia | 2A (skoro hotové) |
| **Audio Lectio (home widget)** | „Dnešné Lectio audio" + ▶ tlačidlo, ktoré spustí prehrávanie | 2B |
| **Live Activity** (voliteľné) | Aktuálne hrajúci krok + play/pause v Dynamic Island | 3 |

---

## 2. Ako to funguje (architektúra)

iOS widget = **natívny WidgetKit / SwiftUI**, Flutter doň nekreslí. Most:

```
┌─────────────────┐   zapíše dáta    ┌──────────────────────┐
│  Flutter appka  │ ───────────────▶ │  App Group container │
│ (LectioData...) │  home_widget     │  (shared UserDefaults)│
└─────────────────┘                  └──────────┬───────────┘
        ▲                                        │ číta
        │ deep-link (lectio-divina://)           ▼
        │                              ┌──────────────────────┐
        └───────────── ťuk ─────────── │  WidgetKit extension │
                                       │   (SwiftUI views)    │
                                       └──────────────────────┘
```

- Flutter zapíše dnešné dáta cez `home_widget` do **App Group** `UserDefaults`.
- Natívny SwiftUI widget ich číta a vykresľuje.
- Refresh: WidgetKit **timeline** (denne o polnoci) + manuálny `updateWidget()` po načítaní Lectia.
- Ťuknutie → `lectio-divina://…` → spracuje existujúci `app_links` handler.

---

## 3. Spoločný setup (raz pre obe fázy)

### 3.1 Balíky (`pubspec.yaml`)
```yaml
dependencies:
  home_widget: ^0.7.0        # most Flutter ↔ WidgetKit
  # (workmanager: ^0.5.2)    # voliteľne pre denný background refresh
```

### 3.2 App Group (Apple Developer portal + Xcode)
1. **developer.apple.com → Identifiers → App Groups** → vytvoriť
   `group.sk.dpapp.app.ios604688a889d93`.
2. Priradiť App Group k **App ID** hlavnej appky aj k **App ID widget extensionu**.
3. V Xcode pridať capability **App Groups** na target *Runner* aj na *widget extension*
   (zaškrtnúť ten istý group).

### 3.3 Xcode — vytvoriť Widget Extension target
`File → New → Target… → Widget Extension` → názov napr. **`LectioWidgets`**,
zaškrtnúť *Include Live Activity* (ak ideme aj fáza 3), **odškrtnúť** *Include Configuration Intent*
(zatiaľ stačí statický). Vznikne bundle id `sk.dpapp.app.ios604688a889d93.LectioWidgets`.

> ⚠️ **Toto sa robí v Xcode UI — spravíš ty, ja ťa krok-za-krokom odnaviem.**
> Swift + Dart kód napíšem celý.

### 3.4 CocoaPods pozn.
Widget extension nech **nelinkuje** všetky Flutter pody (drž ho natívny a ľahký).
`home_widget` dokumentácia má sekciu pre Podfile — pridáme len čo treba.

---

## 4. FÁZA 1 — Actio widget

### 4.1 Dart — zapisovanie dát
Nová služba `lib/services/home_widget_service.dart`:
```dart
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const _group = 'group.sk.dpapp.app.ios604688a889d93';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_group);
  }

  /// Zavolať po načítaní dnešného Lectia.
  static Future<void> pushActio({
    required String text,
    String? reference,
    required DateTime date,
  }) async {
    await HomeWidget.saveWidgetData<String>('actio_text', text);
    await HomeWidget.saveWidgetData<String>('actio_ref', reference ?? '');
    await HomeWidget.saveWidgetData<String>(
        'actio_date', date.toIso8601String().substring(0, 10));
    await HomeWidget.updateWidget(
      name: 'ActioWidget',      // názov SwiftUI struct
      iOSName: 'ActioWidget',
    );
  }
}
```

**Kam ho volať:** v `lectio_screen.dart` / `home_screen.dart` po úspešnom načítaní
dnešného Lectia (keď `date == dnes`) → `HomeWidgetService.pushActio(...)`.
A `HomeWidgetService.init()` raz v `main.dart`.

### 4.2 Native — SwiftUI widget (`ios/LectioWidgets/ActioWidget.swift`)
```swift
import WidgetKit
import SwiftUI

struct ActioEntry: TimelineEntry {
  let date: Date
  let text: String
  let reference: String
}

struct ActioProvider: TimelineProvider {
  let group = "group.sk.dpapp.app.ios604688a889d93"

  func placeholder(in: Context) -> ActioEntry {
    ActioEntry(date: Date(), text: "…", reference: "")
  }
  func getSnapshot(in: Context, completion: @escaping (ActioEntry) -> Void) {
    completion(read())
  }
  func getTimeline(in: Context, completion: @escaping (Timeline<ActioEntry>) -> Void) {
    // refresh po najbližšej polnoci (nové actio)
    let next = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
    completion(Timeline(entries: [read()], policy: .after(next)))
  }
  func read() -> ActioEntry {
    let d = UserDefaults(suiteName: group)
    return ActioEntry(
      date: Date(),
      text: d?.string(forKey: "actio_text") ?? "Otvor dnešné Lectio",
      reference: d?.string(forKey: "actio_ref") ?? "")
  }
}

struct ActioWidgetView: View {
  var entry: ActioEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("ACTIO").font(.caption2).bold().tracking(1.5)
        .foregroundStyle(Color(red: 0.29, green: 0.31, blue: 0.52)) // #4A5085
      Text(entry.text).font(.system(.callout, design: .serif))
        .italic().lineLimit(4).minimumScaleFactor(0.7)
      if !entry.reference.isEmpty {
        Text(entry.reference).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(URL(string: "lectio-divina://lectio?date=today")) // ťuk → app
  }
}

@main
struct ActioWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ActioWidget", provider: ActioProvider()) { e in
      ActioWidgetView(entry: e)
    }
    .configurationDisplayName("Actio")
    .description("Dnešný duchovný impulz")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
```

### 4.3 Ťuknutie → otvorenie appky
`widgetURL` použije existujúci scheme `lectio-divina://`. Vo Flutteri to chytí
už použitý `app_links` (`uriLinkStream` / `getInitialLink`) — pridáme route
`lectio?date=today` → otvor dnešné Lectio.

### 4.4 Denný refresh (aby widget ukázal správny deň aj bez otvorenia appky)
- **Základ:** widget timeline `.after(polnoc)` ukáže prázdny/posledný stav, dáta sa
  obnovia keď používateľ otvorí appku (typické pre denné devocionály).
- **Lepšie (voliteľné):** `workmanager` / `BGAppRefreshTask` raz denne stiahne
  dnešné Lectio na pozadí a zavolá `pushActio()`.

---

## 5. FÁZA 2 — Audio Lectio

### 2A. Now Playing (lock screen + Control Center) — **takmer hotové**
Už máme `UIBackgroundModes: audio` + `just_audio_background` + `MediaItem(title, artUri)`.
Ostáva len **doladiť**:
- konzistentný `title`/`album` (napr. „Lectio • <dátum>", krok ako title),
- platný `artUri` (obrázok dňa / brand cover),
- otestovať play/pause/seek na lock screene.
→ Žiadny nový target, len úprava miest kde sa skladá `MediaItem`.

### 2B. Audio home-screen widget s ▶ tlačidlom (iOS 17+)
Widget na ploche **nestreamuje** zvuk — ukáže info + tlačidlo, ktoré spustí audio v appke.

**Dáta (Dart):** podobne ako actio — zapíš `lectio_audio_title`, `lectio_audio_url`,
`lectio_audio_duration` cez `home_widget`.

**Native (SwiftUI + App Intent):**
```swift
import AppIntents

struct PlayLectioIntent: AppIntent {
  static var title: LocalizedStringResource = "Prehrať dnešné Lectio"
  static var openAppWhenRun = true   // otvorí app, ktorá spustí audio
  func perform() async throws -> some IntentResult {
    // appka pri otvorení cez deep-link spustí prehrávanie
    return .result()
  }
}
```
Widget view má `Button(intent: PlayLectioIntent())` s ikonou ▶ + názvom.
- iOS 17+: tlačidlo priamo v widgete.
- iOS 16 fallback: `widgetURL(lectio-divina://play?target=today)` (ťuk kdekoľvek → app spustí audio).

**Pozn.:** „bezfokusové" spustenie audia z widgetu (`AudioPlaybackIntent`, bez otvorenia
appky) je možné, ale krehké — odporúčam `openAppWhenRun = true` (spoľahlivé).

### 2C. Live Activity (Dynamic Island) — voliteľné, fáza 3
- `NSSupportsLiveActivities = YES` v Info.plist, `ActivityAttributes` v extensione.
- Štart/update/stop z Dart cez balík `live_activities` (alebo natívny MethodChannel),
  napojené na `MediaPlayerBus` stavy (hrá/pauza/krok).
- Vyššia náročnosť, samostatná fáza.

---

## 6. Xcode UI kroky (robíš ty — odnaviem)
1. App Group v Developer portáli + capability na oba targety (§3.2).
2. `File → New → Target → Widget Extension` = `LectioWidgets` (§3.3).
3. Skopírovať `ActioWidget.swift` (a neskôr audio) do targetu.
4. Signing: widget extension dostane vlastný provisioning profil (automatic signing
   to zvládne, ak je App ID + App Group správne).
5. Build na reálnom zariadení (widgety sa dobre testujú na zariadení, nie vždy v simulátore).

---

## 7. Signing / App Store Connect
- Nový **App ID** pre widget extension (`…​.LectioWidgets`) — pri automatic signing
  Xcode väčšinou vytvorí sám; App Group treba mať na oboch.
- V App Store Connect žiadny extra krok navyše okrem nového buildu (extension ide
  v rámci appky).
- Pozor na verziu/build number — extension musí mať **rovnaké** `CFBundleShortVersionString`
  a `CFBundleVersion` ako Runner, inak App Store upload zlyhá.

---

## 8. Testovanie (checklist)
- [ ] Actio widget ukáže dnešný text po otvorení appky.
- [ ] Po polnoci / ďalší deň ukáže nové actio (po otvorení appky / background refresh).
- [ ] Ťuk na Actio widget otvorí dnešné Lectio.
- [ ] Now Playing na lock screene: play/pause/seek + správny názov a obrázok.
- [ ] Audio widget ▶ spustí prehrávanie dnešného Lectia.
- [ ] iOS 16 fallback (ťuk namiesto tlačidla) funguje.
- [ ] Widgety v light/dark + small/medium veľkosti.
- [ ] Build number Runner == LectioWidgets (upload prejde).

---

## 9. Riziká / gotchas
- **Widget refresh budget**: WidgetKit limituje reloady (~40–70/deň) → dizajn na denný
  refresh, nie real-time.
- **App Group musí sedieť** na oboch targetoch, inak widget číta prázdno.
- **iOS 17** pre interaktívne tlačidlá; pre staršie fallback cez `widgetURL`.
- **Bundle id `sk.dpapp.app…`** vyzerá ako z builder služby (dpapp) — ak je iOS projekt
  spravovaný externe, over, že pridanie natívneho targetu neprepíše ich generátor.
- **Verzia extensionu** musí kopírovať Runner (CI/build).
- Existujúce SPM warningy (sign_in_with_apple…) s tým nesúvisia.

---

## 10. Odhad & fázovanie
| Fáza | Obsah | Náročnosť | Odporúčanie |
|---|---|---|---|
| Setup | App Group + target + home_widget | 0.5 dňa | nutné raz |
| **1 — Actio** | widget + dataflow + tap | ~1–1.5 dňa | **stíhateľné do v11** |
| **2A — Now Playing** | doladenie MediaItem | ~0.5 dňa | do v11 |
| 2B — Audio widget ▶ | App Intent + dataflow | ~1–1.5 dňa | v11.x |
| 3 — Live Activity | ActivityKit | ~2+ dni | v12 |

**Odporúčaný rez pre 14.7:** Setup + Fáza 1 (Actio) + 2A (Now Playing polish).
Audio home widget (2B) a Live Activity (3) ako follow-up po release.

---

## 11. Android (mimo rozsahu, na neskôr)
`home_widget` podporuje aj Android (RemoteViews / Glance). Actio widget by sa dal
zrkadliť s tým istým Dart dataflowom — riešiť samostatne po iOS.

# Oprava iOS Background Audio Playback

## Problém
Keď sa obrazovka zamkne a aplikácia prejde do pozadia, audio prehrávač prehráva len aktuálnu stopu a potom sa vypne. Po otvorení aplikácie pokračuje prehrávanie normálne.

## Príčina
iOS pozastavuje aplikácie v pozadí a ukončuje audio session po dokončení aktuálnej stopy, ak nie je správne nastavená audio session s parametrami pre background playback.

Hlavné problémy:
1. **Nesprávna konfigurácia audio session** - používala sa základná `AudioSessionConfiguration.music()` bez špecifických iOS parametrov
2. **Audio session sa neobnovovala** pri prechode medzi trackami a interlude
3. **Chýbalo explicitné nastavenie `setActive(true)`** s iOS parametrami pri každom prechode medzi trackami

## Riešenie

### 1. Vylepšená konfigurácia audio session (`initialize()`)
```dart
await session.configure(
  const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
    avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: true,
  ),
);

// KRITICKÉ: Udržuj session aktívnu
await session.setActive(
  true,
  avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
);
```

### 2. Reaktivácia audio session pri každom prechode
Pridané volanie `session.setActive(true)` v:
- `playTrackByIndex()` - pred prehratím tracku
- `_playInterlude()` - pred prehratím interlude
- `_restorePlaylistAndPlayTrack()` - pri návrate z interlude na playlist

### 3. Správne ukončenie audio session
```dart
@override
void dispose() async {
  try {
    final session = await AudioSession.instance;
    await session.setActive(false);
  } catch (e) {
    debugPrint('⚠️ Error deactivating audio session: $e');
  }
  _player.dispose();
  super.dispose();
}
```

## Kľúčové iOS parametre

### `AVAudioSessionCategory.playback`
- Umožňuje prehrávanie audio aj keď je zariadenie v tichom režime
- Podporuje background playback

### `AVAudioSessionMode.spokenAudio`
- Optimalizované pre hovorené slovo (Lectio Divina)
- Lepšia kvalita pre reč vs. hudbu

### `AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation`
- Upozorní ostatné aplikácie, keď sa audio session deaktivuje
- Umožňuje plynulý prechod medzi aplikáciami

## Testovanie

1. Spustiť aplikáciu
2. Otvoriť Lectio screen
3. Spustiť audio prehrávač
4. Zamknúť obrazovku
5. **Očakávaný výsledok**: Audio pokračuje v prehrávaní všetkých trackov vrátane interlude
6. Otvoriť aplikáciu - audio stále hrá správny track

## Súvisiace súbory
- `/Users/dusanpecko/lectiodivina/mobile/lib/services/lectio_audio_player.dart`
- `/Users/dusanpecko/lectiodivina/mobile/ios/Runner/Info.plist` (už obsahuje `UIBackgroundModes` s `audio`)

## Poznámky
- iOS vyžaduje `UIBackgroundModes` s `audio` v `Info.plist` (už nastavené)
- Audio session musí byť aktívna počas celého playbacku
- Pri každom prechode medzi trackami je potrebné reaktivovať session

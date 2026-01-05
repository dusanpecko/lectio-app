# iOS Lock Screen Controls - Testing Guide

## ⚠️ IMPORTANT: Physical Device Required

**Lock screen controls DO NOT work in iOS Simulator!**

You MUST test on a **physical iOS device** to see lock screen controls.

## Testing Steps

### 1. Build and Install on Physical Device

```bash
cd mobile
flutter run --release
```

Or use Xcode to build and install on your device.

### 2. Test Lock Screen Controls

1. **Start audio playback** in the Lectio screen
2. **Lock the device** (press power button)
3. **Wake the lock screen** (press power button again, but don't unlock)
4. **Check for media controls** on the lock screen

You should see:
- ✅ Track title ("Katolícky preklad (SSV)", "Lectio", etc.)
- ✅ Artist ("Lectio Divina")
- ✅ Album art (if available)
- ✅ Play/Pause button
- ✅ Next/Previous track buttons
- ✅ Playback progress bar

### 3. Test Control Center

1. **Swipe down from top-right** (on iPhone X and later) or **swipe up from bottom** (on older iPhones)
2. **Check for media controls** in Control Center

### 4. Test Background Playback

1. **Start audio playback**
2. **Go to home screen** (swipe up or press home button)
3. **Audio should continue playing**
4. **Open another app**
5. **Audio should still play**
6. **Lock the device**
7. **Audio should continue playing**

## Expected Behavior

### ✅ What Should Work

- **Background playback**: Audio continues when app is backgrounded
- **Lock screen controls**: Media controls visible on lock screen
- **Control Center**: Media controls visible in Control Center
- **Automatic track progression**: Tracks play automatically with interlude between them
- **Interlude playback**: Short meditation music plays between tracks
- **All buttons work**: Play/Pause, Next, Previous, Seek

### ❌ What Won't Work in Simulator

- Lock screen controls (iOS limitation)
- Some background audio behaviors may differ

## Troubleshooting

### Lock Screen Controls Not Showing

1. **Check device**: Are you testing on a physical device?
2. **Check audio session**: Is audio actually playing?
3. **Check logs**: Look for `JustAudioBackground initialized` in console
4. **Restart app**: Sometimes iOS needs a fresh start

### Background Audio Stops

1. **Check battery saver**: Disable Low Power Mode
2. **Check app permissions**: Ensure audio permissions are granted
3. **Check logs**: Look for errors in Xcode console

## Technical Details

### Audio Session Configuration

```dart
avAudioSessionCategory: AVAudioSessionCategory.playback
avAudioSessionMode: AVAudioSessionMode.defaultMode
avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers
```

### Background Modes

In `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### JustAudioBackground Initialization

In `main.dart`:
```dart
await JustAudioBackground.init(
  androidNotificationChannelId: 'sk.lectio.divina.audio',
  androidNotificationChannelName: 'Lectio Divina Audio',
  androidNotificationOngoing: false,
  androidShowNotificationBadge: true,
  androidStopForegroundOnPause: false,
  notificationColor: const Color(0xFF8B5C2A),
  preloadArtwork: true,
);
```

## Known Issues

1. **iOS Simulator**: Lock screen controls don't work (iOS limitation)
2. **First launch**: Sometimes requires app restart to show controls
3. **Interlude transitions**: May briefly show wrong track info during transition

## Success Criteria

- ✅ Audio plays in background
- ✅ Lock screen shows media controls (on physical device)
- ✅ All buttons work (Play/Pause, Next, Previous)
- ✅ Interlude plays between tracks
- ✅ Automatic track progression works
- ✅ Seek bar works

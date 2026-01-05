# iOS Lock Screen Controls - Troubleshooting

## Current Status

✅ **Working**:
- Background playback
- Automatic track progression  
- Interlude between tracks
- All player controls (Play/Pause/Seek/Next/Previous)

❌ **Not Working**:
- Control Center media controls
- Lock screen media controls

## Root Cause Analysis

The issue is that `just_audio_background` is not properly setting up `MPNowPlayingInfoCenter` on iOS.

### Possible Causes

1. **`ConcatenatingAudioSource` incompatibility**: `just_audio_background` may not work well with `ConcatenatingAudioSource`
2. **Audio session not activated for remote controls**: iOS may not be receiving remote control events
3. **MediaItem not being set**: The `tag: MediaItem(...)` may not be propagating to iOS

## Quick Test

Try this to verify if the issue is with `just_audio_background`:

1. **Restart the app** completely (force quit and relaunch)
2. **Play audio**
3. **Check Control Center** immediately after audio starts
4. **Check lock screen** after locking device

If still not working, the issue is likely with how we're using `just_audio_background` with `ConcatenatingAudioSource`.

## Alternative Solution

If `just_audio_background` doesn't work with our setup, we have two options:

### Option 1: Use `audio_service` directly

Instead of `just_audio_background`, use `audio_service` package directly and manually set up `MPNowPlayingInfoCenter`.

**Pros**:
- Full control over Now Playing info
- Works reliably with any audio source

**Cons**:
- More code to write
- More complex setup

### Option 2: Switch from `ConcatenatingAudioSource` to single tracks

Play each track individually using `setAudioSource()` instead of using a concatenated playlist.

**Pros**:
- Better compatibility with `just_audio_background`
- Simpler Now Playing info management

**Cons**:
- Lose automatic track progression from `just_audio`
- Need to manually handle track transitions

## Recommended Next Steps

1. **Test with app restart** - Sometimes iOS needs a fresh start
2. **Check Xcode console** for any `MPNowPlayingInfoCenter` errors
3. **Try Option 2** - It's the quickest fix and aligns better with how we're already handling interludes

## Implementation Plan for Option 2

Since we're already using `setAudioSource()` for interludes, we can use the same approach for all tracks:

```dart
// Instead of:
await _player.setAudioSource(_playlistSource);
await _player.seek(Duration.zero, index: index);

// Do:
final track = _playlist[index];
await _player.setAudioSource(
  AudioSource.uri(
    Uri.parse(track['url']),
    tag: MediaItem(
      id: track['key'],
      title: track['label'],
      artist: 'Lectio Divina',
      album: 'Lectio Divina',
      artUri: Uri.parse(AudioConstants.defaultArtworkUrl),
    ),
  ),
);
```

This way, each track gets its own `MediaItem` and iOS should properly show Now Playing info.

## Testing Checklist

After implementing Option 2:

- [ ] Restart app
- [ ] Play first track
- [ ] Check Control Center - should show track info
- [ ] Check lock screen - should show media controls
- [ ] Test Play/Pause from lock screen
- [ ] Test Next/Previous from lock screen
- [ ] Test automatic track progression
- [ ] Test interlude playback

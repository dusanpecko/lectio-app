#!/usr/bin/env dart
// Background Audio Diagnostics Script

import 'dart:io';

void main() async {
  print('🔍 Lectio Divina Background Audio Diagnostics');
  print('============================================');

  await checkNetworkConnectivity();
  await checkAndroidConfig();
  await checkiOSConfig();
  await checkAssets();

  print('\n📝 Troubleshooting Summary:');
  print('---------------------------');
  print('1. Network Issues:');
  print('   - Ensure device has internet connection');
  print('   - Check Supabase URL accessibility');
  print('   - Try loading audio in browser first');
  print('');
  print('2. Icon Issues:');
  print('   - Android: Check notification icon exists');
  print('   - iOS: Ensure background audio mode is enabled');
  print('   - Use proper artwork URL in MediaItem');
  print('');
  print('3. Background Play Issues:');
  print('   - Verify audio service initialization');
  print('   - Check callback registration');
  print('   - Test with simple audio URLs first');
  print('');
  print('4. Auto-progression Issues:');
  print('   - Network errors stop auto-progression');
  print('   - Check _onAudioCompleted callback');
  print('   - Verify section completion handler');
}

Future<void> checkNetworkConnectivity() async {
  print('\n🌐 Network Connectivity Check:');

  try {
    final result = await Process.run('ping', ['-c', '1', 'google.com']);
    if (result.exitCode == 0) {
      print('  ✅ Internet connection: OK');
    } else {
      print('  ❌ Internet connection: FAILED');
    }
  } catch (e) {
    print('  ❌ Could not test connectivity: $e');
  }

  // Test Supabase connectivity
  try {
    final result = await Process.run('ping', [
      '-c',
      '1',
      'unnijykbupxguogrkolj.supabase.co',
    ]);
    if (result.exitCode == 0) {
      print('  ✅ Supabase connectivity: OK');
    } else {
      print('  ❌ Supabase connectivity: FAILED');
      print('     - This could cause audio loading errors');
    }
  } catch (e) {
    print('  ❌ Could not test Supabase: $e');
  }
}

Future<void> checkAndroidConfig() async {
  print('\n🤖 Android Configuration Check:');

  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (await manifestFile.exists()) {
    final content = await manifestFile.readAsString();

    // Check permissions
    final permissions = [
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'android.permission.WAKE_LOCK',
    ];

    for (final permission in permissions) {
      if (content.contains(permission)) {
        print('  ✅ $permission: OK');
      } else {
        print('  ❌ $permission: MISSING');
      }
    }

    // Check audio service
    if (content.contains('com.ryanheise.audioservice.AudioService')) {
      print('  ✅ AudioService declared: OK');
    } else {
      print('  ❌ AudioService declaration: MISSING');
    }

    // Check notification icon
    final iconFile = File(
      'android/app/src/main/res/mipmap-hdpi/launcher_icon.png',
    );
    if (await iconFile.exists()) {
      print('  ✅ Notification icon: OK');
    } else {
      print('  ❌ Notification icon: MISSING');
    }
  } else {
    print('  ❌ AndroidManifest.xml not found');
  }
}

Future<void> checkiOSConfig() async {
  print('\n🍎 iOS Configuration Check:');

  final plistFile = File('ios/Runner/Info.plist');
  if (await plistFile.exists()) {
    final content = await plistFile.readAsString();

    // Check background modes
    if (content.contains('<string>audio</string>')) {
      print('  ✅ Background audio mode: OK');
    } else {
      print('  ❌ Background audio mode: MISSING');
    }

    if (content.contains('UIBackgroundModes')) {
      print('  ✅ UIBackgroundModes declared: OK');
    } else {
      print('  ❌ UIBackgroundModes: MISSING');
    }
  } else {
    print('  ❌ Info.plist not found');
  }
}

Future<void> checkAssets() async {
  print('\n🎨 Assets Check:');

  final iconFile = File('assets/icon/icon.png');
  if (await iconFile.exists()) {
    print('  ✅ App icon asset: OK');
  } else {
    print('  ❌ App icon asset: MISSING');
  }

  // Check pubspec dependencies
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();

    final dependencies = ['audio_service:', 'just_audio:', 'get_it:'];
    for (final dep in dependencies) {
      if (content.contains(dep)) {
        print('  ✅ $dep OK');
      } else {
        print('  ❌ $dep MISSING');
      }
    }
  }
}

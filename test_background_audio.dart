#!/usr/bin/env dart
// Test script pre background audio functionality

import 'dart:async';
import 'dart:io';

void main() async {
  print('🎵 Lectio Divina Background Audio Test');
  print('=====================================');

  print('\n📱 Testing Background Play Configuration...');

  // Test 1: Check if background play configuration is properly set
  await testBackgroundPlayConfig();

  // Test 2: Check audio service setup
  await testAudioServiceSetup();

  // Test 3: Check permissions and foreground service
  await testPermissions();

  print('\n✅ Background audio test completed!');
  print('\n📝 To test on device:');
  print('1. Run: flutter run');
  print('2. Start audio playback in Lectio screen');
  print('3. Put app to background (home button)');
  print('4. Check notification tray for media controls');
  print('5. Audio should continue playing in background');
}

Future<void> testBackgroundPlayConfig() async {
  print('  🔧 Checking audio service configuration...');

  // Check if audio service files exist
  final audioServiceFile = File('lib/services/lectio_audio_service.dart');
  final backgroundManagerFile = File(
    'lib/services/background_audio_manager.dart',
  );

  if (await audioServiceFile.exists()) {
    print('  ✅ LectioAudioService found');
  } else {
    print('  ❌ LectioAudioService missing');
  }

  if (await backgroundManagerFile.exists()) {
    print('  ✅ BackgroundAudioManager found');
  } else {
    print('  ❌ BackgroundAudioManager missing');
  }
}

Future<void> testAudioServiceSetup() async {
  print('  🎯 Checking audio_service integration...');

  // Check pubspec.yaml for audio_service dependency
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    if (content.contains('audio_service:')) {
      print('  ✅ audio_service dependency found');
    } else {
      print('  ❌ audio_service dependency missing in pubspec.yaml');
    }

    if (content.contains('just_audio:')) {
      print('  ✅ just_audio dependency found');
    } else {
      print('  ❌ just_audio dependency missing in pubspec.yaml');
    }
  }
}

Future<void> testPermissions() async {
  print('  🔐 Checking Android permissions...');

  // Check Android manifest for required permissions
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (await manifestFile.exists()) {
    final content = await manifestFile.readAsString();

    final requiredPermissions = [
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'android.permission.WAKE_LOCK',
    ];

    for (final permission in requiredPermissions) {
      if (content.contains(permission)) {
        print('  ✅ $permission found');
      } else {
        print('  ❌ $permission missing - add to AndroidManifest.xml');
      }
    }
  } else {
    print('  ❌ AndroidManifest.xml not found');
  }
}

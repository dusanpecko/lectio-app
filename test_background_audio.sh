#!/bin/bash

echo "🎵 Background Audio Testing Script"
echo "=================================="

# Build and run the app
echo "📱 Building and deploying app..."
flutter run -d 58271JEBF00102 --hot &

# Wait for app to start
sleep 10

# Test procedures
echo ""
echo "🧪 TESTING PROCEDURES:"
echo "======================"

echo ""
echo "1️⃣ TEST NOTIFICATION ICON (iOS & Android):"
echo "   → Start lectio audio playback"
echo "   → Minimize app to background"
echo "   → Check notification tray for:"
echo "     • iOS: Control Center media controls with app icon"
echo "     • Android: Notification with proper launcher icon"

echo ""
echo "2️⃣ TEST ANDROID LOCK SCREEN CONTROLS:"
echo "   → Start audio playback"
echo "   → Lock device screen"
echo "   → Check lock screen shows:"
echo "     • Media player widget"
echo "     • Play/pause/stop controls"
echo "     • Track title and app info"

echo ""
echo "3️⃣ TEST AUTO-PROGRESSION:"
echo "   → Start first audio track (e.g., Modlitba)"
echo "   → Let it play to completion"
echo "   → Verify app automatically starts next track"
echo "   → Test both foreground and background modes"

echo ""
echo "4️⃣ TEST BACKGROUND CONTINUITY:"
echo "   → Start audio playback"
echo "   → Switch to other apps / home screen"
echo "   → Verify audio continues playing"
echo "   → Test media controls from notification/lock screen"

echo ""
echo "5️⃣ TEST CALLBACK SYSTEM:"
echo "   → Monitor logs for: 'Background audio completed - triggering auto-progression'"
echo "   → Verify background service triggers lectio screen callbacks"

echo ""
echo "📋 LOG MONITORING COMMANDS:"
echo "=========================="
echo "# General audio logs:"
echo "adb logcat -s flutter:I | grep -E '(🎵|▶️|🎮|Background audio)'"
echo ""
echo "# Media session logs:"
echo "adb logcat -s flutter:I | grep -E '(MediaSession|AudioService|notification)'"
echo ""
echo "# Auto-progression logs:"
echo "adb logcat -s flutter:I | grep -E '(completed|progression|callback)'"

echo ""
echo "🚀 App is deploying... Start testing when ready!"
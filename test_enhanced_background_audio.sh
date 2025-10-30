#!/bin/bash

echo "🔧 COMPREHENSIVE BACKGROUND AUDIO TESTING"
echo "========================================="

echo ""
echo "📱 Building and deploying with enhanced debugging..."

# Clean and build
flutter clean
flutter pub get

# Build and run
flutter run -d 58271JEBF00102 --debug &

# Wait for deployment
sleep 15

echo ""
echo "🎯 CRITICAL TESTING PROCEDURES:"
echo "==============================="

echo ""
echo "1️⃣ ANDROID LOCK SCREEN TEST:"
echo "   → Open Lectio Divina app"
echo "   → Navigate to Lectio screen"
echo "   → Start any audio track (e.g., Modlitba)"
echo "   → LOCK your device screen (power button)"
echo "   → On lock screen, you should see:"
echo "     • Media player widget with controls"
echo "     • App icon (launcher_icon)"
echo "     • Play/Pause/Stop buttons"
echo "     • Track title and artist"

echo ""
echo "2️⃣ AUTO-PROGRESSION TEST:"
echo "   → Start first audio track"
echo "   → Wait for it to complete (or seek to end)"
echo "   → App should automatically start next track"
echo "   → Monitor logs for: 'Calling registered section completion callback'"

echo ""
echo "3️⃣ BACKGROUND CONTINUITY TEST:"
echo "   → Start audio playback"
echo "   → Press home button (minimize app)"
echo "   → Audio should continue playing"
echo "   → Pull down notification tray"
echo "   → Should see media notification with controls"

echo ""
echo "4️⃣ NOTIFICATION CONTROLS TEST:"
echo "   → With audio playing, pull down notification"
echo "   → Test play/pause button"
echo "   → Test stop button"
echo "   → Test skip next/previous buttons"

echo ""
echo "📊 MONITORING COMMANDS:"
echo "======================"
echo "# Background audio logs:"
echo "adb logcat -s flutter:I | grep -E '(🎵|🏁|🔄|📝|Background|MediaSession)'"
echo ""
echo "# Lock screen media session logs:"
echo "adb logcat | grep -E '(MediaSession|AudioFocus|MediaController)'"
echo ""
echo "# Auto-progression logs:"
echo "adb logcat -s flutter:I | grep -E '(completion|callback|progression|next section)'"

echo ""
echo "🚨 EXPECTED RESULTS:"
echo "==================="
echo "✅ Lock screen shows media player with app icon"
echo "✅ Media controls work from lock screen"
echo "✅ Audio continues in background"
echo "✅ Auto-progression to next track works"
echo "✅ Notification controls are functional"

echo ""
echo "❌ IF PROBLEMS PERSIST:"
echo "======================"
echo "• Android lock screen: Check MediaSession logs"
echo "• Auto-progression: Look for callback registration logs"
echo "• Audio stops: Check background play settings"

echo ""
echo "🔄 App deploying... Start testing when ready!"
#!/bin/bash

# Test script pre Android notification icon
echo "🔍 Testing Android notification icon setup..."

ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
ANDROID_DRAWABLE_DIR="android/app/src/main/res/drawable"

echo ""
echo "📋 Checking AndroidManifest.xml permissions..."

if [ -f "$ANDROID_MANIFEST" ]; then
    echo "✅ AndroidManifest.xml found"
    
    # Check for required permissions
    if grep -q "android.permission.FOREGROUND_SERVICE" "$ANDROID_MANIFEST"; then
        echo "✅ FOREGROUND_SERVICE permission found"
    else
        echo "❌ FOREGROUND_SERVICE permission missing"
    fi
    
    if grep -q "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" "$ANDROID_MANIFEST"; then
        echo "✅ FOREGROUND_SERVICE_MEDIA_PLAYBACK permission found"
    else
        echo "❌ FOREGROUND_SERVICE_MEDIA_PLAYBACK permission missing"
    fi
    
    if grep -q "android.permission.WAKE_LOCK" "$ANDROID_MANIFEST"; then
        echo "✅ WAKE_LOCK permission found"
    else
        echo "❌ WAKE_LOCK permission missing"
    fi
else
    echo "❌ AndroidManifest.xml not found"
fi

echo ""
echo "🎨 Checking notification icon..."

if [ -d "$ANDROID_DRAWABLE_DIR" ]; then
    echo "✅ Drawable directory found: $ANDROID_DRAWABLE_DIR"
    
    if [ -f "$ANDROID_DRAWABLE_DIR/ic_notification.png" ]; then
        echo "✅ ic_notification.png found"
    else
        echo "❌ ic_notification.png missing"
        echo "💡 Creating default notification icon..."
        
        # Create drawable directory if not exists
        mkdir -p "$ANDROID_DRAWABLE_DIR"
        
        # Copy app icon as notification icon
        if [ -f "assets/icon/icon.png" ]; then
            cp "assets/icon/icon.png" "$ANDROID_DRAWABLE_DIR/ic_notification.png"
            echo "✅ Created ic_notification.png from app icon"
        else
            echo "❌ App icon not found at assets/icon/icon.png"
        fi
    fi
else
    echo "❌ Drawable directory not found"
fi

echo ""
echo "🔧 Background audio configuration summary:"
echo "- Notification channel: sk.lectio.divina.audio"
echo "- Ongoing notification: true"
echo "- Stop foreground on pause: true"
echo "- Custom notification icon: drawable/ic_notification"
echo ""
echo "✅ Test completed!"
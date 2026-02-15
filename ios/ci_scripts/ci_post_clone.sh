#!/bin/sh

# Xcode Cloud post-clone script for Flutter
# Installs Flutter, generates config files, and runs pod install

set -e

echo "=== ci_post_clone.sh START ==="
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_WORKSPACE: $CI_WORKSPACE"

# ---- Install Flutter SDK ----
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
    echo "Installing Flutter SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

echo "Flutter version:"
flutter --version

# Precache iOS artifacts
flutter precache --ios

# ---- Navigate to project root ----
cd "$CI_PRIMARY_REPOSITORY_PATH"

# ---- Create .env if missing (it's in .gitignore) ----
if [ ! -f ".env" ]; then
    echo "Creating empty .env file..."
    touch .env
fi

# ---- Flutter pub get ----
echo "Running flutter pub get..."
flutter pub get

# ---- Generate Flutter build files (Generated.xcconfig etc.) ----
echo "Generating Flutter build config..."
flutter build ios --config-only --release --no-codesign

# ---- CocoaPods ----
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
echo "Running pod install..."
pod install

echo "=== ci_post_clone.sh DONE ==="

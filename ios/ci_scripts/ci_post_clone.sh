#!/bin/sh

# Xcode Cloud post-clone script for Flutter
# Installs Flutter, generates config files, and runs pod install

set -e

echo "=== ci_post_clone.sh START ==="
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_WORKSPACE: $CI_WORKSPACE"

# ---- Install Flutter SDK ----
# Pinnuté na verziu zhodnú s lokálnym vývojom (pri lokálnom upgrade Fluttera
# zvýš aj tu) — reprodukovateľné store buildy > "najnovšie stable".
FLUTTER_VERSION="3.44.0"
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
    echo "Installing Flutter SDK $FLUTTER_VERSION..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

echo "Flutter version:"
flutter --version

# ---- KĽÚČOVÉ (fix 5.7.2026): vypni Swift Package Manager ----
# Čerstvý Flutter má SPM integráciu ZAPNUTÚ → do workspace by pridal
# 'flutterfire' ako SPM balík a Xcode Cloud archive by potom vyžadoval
# commitnutý Package.resolved ("Could not resolve package dependencies:
# a resolved file is required when automatic dependency resolution is
# disabled…"). Lokálne buildujeme so SPM VYPNUTÝM (čisté CocoaPods) →
# CI musí byť zhodné.
flutter config --no-enable-swift-package-manager

# Precache iOS artifacts
flutter precache --ios

# ---- Navigate to project root ----
cd "$CI_PRIMARY_REPOSITORY_PATH"

# ---- .env (v .gitignore, ale je bundlovaný asset — appka ho číta pri štarte) ----
# V Xcode Cloud workflow nastav SECRET environment premennú DOTENV_BASE64:
#   lokálne: base64 -i .env | pbcopy
#   App Store Connect → Xcode Cloud → Workflow → Environment Variables
#   → pridaj DOTENV_BASE64 (Secret ✓) a vlož skopírovanú hodnotu.
if [ -n "$DOTENV_BASE64" ]; then
    echo "Writing .env from DOTENV_BASE64..."
    echo "$DOTENV_BASE64" | base64 --decode > .env
else
    echo "⚠️  DOTENV_BASE64 NIE JE nastavené — vytváram PRÁZDNY .env."
    echo "⚠️  Build prejde, ale appka pri štarte ukáže 'Konfigurácia chýba'!"
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

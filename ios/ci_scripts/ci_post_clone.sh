#!/bin/sh

# Xcode Cloud post-clone script
# Installs CocoaPods dependencies and generates Flutter build files

set -e

echo "=== ci_post_clone.sh ==="

# Navigate to the ios directory
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

# Install Flutter
# Check if flutter is already available
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
    export PATH="$HOME/flutter/bin:$PATH"
fi

echo "Flutter version:"
flutter --version

# Navigate back to project root for Flutter commands
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Get Flutter dependencies
echo "Running flutter pub get..."
flutter pub get

# Generate Flutter build config files
echo "Running flutter build ios --config-only..."
flutter build ios --config-only

# Navigate to ios directory for pod install
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

# Install CocoaPods dependencies
echo "Running pod install..."
pod install

echo "=== ci_post_clone.sh completed ==="

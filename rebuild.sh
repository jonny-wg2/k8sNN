#!/bin/bash

# Quick rebuild and reinstall script for K8sNN
# Usage:
#   ./rebuild.sh            # builds Debug (fast, recommended while iterating)
#   ./rebuild.sh release    # builds Release

set -euo pipefail

MODE="${1:-debug}"
MODE_LOWER="$(echo "$MODE" | tr '[:upper:]' '[:lower:]')"
if [[ "$MODE_LOWER" == "release" ]]; then
  CONFIG="Release"
else
  CONFIG="Debug"
fi

echo "🔨 Rebuilding K8sNN ($CONFIG)..."

# Kill any running instances
echo "🛑 Stopping existing K8sNN instances..."
killall K8sNN 2>/dev/null || true

# Clean previous build output to avoid DB locks
rm -rf build || true

# Common speed-ups for CLI builds
COMMON_FLAGS=(
  -project K8sNN.xcodeproj
  -scheme K8sNN
  -configuration "$CONFIG"
  -destination "platform=macOS"
  -derivedDataPath build
  COMPILER_INDEX_STORE_ENABLE=NO
)

# Debug builds: incremental compilation (fast, avoids WMO)
if [[ "$CONFIG" == "Debug" ]]; then
  EXTRA_FLAGS=(SWIFT_COMPILATION_MODE=incremental)
else
  # Release builds: avoid WMO to prevent hangs on large SwiftUI files
  EXTRA_FLAGS=(SWIFT_COMPILATION_MODE=singlefile)
fi

echo "🏗️  Building project..."
if xcodebuild "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" build; then
  echo "✅ Build successful!"
else
  echo "❌ Build failed!"
  exit 1
fi

# Install the app
echo "📦 Installing to Applications..."
cp -R "build/Build/Products/$CONFIG/K8sNN.app" /Applications/

# Launch the app
echo "🚀 Launching K8sNN..."
open /Applications/K8sNN.app

echo ""
echo "✅ K8sNN ($CONFIG) rebuilt and launched successfully!"
echo "💡 The app should now appear in your menubar"
echo "🔄 Click the server icon to see your clusters"
#!/bin/bash

# Quick rebuild and reinstall script for K8sNN
# This script builds the app and automatically installs it

set -e

echo "🔨 Rebuilding K8sNN..."

# Kill any running instances
echo "🛑 Stopping existing K8sNN instances..."
killall K8sNN 2>/dev/null || true

# Build the project
echo "🏗️  Building project..."
if xcodebuild -project K8sNN.xcodeproj -scheme K8sNN -configuration Release -derivedDataPath build; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Install the app
echo "📦 Installing to Applications..."
cp -r build/Build/Products/Release/K8sNN.app /Applications/

# Launch the app
echo "🚀 Launching K8sNN..."
open /Applications/K8sNN.app

echo ""
echo "✅ K8sNN rebuilt and launched successfully!"
echo "💡 The app should now appear in your menubar"
echo "🔄 Click the server icon to see your clusters"
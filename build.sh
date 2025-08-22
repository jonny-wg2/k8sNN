#!/bin/bash

# Build script for K8sNN macOS app

set -e

echo "Building K8sNN..."

# Check if we have Xcode or just Command Line Tools
if command -v xcodebuild &> /dev/null; then
    # Check if we have full Xcode
    if xcode-select -p | grep -q "Xcode.app"; then
        echo "Using Xcode to build..."
        xcodebuild -project K8sNN.xcodeproj -scheme K8sNN -configuration Release -derivedDataPath build
        echo "Build completed successfully!"
        echo "The app can be found at: build/Build/Products/Release/K8sNN.app"
    else
        echo "Full Xcode not found. You have Command Line Tools but need full Xcode for GUI apps."
        echo ""
        echo "Options:"
        echo "1. Install Xcode from the Mac App Store (recommended)"
        echo "2. Use the manual Swift compilation method below"
        echo ""
        echo "Manual compilation (experimental):"
        echo "This will compile the Swift files directly, but may not work perfectly for GUI apps."
        read -p "Do you want to try manual compilation? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            manual_build
        else
            echo "Please install Xcode from the Mac App Store and try again."
            exit 1
        fi
    fi
else
    echo "Error: No development tools found. Please install Xcode from the Mac App Store."
    exit 1
fi

echo ""
echo "To install the app:"
echo "1. Copy K8sNN.app to your Applications folder"
echo "2. Run the app from Applications or Spotlight"
echo "3. The app will appear in your menu bar"

manual_build() {
    echo "Attempting manual Swift compilation..."

    # Create build directory
    mkdir -p manual_build

    # Try to compile with swiftc (this is experimental and may not work for GUI apps)
    echo "Note: Manual compilation of SwiftUI apps is complex and may not work."
    echo "The recommended approach is to install Xcode and use the proper build system."

    # This is a simplified attempt - it likely won't work for a full SwiftUI app
    swiftc -o manual_build/k8snn \
        -framework Foundation \
        -framework AppKit \
        -framework SwiftUI \
        K8sNN/*.swift 2>/dev/null || {
        echo "Manual compilation failed (expected for SwiftUI apps)."
        echo "Please install Xcode from the Mac App Store for proper app building."
        exit 1
    }
}

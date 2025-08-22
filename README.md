# K8sNN - Kubernetes Cluster Authentication Monitor

A beautiful macOS menubar app that monitors the authentication status of your Kubernetes clusters and provides quick access to Dex login pages.

## Features

- **Real-time Authentication Monitoring**: Shows green/red status indicators for each cluster
- **Automatic Cluster Discovery**: Reads your kubectl config to find all configured clusters
- **One-Click Login**: Click on unauthenticated clusters to open their Dex login pages
- **Native macOS Design**: Clean, professional menubar interface
- **Periodic Checks**: Automatically refreshes authentication status every 5 minutes
- **Smart URL Generation**: Automatically constructs login URLs for wgtwo.com clusters

## Download

**📥 [Download the latest release](https://github.com/jonny-wg2/k8sNN/releases/latest)**

Choose from:

- **K8sNN.dmg** - Easy installer with drag-and-drop setup
- **K8sNN.zip** - Manual installation archive

For detailed installation instructions, see [INSTALLATION.md](INSTALLATION.md).

## Requirements

- macOS 14.0 or later
- kubectl installed and configured
- Xcode 15.0 or later (for building from source)

## Installation

### Option 1: Build from Source

1. Clone or download this project
2. Open Terminal and navigate to the project directory
3. Run the build script:
   ```bash
   ./build.sh
   ```
4. Copy the built app to your Applications folder:
   ```bash
   cp -r build/Build/Products/Release/K8sNN.app /Applications/
   ```
5. Launch K8sNN from Applications or Spotlight

### Option 2: Build with Xcode

1. Open `K8sNN.xcodeproj` in Xcode
2. Select the K8sNN scheme
3. Build and run (⌘+R)

## Usage

1. **Launch the app**: K8sNN will appear in your menu bar with a server icon
2. **View cluster status**: Click the menu bar icon to see all your clusters
   - 🟢 Green dot = Authenticated
   - 🔴 Red dot = Not authenticated
3. **Login to clusters**: Click on any cluster with a red dot to open its login page
4. **Refresh status**: Click the refresh button to manually check all clusters
5. **Monitor continuously**: The app automatically checks every 5 minutes

## How It Works

K8sNN works by:

1. **Reading kubectl config**: Parses your `~/.kube/config` file to discover clusters
2. **Testing authentication**: Runs `kubectl auth can-i get pods` for each cluster
3. **Generating login URLs**: Creates Dex login URLs based on cluster names
4. **Opening browsers**: Uses macOS to open login pages when needed

## Supported Cluster Patterns

The app automatically generates login URLs for clusters following these patterns:

- `*.tky.prod.wgtwo.com` → `https://login.tky.prod.wgtwo.com`
- `*.dub.prod.wgtwo.com` → `https://login.dub.prod.wgtwo.com`
- `*.pdx.prod.wgtwo.com` → `https://login.pdx.prod.wgtwo.com`
- `*.sto.prod.wgtwo.com` → `https://login.sto.prod.wgtwo.com`
- `*.dub.infrasvc.wgtwo.com` → `https://login.dub.infrasvc.wgtwo.com`
- And similar patterns for dev environments

## Troubleshooting

### "No clusters found"

- Ensure kubectl is installed and in your PATH
- Check that `~/.kube/config` exists and contains cluster configurations
- Try running `kubectl config get-contexts` in Terminal

### "Failed to get kubectl contexts"

- Verify kubectl is installed at `/usr/local/bin/kubectl`
- If kubectl is installed elsewhere, update the path in `KubernetesManager.swift`

### Authentication checks failing

- Ensure you have network connectivity
- Check that your kubectl contexts are properly configured
- Some clusters may require VPN access

## Architecture

The app consists of several key components:

- **K8sNNApp.swift**: Main app entry point and menubar setup
- **KubernetesManager.swift**: Core logic for cluster discovery and authentication checking
- **ClusterModel.swift**: Data models for clusters and kubectl config
- **MenuBarView.swift**: SwiftUI interface for the menubar dropdown
- **ContentView.swift**: Placeholder view (not used in menubar mode)

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is provided as-is for personal use.

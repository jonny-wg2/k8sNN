# K8sNN Installation Guide

## Download

Visit the [Releases page](https://github.com/jonny-wg2/k8sNN/releases) and download the latest version.

### Download Options

**🎯 Recommended: DMG Installer**

- File: `K8sNN.dmg`
- Easy drag-and-drop installation
- Includes Applications folder shortcut

**📦 Alternative: ZIP Archive**

- File: `K8sNN.zip`
- Manual installation required
- Smaller download size

## Installation

### Option 1: DMG Installer (Recommended)

1. **Download** `K8sNN.dmg` from the releases page
2. **Double-click** the DMG file to mount it
3. **Drag** K8sNN.app to the Applications folder
4. **Eject** the disk image
5. **Launch** K8sNN from Applications or Spotlight

### Option 2: ZIP Archive

1. **Download** `K8sNN.zip` from the releases page
2. **Extract** the ZIP file (double-click or use Archive Utility)
3. **Move** K8sNN.app to your `/Applications` folder
4. **Launch** K8sNN from Applications or Spotlight

## First Launch

### Security Notice

On first launch, macOS may show a security warning because the app is ad-hoc signed (not signed with a paid Apple Developer certificate).

**To allow the app to run:**

**Method 1: Security & Privacy (Recommended)**

1. Try to open the app (it will be blocked)
2. Go to **System Preferences** > **Security & Privacy** > **General**
3. Click **"Open Anyway"** next to the K8sNN warning
4. Confirm by clicking **"Open"** in the dialog

**Method 2: Right-click Override**

1. Right-click on K8sNN.app in Applications
2. Select **"Open"** from the context menu
3. Click **"Open"** in the security dialog

**Method 3: Command Line (Advanced)**

```bash
sudo xattr -rd com.apple.quarantine /Applications/K8sNN.app
```

### Initial Setup

1. **Look for the server icon** in your menubar (top-right area)
2. **Click the icon** to open the cluster list
3. **Green dots** = authenticated clusters
4. **Red dots** = clusters needing authentication
5. **Click red clusters** to open their login pages

## Requirements

- **macOS 14.0** or later
- **kubectl** installed and configured
- **Network access** to your Kubernetes clusters

### Installing kubectl (if needed)

**Using Homebrew:**

```bash
brew install kubectl
```

**Using curl:**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## Features

### 🔍 Spotlight-Style Search

- Press **⌘⇧K** (configurable) to open quick search
- Type to filter clusters
- Use **↑↓** arrows to navigate
- Press **Enter** to authenticate or open terminal

### 📊 Real-Time Monitoring

- Automatic authentication checks every 5 minutes
- Visual status indicators (green/red dots)
- Last checked timestamps

### 🌐 One-Click Authentication

- Automatically detects Dex-enabled clusters
- Opens login pages in your default browser
- Supports wgtwo.com cluster patterns

### ⚙️ Customizable Settings

- Configurable global hotkey
- Adjustable check intervals
- Terminal application preferences

## Troubleshooting

### "K8sNN can't be opened because it's from an unidentified developer"

This is normal for unsigned apps. Follow the security steps above.

### "No clusters found"

- Ensure kubectl is installed: `kubectl version --client`
- Check your kubeconfig: `kubectl config get-contexts`
- Verify file exists: `ls ~/.kube/config`

### "Authentication checks failing"

- Test kubectl manually: `kubectl get pods`
- Check network connectivity
- Verify VPN connection if required
- Ensure cluster URLs are accessible

### App doesn't appear in menubar

- Check if the app is running: Activity Monitor > search "K8sNN"
- Try quitting and relaunching
- Check macOS menubar settings (System Preferences > Dock & Menu Bar)

### Hotkey not working

- Check for conflicts with other apps
- Try changing the hotkey in K8sNN settings
- Ensure K8sNN has accessibility permissions if needed

## Uninstalling

1. **Quit K8sNN** (right-click menubar icon > Quit)
2. **Delete** `/Applications/K8sNN.app`
3. **Remove settings** (optional): `~/Library/Preferences/com.k8snn.app.plist`

## Support

- **Issues**: [GitHub Issues](https://github.com/jonny-wg2/k8sNN/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jonny-wg2/k8sNN/discussions)
- **Source Code**: [GitHub Repository](https://github.com/jonny-wg2/k8sNN)

## Building from Source

If you prefer to build the app yourself:

```bash
git clone https://github.com/jonny-wg2/k8sNN.git
cd k8sNN
./build.sh
cp -r build/Build/Products/Release/K8sNN.app /Applications/
```

Requires Xcode 15.0 or later.

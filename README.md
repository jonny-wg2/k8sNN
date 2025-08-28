# K8sNN - Kubernetes Multi-Cluster Management

A macOS menu bar app that solves the pain of managing authentication and running commands across multiple Kubernetes clusters.

## The Problem

Working with multiple Kubernetes clusters is frustrating:

- **Authentication expires constantly** - You never know which clusters you're authenticated to
- **Manual login is tedious** - Finding and opening the right Dex/OIDC login URLs
- **Context switching is slow** - Manually switching kubectl contexts and opening terminals
- **Multi-cluster operations are painful** - Running the same command across multiple clusters requires scripts or repetitive work

## The Solution

K8sNN puts all your clusters in your menu bar with:

- **🟢 Real-time auth status** - See which clusters you're authenticated to at a glance
- **⚡ One-click login** - Click any cluster to open its authentication page
- **🚀 Instant terminal access** - Click authenticated clusters to open a terminal with the right context
- **🔄 Multi-cluster commands** - Run kubectl/flux commands across multiple clusters simultaneously
- **⌨️ Global hotkeys** - Quick access with ⌘⇧K (single cluster) or ⌘⇧L (multi-cluster)
- **🔧 Custom commands** - Configure SSH tunnels or other per-cluster commands

## Installation

**📥 [Download the latest release](https://github.com/jonny-wg2/k8sNN/releases/latest)**

1. Download `K8sNN.dmg` or `K8sNN.zip`
2. Drag K8sNN.app to your Applications folder
3. Launch K8sNN - it will appear in your menu bar
4. The app will automatically start on login (can be disabled in settings)

**Requirements:** macOS 14.0+, kubectl installed

## How to Use

### Basic Usage

1. **Click the server icon** in your menu bar to see all clusters
2. **Check authentication status**:
   - 🟢 Green = Authenticated and ready
   - 🔴 Red = Need to authenticate
3. **Click any cluster** to:
   - **Red clusters**: Open authentication page in browser
   - **Green clusters**: Open terminal with kubectl context set

### Quick Access (Hotkeys)

- **⌘⇧K**: Open cluster selector - type to search, Enter to select
- **⌘⇧L**: Open multi-cluster command interface

### Multi-Cluster Commands

1. Press **⌘⇧L** or click "Multi-Cluster kubectl" in menu
2. Select clusters you want to target
3. Type your command (e.g., `get pods`, `get nodes`)
4. Choose command type: `kubectl` or `flux`
5. Press Enter to run across all selected clusters

### Settings & Customization

- **Custom login URLs**: Override auto-generated URLs for specific clusters
- **Custom commands**: Set up SSH tunnels or other per-cluster commands
- **Terminal app**: Choose between Terminal.app and iTerm
- **Auto-start**: Control whether app starts on login (enabled by default)
- **Hotkeys**: Customize keyboard shortcuts

### Examples

```bash
# Multi-cluster examples:
get pods -n kube-system
get nodes --show-labels
describe deployment nginx -n default
logs -f deployment/app -n production
```

## How It Works

K8sNN automatically:

1. **Discovers clusters** from your `~/.kube/config` file
2. **Tests authentication** by running `kubectl auth can-i get pods` for each cluster
3. **Generates login URLs** for Dex/OIDC authentication (supports custom URLs)
4. **Monitors continuously** - checks authentication status every 5 minutes

## Troubleshooting

**No clusters found?**

- Ensure kubectl is installed and `~/.kube/config` exists
- Run `kubectl config get-contexts` to verify your setup

**Authentication failing?**

- Check network connectivity and VPN if required
- Verify kubectl contexts are properly configured

**Need help?** [Open an issue](https://github.com/jonny-wg2/k8sNN/issues) with details about your setup.

## Building from Source

```bash
git clone https://github.com/jonny-wg2/k8sNN.git
cd k8sNN
./build.sh
cp -r build/Build/Products/Release/K8sNN.app /Applications/
```

Requires Xcode 15.0+ and macOS 14.0+.

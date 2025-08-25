import AppKit
import SwiftUI

final class SpotlightController {
    static let shared = SpotlightController()
    private init() {}

    private var window: SpotlightOverlayWindow?

    // Show or focus the overlay
    func show(kubernetesManager: KubernetesManager, settingsManager: SettingsManager) {
        showWithMode(.clusters, kubernetesManager: kubernetesManager, settingsManager: settingsManager)
    }

    // Show spotlight in multi-command mode
    func showMultiCommand(kubernetesManager: KubernetesManager, settingsManager: SettingsManager) {
        showWithMode(.multiCommand, kubernetesManager: kubernetesManager, settingsManager: settingsManager)
    }

    private func showWithMode(_ mode: SpotlightMode, kubernetesManager: KubernetesManager, settingsManager: SettingsManager) {
        if let win = window {
            // Bring to front and focus
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            // Update the mode if needed
            if let hostingView = win.contentView as? NSHostingView<SpotlightOverlay> {
                // We need to recreate the view with the new mode
                // For now, just close and reopen
                hide()
                showWithMode(mode, kubernetesManager: kubernetesManager, settingsManager: settingsManager)
            }
            return
        }

        let win = SpotlightOverlayWindow()
        let content = SpotlightOverlay(initialMode: mode)
            .environmentObject(kubernetesManager)
            .environmentObject(settingsManager)

        win.contentView = NSHostingView(rootView: content)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Track and auto-clear when closed
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { [weak self] _ in
            self?.window = nil
        }

        window = win
    }

    // Hide the overlay if present
    func hide() {
        guard let win = window else { return }
        win.orderOut(nil)
        win.close()
        window = nil
    }
}


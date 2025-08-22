import AppKit
import SwiftUI

final class SpotlightController {
    static let shared = SpotlightController()
    private init() {}

    private var window: SpotlightOverlayWindow?

    // Show or focus the overlay
    func show(kubernetesManager: KubernetesManager, settingsManager: SettingsManager) {
        if let win = window {
            // Bring to front and focus
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = SpotlightOverlayWindow()
        let content = SpotlightOverlay()
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


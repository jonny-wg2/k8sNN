import SwiftUI
import AppKit

// Keep the app alive after last window closes
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct K8sNNApp: App {
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var kubernetesManager = KubernetesManager()
    @StateObject private var settingsManager = SettingsManager()

    // No stored reference; we discover the overlay window when needed

    var body: some Scene {
        MenuBarExtra("K8sNN", systemImage: "server.rack") {
            MenuBarView()
                .environmentObject(kubernetesManager)
                .environmentObject(settingsManager)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        setupNotifications()

        // Ensure cleanup on app termination
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Cleanup will be handled by deinit
        }
    }

    private func cleanup() {
        SpotlightControllerInlined.shared.hide()
        settingsManager.cleanup()
    }

    private func setupNotifications() {
        // Listen for hotkey press
        NotificationCenter.default.addObserver(
            forName: .hotkeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            print("Hotkey pressed notification received")
            SpotlightControllerInlined.shared.show(kubernetesManager: kubernetesManager, settingsManager: settingsManager)
        }

        // Listen for hide spotlight
        NotificationCenter.default.addObserver(
            forName: .hideSpotlight,
            object: nil,
            queue: .main
        ) { notification in
            print("hideSpotlight notification received from: \(notification.object ?? "unknown")")
            SpotlightControllerInlined.shared.hide()
        }
    }

    /* Legacy: handled by SpotlightController
    private func showSpotlightOverlay() {
        print("showSpotlightOverlay called, current window: \(windowManager.spotlightWindow != nil ? "exists" : "nil")")
        if let window = windowManager.spotlightWindow {
            print("Window reference exists: \(window), isVisible: \(window.isVisible)")
        }

        // If window is already open, just focus/bring to front (no toggle)
        if let existing = windowManager.spotlightWindow {
            print("Window exists, bringing to front")
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        print("Creating new spotlight window")
        // Create new spotlight window
        let window = SpotlightOverlayWindow()
        let contentView = SpotlightOverlay()
            .environmentObject(kubernetesManager)
            .environmentObject(settingsManager)

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        // Hold a strong reference for the life of the window
        windowManager.spotlightWindow = window

        // When the window closes, clear our reference
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            self.windowManager.spotlightWindow = nil
        }

        print("Spotlight window created and shown, reference set to: \(window)")
        print("Current spotlightWindow after assignment: \(windowManager.spotlightWindow != nil ? "exists" : "nil")")
    }
    */

    /* Legacy: handled by SpotlightController
    private func hideSpotlightOverlay() {
        print("hideSpotlightOverlay called")
        if let window = windowManager.spotlightWindow {
            print("Closing existing window")
            window.orderOut(nil)
            window.close()
            windowManager.spotlightWindow = nil
            print("Window closed and reference cleared")
        } else {
            print("No window to close - this might indicate a reference management issue")
        }
    }
    */
}
// Inline controller to avoid target linkage issues
final class SpotlightControllerInlined {
    static let shared = SpotlightControllerInlined()
    private init() {}

    private var window: SpotlightOverlayWindow?

    func show(kubernetesManager: KubernetesManager, settingsManager: SettingsManager) {
        if let win = window {
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
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { [weak self] _ in
            self?.window = nil
        }
        window = win
    }

    // Hide by ordering out; do not close the window so the app doesn't terminate
    func hide() {
        guard let win = window else { return }
        win.orderOut(nil)
        // Keep reference so we can bring it back quickly
    }
}


// Simple class to hold window reference outside of SwiftUI state management
class WindowManager {
    var spotlightWindow: SpotlightOverlayWindow?
}



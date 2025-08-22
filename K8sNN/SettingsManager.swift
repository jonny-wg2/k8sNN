import Foundation
import SwiftUI
import AppKit
import Carbon
import ApplicationServices

class SettingsManager: ObservableObject {
    @Published var hotkey: String = "⌘⇧K"
    @Published var isHotkeyEnabled: Bool = true
    @Published var terminalApp: String = "iTerm"

    private let defaults = UserDefaults.standard
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    init() {
        loadSettings()
        setupHotkey()
    }
    
    deinit {
        unregisterHotkey()
    }

    func cleanup() {
        unregisterHotkey()
    }
    
    private func loadSettings() {
        hotkey = defaults.string(forKey: "hotkey") ?? "⌘⇧K"
        isHotkeyEnabled = defaults.bool(forKey: "isHotkeyEnabled")
        terminalApp = defaults.string(forKey: "terminalApp") ?? "iTerm"
    }
    
    func saveSettings() {
        let oldHotkey = defaults.string(forKey: "hotkey") ?? "⌘⇧K"
        let oldEnabled = defaults.bool(forKey: "isHotkeyEnabled")

        defaults.set(hotkey, forKey: "hotkey")
        defaults.set(isHotkeyEnabled, forKey: "isHotkeyEnabled")
        defaults.set(terminalApp, forKey: "terminalApp")

        // Only re-register hotkey if it actually changed
        if oldHotkey != hotkey || oldEnabled != isHotkeyEnabled {
            print("Hotkey settings changed, re-registering...")
            unregisterHotkey()
            if isHotkeyEnabled {
                setupHotkey()
            }
        }
    }
    
    private func setupHotkey() {
        guard isHotkeyEnabled else {
            print("Hotkey is disabled")
            return
        }

        // Unregister any existing hotkey first
        unregisterHotkey()

        let hotkeyID = EventHotKeyID(signature: fourCharCodeFrom("K8NN"), id: 1)
        let (keyCode, modifiers) = parseHotkey(hotkey)

        print("Setting up hotkey with keyCode: \(keyCode), modifiers: \(modifiers)")

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            print("Event handler called!")

            // Verify this is our hotkey event
            var hotkeyID = EventHotKeyID()
            let result = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            print("Event parameter result: \(result), hotkeyID signature: \(hotkeyID.signature), id: \(hotkeyID.id)")

            if result == noErr && hotkeyID.signature == fourCharCodeFrom("K8NN") && hotkeyID.id == 1 {
                print("Our hotkey detected! Posting notification...")
                // Post notification when our specific hotkey is pressed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
                }
            } else {
                print("Not our hotkey or error getting parameters")
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }

        let registerStatus = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return
        }

        print("Hotkey registered successfully: \(hotkey) with keyCode: \(keyCode), modifiers: \(modifiers)")
    }
    
    private func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func parseHotkey(_ hotkey: String) -> (keyCode: Int, modifiers: Int) {
        var modifiers = 0
        var keyCode = kVK_ANSI_K // Default to K
        
        if hotkey.contains("⌘") {
            modifiers |= cmdKey
        }
        if hotkey.contains("⇧") {
            modifiers |= shiftKey
        }
        if hotkey.contains("⌥") {
            modifiers |= optionKey
        }
        if hotkey.contains("⌃") {
            modifiers |= controlKey
        }
        
        // Extract the actual key (last character)
        if let lastChar = hotkey.last, lastChar.isLetter {
            switch lastChar.uppercased() {
            case "A": keyCode = kVK_ANSI_A
            case "B": keyCode = kVK_ANSI_B
            case "C": keyCode = kVK_ANSI_C
            case "D": keyCode = kVK_ANSI_D
            case "E": keyCode = kVK_ANSI_E
            case "F": keyCode = kVK_ANSI_F
            case "G": keyCode = kVK_ANSI_G
            case "H": keyCode = kVK_ANSI_H
            case "I": keyCode = kVK_ANSI_I
            case "J": keyCode = kVK_ANSI_J
            case "K": keyCode = kVK_ANSI_K
            case "L": keyCode = kVK_ANSI_L
            case "M": keyCode = kVK_ANSI_M
            case "N": keyCode = kVK_ANSI_N
            case "O": keyCode = kVK_ANSI_O
            case "P": keyCode = kVK_ANSI_P
            case "Q": keyCode = kVK_ANSI_Q
            case "R": keyCode = kVK_ANSI_R
            case "S": keyCode = kVK_ANSI_S
            case "T": keyCode = kVK_ANSI_T
            case "U": keyCode = kVK_ANSI_U
            case "V": keyCode = kVK_ANSI_V
            case "W": keyCode = kVK_ANSI_W
            case "X": keyCode = kVK_ANSI_X
            case "Y": keyCode = kVK_ANSI_Y
            case "Z": keyCode = kVK_ANSI_Z
            default: keyCode = kVK_ANSI_K
            }
        }
        
        return (keyCode, modifiers)
    }

    func openTerminalWithContext(_ contextName: String) -> Bool {
        let kubectlCommand = "kubectl config use-context \"\(contextName)\" && echo \"Switched to context: \(contextName)\" && kubectl config current-context"
        NSLog("[K8sNN] openTerminalWithContext called for context=\(contextName), preferred=\(terminalApp)")

        let itermInstalled = isAppInstalled(bundleId: "com.googlecode.iterm2")
        let terminalInstalled = isAppInstalled(bundleId: "com.apple.Terminal")
        NSLog("[K8sNN] Installed apps -> iTerm: \(itermInstalled), Terminal: \(terminalInstalled)")

        // Check if we have permission to control applications
        let status = AXIsProcessTrusted()
        NSLog("[K8sNN] Accessibility permission status: \(status)")

        func tryITermThenTerminal() -> Bool {
            NSLog("[K8sNN] Trying iTerm first...")
            if openITermWithCommand(kubectlCommand) {
                NSLog("[K8sNN] Successfully opened iTerm and sent command")
                return true
            }
            NSLog("[K8sNN] iTerm attempt failed, trying Terminal...")
            if openTerminalAppWithCommand(kubectlCommand) {
                NSLog("[K8sNN] Successfully opened Terminal and sent command")
                return true
            }
            NSLog("[K8sNN] Both iTerm and Terminal AppleScript attempts failed, trying fallback...")
            return openTerminalWithWorkspace()
        }
        func tryTerminalThenITerm() -> Bool {
            NSLog("[K8sNN] Trying Terminal first...")
            if openTerminalAppWithCommand(kubectlCommand) {
                NSLog("[K8sNN] Successfully opened Terminal and sent command")
                return true
            }
            NSLog("[K8sNN] Terminal attempt failed, trying iTerm...")
            if openITermWithCommand(kubectlCommand) {
                NSLog("[K8sNN] Successfully opened iTerm and sent command")
                return true
            }
            NSLog("[K8sNN] Both Terminal and iTerm AppleScript attempts failed, trying fallback...")
            return openTerminalWithWorkspace()
        }

        switch terminalApp {
        case "iTerm":
            return tryITermThenTerminal()
        case "Terminal":
            return tryTerminalThenITerm()
        default:
            return tryITermThenTerminal() // Default to iTerm with Terminal fallback
        }
    }

    private func isAppInstalled(bundleId: String) -> Bool {
        let isInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        NSLog("[K8sNN] App \(bundleId) installed: \(isInstalled)")

        // Also try to find iTerm using mdfind as a fallback
        if !isInstalled && bundleId == "com.googlecode.iterm2" {
            let task = Process()
            task.launchPath = "/usr/bin/mdfind"
            task.arguments = ["kMDItemCFBundleIdentifier == 'com.googlecode.iterm2'"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let foundPaths = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines).filter { !$0.isEmpty }

            NSLog("[K8sNN] mdfind found iTerm paths: \(foundPaths)")
            return !foundPaths.isEmpty
        }

        return isInstalled
    }

    private func openITermWithCommand(_ command: String) -> Bool {
        NSLog("[K8sNN] openITermWithCommand called with command: \(command)")

        // First try to check if iTerm is running
        let runningApps = NSWorkspace.shared.runningApplications
        let itermRunning = runningApps.contains { $0.bundleIdentifier == "com.googlecode.iterm2" }
        NSLog("[K8sNN] iTerm running: \(itermRunning)")

        // Escape the command properly for AppleScript
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")

        // Try different approaches to reference iTerm
        let scripts = [
            // Try using the application name directly (most common)
            """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(escapedCommand)"
                end tell
            end tell
            """,
            // Try alternative syntax for older iTerm versions
            """
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(escapedCommand)"
                end tell
            end tell
            """,
            // Try using bundle identifier
            """
            tell application id "com.googlecode.iterm2"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(escapedCommand)"
                end tell
            end tell
            """,
            // Try using full path
            """
            tell application "/Applications/iTerm.app"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(escapedCommand)"
                end tell
            end tell
            """,
            // Try just opening iTerm without creating a new window
            """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current session of current window
                    write text "\(escapedCommand)"
                end tell
            end tell
            """
        ]

        for (index, script) in scripts.enumerated() {
            NSLog("[K8sNN] Trying iTerm script approach \(index + 1)")
            NSLog("[K8sNN] Executing iTerm AppleScript: \(script)")

            // First check if the script compiles
            guard let appleScript = NSAppleScript(source: script) else {
                NSLog("[K8sNN] Failed to create AppleScript for iTerm (approach \(index + 1))")
                continue
            }

            // Check if the script compiles without errors
            var compileError: NSDictionary?
            if !appleScript.compileAndReturnError(&compileError) {
                NSLog("[K8sNN] Failed to compile AppleScript for iTerm (approach \(index + 1)): \(compileError ?? [:])")
                continue
            }

            var errorDict: NSDictionary?
            let result = appleScript.executeAndReturnError(&errorDict)

            if let errorDict = errorDict {
                NSLog("[K8sNN] AppleScript error (iTerm approach \(index + 1)): \(errorDict)")
                if let errorNumber = errorDict["NSAppleScriptErrorNumber"] as? Int {
                    NSLog("[K8sNN] Error number: \(errorNumber)")
                    switch errorNumber {
                    case -1728:
                        NSLog("[K8sNN] iTerm application not found")
                    case -1743:
                        NSLog("[K8sNN] Unknown error - likely permissions issue")
                    case -10810:
                        NSLog("[K8sNN] iTerm application isn't running")
                    default:
                        NSLog("[K8sNN] Other error code: \(errorNumber)")
                    }
                }
                if let errorMessage = errorDict["NSAppleScriptErrorMessage"] as? String {
                    NSLog("[K8sNN] Error message: \(errorMessage)")
                }
                continue // Try next approach
            }

            NSLog("[K8sNN] iTerm AppleScript executed successfully (approach \(index + 1)), result: \(result)")
            return true
        }

        NSLog("[K8sNN] All iTerm approaches failed")
        return false
    }

    private func openTerminalAppWithCommand(_ command: String) -> Bool {
        NSLog("[K8sNN] openTerminalAppWithCommand called with command: \(command)")

        // First try to check if Terminal is running
        let runningApps = NSWorkspace.shared.runningApplications
        let terminalRunning = runningApps.contains { $0.bundleIdentifier == "com.apple.Terminal" }
        NSLog("[K8sNN] Terminal running: \(terminalRunning)")

        // Escape the command properly for AppleScript
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        NSLog("[K8sNN] Executing Terminal AppleScript: \(script)")

        guard let appleScript = NSAppleScript(source: script) else {
            NSLog("[K8sNN] Failed to create AppleScript for Terminal")
            return false
        }

        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            NSLog("[K8sNN] AppleScript error (Terminal): \(errorDict)")
            if let errorNumber = errorDict["NSAppleScriptErrorNumber"] as? Int {
                NSLog("[K8sNN] Error number: \(errorNumber)")
                switch errorNumber {
                case -1728:
                    NSLog("[K8sNN] Terminal application not found")
                case -1743:
                    NSLog("[K8sNN] Unknown error - likely permissions issue")
                case -10810:
                    NSLog("[K8sNN] Terminal application isn't running")
                default:
                    NSLog("[K8sNN] Other error code: \(errorNumber)")
                }
            }
            if let errorMessage = errorDict["NSAppleScriptErrorMessage"] as? String {
                NSLog("[K8sNN] Error message: \(errorMessage)")
            }
            return false
        }

        NSLog("[K8sNN] Terminal AppleScript executed successfully, result: \(result)")
        return true
    }

    // Fallback method using NSWorkspace
    private func openTerminalWithWorkspace() -> Bool {
        NSLog("[K8sNN] Trying fallback method with NSWorkspace")

        // Try to open Terminal.app directly
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSLog("[K8sNN] Found Terminal at: \(terminalURL)")
            do {
                try NSWorkspace.shared.launchApplication(at: terminalURL, options: [], configuration: [:])
                NSLog("[K8sNN] Successfully launched Terminal with NSWorkspace")
                return true
            } catch {
                NSLog("[K8sNN] Failed to launch Terminal with NSWorkspace: \(error)")
            }
        }

        // Try to open iTerm if Terminal failed
        if let itermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
            NSLog("[K8sNN] Found iTerm at: \(itermURL)")
            do {
                try NSWorkspace.shared.launchApplication(at: itermURL, options: [], configuration: [:])
                NSLog("[K8sNN] Successfully launched iTerm with NSWorkspace")
                return true
            } catch {
                NSLog("[K8sNN] Failed to launch iTerm with NSWorkspace: \(error)")
            }
        }

        NSLog("[K8sNN] All fallback methods failed")
        return false
    }
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("hotkeyPressed")
}

// Helper function to create FourCharCode from String
func fourCharCodeFrom(_ string: String) -> FourCharCode {
    let utf8 = Array(string.utf8)
    var result: FourCharCode = 0
    for i in 0..<min(4, utf8.count) {
        result = (result << 8) + FourCharCode(utf8[i])
    }
    return result
}

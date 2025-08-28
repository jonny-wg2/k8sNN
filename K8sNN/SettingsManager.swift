import Foundation
import SwiftUI
import AppKit
import Carbon
import ApplicationServices
import ServiceManagement

enum ClusterSortOrder: String, CaseIterable {
    case connectedFirst = "connected_first"
    case alphabetical = "alphabetical"

    var displayName: String {
        switch self {
        case .connectedFirst:
            return "Connected First"
        case .alphabetical:
            return "Alphabetical"
        }
    }
}

class SettingsManager: ObservableObject {
    @Published var hotkey: String = "⌘⇧K"
    @Published var isHotkeyEnabled: Bool = true
    @Published var multiClusterHotkey: String = "⌘⇧L"
    @Published var isMultiClusterHotkeyEnabled: Bool = true
    @Published var terminalApp: String = "iTerm"
    @Published var customLoginURLs: [String: String] = [:]
    @Published var customCommands: [String: String] = [:]
    @Published var clusterSortOrder: ClusterSortOrder = .connectedFirst
    @Published var menuBarWidth: Double = 420.0
    @Published var menuBarHeight: Double = 500.0
    @Published var preventDeleteCommands: Bool = true
    @Published var defaultCommandType: CommandType = .kubectl
    @Published var autoStartOnLogin: Bool = true

    // Multi-cluster window size settings
    @Published var multiClusterWindowWidth: Double = 1000
    @Published var multiClusterWindowHeight: Double = 700

    private let defaults = UserDefaults.standard
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    init() {
        loadSettings()
        setupHotkey()

        // Set up auto-start on first launch (if setting is enabled)
        if autoStartOnLogin {
            updateLoginItem()
        }
    }
    
    deinit {
        unregisterHotkey()
    }

    func cleanup() {
        unregisterHotkey()
    }
    
    private func loadSettings() {
        hotkey = defaults.string(forKey: "hotkey") ?? "⌘⇧K"

        // Handle boolean defaults properly - UserDefaults.bool returns false for non-existent keys
        if defaults.object(forKey: "isHotkeyEnabled") == nil {
            isHotkeyEnabled = true // Default to enabled
        } else {
            isHotkeyEnabled = defaults.bool(forKey: "isHotkeyEnabled")
        }

        multiClusterHotkey = defaults.string(forKey: "multiClusterHotkey") ?? "⌘⇧L"

        if defaults.object(forKey: "isMultiClusterHotkeyEnabled") == nil {
            isMultiClusterHotkeyEnabled = true // Default to enabled
        } else {
            isMultiClusterHotkeyEnabled = defaults.bool(forKey: "isMultiClusterHotkeyEnabled")
        }

        terminalApp = defaults.string(forKey: "terminalApp") ?? "iTerm"

        // Load custom login URLs
        if let urlData = defaults.data(forKey: "customLoginURLs"),
           let urls = try? JSONDecoder().decode([String: String].self, from: urlData) {
            customLoginURLs = urls
        }

        // Load custom commands
        if let commandData = defaults.data(forKey: "customCommands"),
           let commands = try? JSONDecoder().decode([String: String].self, from: commandData) {
            customCommands = commands
        }

        // Load cluster sort order
        if let sortOrderString = defaults.string(forKey: "clusterSortOrder"),
           let sortOrder = ClusterSortOrder(rawValue: sortOrderString) {
            clusterSortOrder = sortOrder
        }

        // Load safety setting (default to true for safety)
        preventDeleteCommands = defaults.object(forKey: "preventDeleteCommands") as? Bool ?? true

        // Load menu bar width
        let savedWidth = defaults.double(forKey: "menuBarWidth")
        if savedWidth > 0 {
            menuBarWidth = savedWidth
        }

        // Load menu bar height
        let savedHeight = defaults.double(forKey: "menuBarHeight")
        if savedHeight > 0 {
            menuBarHeight = savedHeight
        }

        // Load multi-cluster window size
        let savedMultiClusterWidth = defaults.double(forKey: "multiClusterWindowWidth")
        if savedMultiClusterWidth > 0 {
            multiClusterWindowWidth = savedMultiClusterWidth
        }

        let savedMultiClusterHeight = defaults.double(forKey: "multiClusterWindowHeight")
        if savedMultiClusterHeight > 0 {
            multiClusterWindowHeight = savedMultiClusterHeight
        }

        // Load default command type
        if let commandTypeString = defaults.string(forKey: "defaultCommandType"),
           let commandType = CommandType(rawValue: commandTypeString) {
            defaultCommandType = commandType
        }

        // Load auto-start setting (default to true)
        if defaults.object(forKey: "autoStartOnLogin") == nil {
            autoStartOnLogin = true // Default to enabled
        } else {
            autoStartOnLogin = defaults.bool(forKey: "autoStartOnLogin")
        }
    }
    
    func saveSettings() {
        let oldHotkey = defaults.string(forKey: "hotkey") ?? "⌘⇧K"
        let oldEnabled = defaults.object(forKey: "isHotkeyEnabled") == nil ? true : defaults.bool(forKey: "isHotkeyEnabled")

        defaults.set(hotkey, forKey: "hotkey")
        defaults.set(isHotkeyEnabled, forKey: "isHotkeyEnabled")
        defaults.set(multiClusterHotkey, forKey: "multiClusterHotkey")
        defaults.set(isMultiClusterHotkeyEnabled, forKey: "isMultiClusterHotkeyEnabled")
        defaults.set(terminalApp, forKey: "terminalApp")

        // Save custom login URLs
        if let urlData = try? JSONEncoder().encode(customLoginURLs) {
            defaults.set(urlData, forKey: "customLoginURLs")
        }

        // Save custom commands
        if let commandData = try? JSONEncoder().encode(customCommands) {
            defaults.set(commandData, forKey: "customCommands")
        }

        // Save cluster sort order
        defaults.set(clusterSortOrder.rawValue, forKey: "clusterSortOrder")

        // Save menu bar width
        defaults.set(menuBarWidth, forKey: "menuBarWidth")

        // Save menu bar height
        defaults.set(menuBarHeight, forKey: "menuBarHeight")

        // Save multi-cluster window size
        defaults.set(multiClusterWindowWidth, forKey: "multiClusterWindowWidth")
        defaults.set(multiClusterWindowHeight, forKey: "multiClusterWindowHeight")

        // Save safety setting
        defaults.set(preventDeleteCommands, forKey: "preventDeleteCommands")

        // Save default command type
        defaults.set(defaultCommandType.rawValue, forKey: "defaultCommandType")

        // Save auto-start setting and update login item
        let oldAutoStart = defaults.object(forKey: "autoStartOnLogin") as? Bool ?? true
        defaults.set(autoStartOnLogin, forKey: "autoStartOnLogin")

        // Update login item if auto-start setting changed
        if oldAutoStart != autoStartOnLogin {
            updateLoginItem()
        }

        // Only re-register hotkey if it actually changed
        if oldHotkey != hotkey || oldEnabled != isHotkeyEnabled {
            print("Hotkey settings changed: '\(oldHotkey)' -> '\(hotkey)', enabled: \(oldEnabled) -> \(isHotkeyEnabled)")
            setupHotkey()
        }
    }

    // MARK: - Command Validation

    func validateCommand(_ command: String, type: CommandType) -> (isValid: Bool, errorMessage: String?) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if command is empty
        if trimmedCommand.isEmpty {
            return (false, "Command cannot be empty")
        }

        // Check for delete commands if safety is enabled
        if preventDeleteCommands {
            let commandParts = trimmedCommand.lowercased().components(separatedBy: .whitespaces)
            let dangerousCommands = ["delete", "rm", "remove"]

            for dangerous in dangerousCommands {
                if commandParts.contains(dangerous) {
                    return (false, "Delete commands are disabled for safety. You can enable them in settings.")
                }
            }
        }

        return (true, nil)
    }

    func validateKubectlCommand(_ command: String) -> (isValid: Bool, errorMessage: String?) {
        return validateCommand(command, type: .kubectl)
    }

    func validateFluxCommand(_ command: String) -> (isValid: Bool, errorMessage: String?) {
        return validateCommand(command, type: .flux)
    }

    // MARK: - Custom Login URL Management

    func setCustomLoginURL(for clusterName: String, url: String) {
        if url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customLoginURLs.removeValue(forKey: clusterName)
        } else {
            customLoginURLs[clusterName] = url
        }
        saveSettings()
    }

    func getCustomLoginURL(for clusterName: String) -> String? {
        return customLoginURLs[clusterName]
    }

    func removeCustomLoginURL(for clusterName: String) {
        customLoginURLs.removeValue(forKey: clusterName)
        saveSettings()
    }

    // MARK: - Custom Command Management

    func setCustomCommand(for clusterName: String, command: String) {
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customCommands.removeValue(forKey: clusterName)
        } else {
            customCommands[clusterName] = command
        }
        saveSettings()
    }

    func getCustomCommand(for clusterName: String) -> String? {
        return customCommands[clusterName]
    }

    func removeCustomCommand(for clusterName: String) {
        customCommands.removeValue(forKey: clusterName)
        saveSettings()
    }

    func runCustomCommand(_ command: String) -> Bool {
        NSLog("[K8sNN] Running custom command: \(command)")

        // Use the same terminal opening logic as openTerminalWithContext but with custom command
        func tryITermWithCommand() -> Bool {
            let script = """
            tell application "iTerm"
                activate
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
                    end tell
                end tell
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error == nil {
                    NSLog("[K8sNN] Successfully sent custom command to iTerm")
                    return true
                } else {
                    NSLog("[K8sNN] iTerm AppleScript error: \(error!)")
                }
            }
            return false
        }

        func tryTerminalWithCommand() -> Bool {
            let script = """
            tell application "Terminal"
                activate
                do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error == nil {
                    NSLog("[K8sNN] Successfully sent custom command to Terminal")
                    return true
                } else {
                    NSLog("[K8sNN] Terminal AppleScript error: \(error!)")
                }
            }
            return false
        }

        func tryTerminalWithWorkspace() -> Bool {
            NSLog("[K8sNN] Trying workspace fallback for custom command...")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Terminal"]

            do {
                try task.run()
                NSLog("[K8sNN] Opened Terminal via workspace (command will need to be run manually)")
                return true
            } catch {
                NSLog("[K8sNN] Failed to open Terminal via workspace: \(error)")
                return false
            }
        }

        // Try terminal apps based on preference
        switch terminalApp {
        case "iTerm":
            return tryITermWithCommand() || tryTerminalWithCommand() || tryTerminalWithWorkspace()
        case "Terminal":
            return tryTerminalWithCommand() || tryITermWithCommand() || tryTerminalWithWorkspace()
        default:
            return tryITermWithCommand() || tryTerminalWithCommand() || tryTerminalWithWorkspace()
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

    // MARK: - Command Path Detection

    func findCommandPath(for commandType: CommandType) -> String {
        switch commandType {
        case .kubectl:
            return findKubectlPath()
        case .flux:
            return findFluxPath()
        }
    }

    private func findKubectlPath() -> String {
        // Common kubectl installation paths
        let possiblePaths = [
            "/usr/local/bin/kubectl",
            "/opt/homebrew/bin/kubectl",
            "/usr/bin/kubectl",
            "/bin/kubectl"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find kubectl in PATH
        return findCommandInPath("kubectl") ?? "/usr/local/bin/kubectl"
    }

    private func findFluxPath() -> String {
        // Common flux installation paths
        let possiblePaths = [
            "/usr/local/bin/flux",
            "/opt/homebrew/bin/flux",
            "/usr/bin/flux",
            "/bin/flux"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find flux in PATH
        return findCommandInPath("flux") ?? "/usr/local/bin/flux"
    }

    private func findCommandInPath(_ commandName: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [commandName]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty {
                        return path
                    }
                }
            }
        } catch {
            // Fall back to nil
        }

        return nil
    }

    // MARK: - Auto-Start Functionality

    func updateLoginItem() {
        if autoStartOnLogin {
            enableAutoStart()
        } else {
            disableAutoStart()
        }
    }

    private func enableAutoStart() {
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            do {
                let service = SMAppService.mainApp
                try service.register()
                NSLog("[K8sNN] Successfully enabled auto-start on login using SMAppService")
            } catch {
                NSLog("[K8sNN] Failed to enable auto-start on login: \(error)")
            }
        } else {
            // Fallback to legacy API for older macOS versions
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                NSLog("[K8sNN] Failed to get bundle identifier for auto-start")
                return
            }

            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            if success {
                NSLog("[K8sNN] Successfully enabled auto-start on login using legacy API")
            } else {
                NSLog("[K8sNN] Failed to enable auto-start on login using legacy API")
            }
        }
    }

    private func disableAutoStart() {
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            do {
                let service = SMAppService.mainApp
                try service.unregister()
                NSLog("[K8sNN] Successfully disabled auto-start on login using SMAppService")
            } catch {
                NSLog("[K8sNN] Failed to disable auto-start on login: \(error)")
            }
        } else {
            // Fallback to legacy API for older macOS versions
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                NSLog("[K8sNN] Failed to get bundle identifier for auto-start")
                return
            }

            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
            if success {
                NSLog("[K8sNN] Successfully disabled auto-start on login using legacy API")
            } else {
                NSLog("[K8sNN] Failed to disable auto-start on login using legacy API")
            }
        }
    }

    func isAutoStartEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            let service = SMAppService.mainApp
            return service.status == .enabled
        } else {
            // For older macOS versions, we'll just return the stored setting
            // since checking the actual login items is complex and deprecated
            return autoStartOnLogin
        }
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

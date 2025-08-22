import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var tempHotkey: String = ""
    @State private var isRecordingHotkey = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Hotkey Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkey")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Set a keyboard shortcut to quickly open the cluster selector")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Toggle("Enable hotkey", isOn: $settingsManager.isHotkeyEnabled)
                        .toggleStyle(.switch)
                    
                    Spacer()
                    
                    Button(action: {
                        if isRecordingHotkey {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isRecordingHotkey {
                                Text("Press keys...")
                                    .foregroundStyle(.orange)
                            } else {
                                Text(settingsManager.hotkey)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isRecordingHotkey ? .orange.opacity(0.1) : .secondary.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecordingHotkey ? .orange : .secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!settingsManager.isHotkeyEnabled)
                }
                
                if isRecordingHotkey {
                    Text("Press the key combination you want to use")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 8)
            
            Divider()

            // Terminal Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Terminal Application")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Choose which terminal app to open when switching to authenticated clusters")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Terminal App", selection: $settingsManager.terminalApp) {
                    Text("iTerm").tag("iTerm")
                    Text("Terminal").tag("Terminal")
                }
                .pickerStyle(.segmented)
                .onChange(of: settingsManager.terminalApp) { _, _ in
                    settingsManager.saveSettings()
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Test Terminal Opening
            VStack(alignment: .leading, spacing: 12) {
                Text("Test Terminal Opening")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Test if the terminal opening functionality works")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Test Terminal") {
                        NSLog("[K8sNN] Test button pressed")
                        let result = settingsManager.openTerminalWithContext("test-context")
                        NSLog("[K8sNN] Test result: \(result)")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Simple Test") {
                        NSLog("[K8sNN] Simple test button pressed")
                        // Try to just open Terminal without any commands
                        let script = """
                        tell application "Terminal"
                            activate
                        end tell
                        """

                        if let appleScript = NSAppleScript(source: script) {
                            var errorDict: NSDictionary?
                            let result = appleScript.executeAndReturnError(&errorDict)
                            if let errorDict = errorDict {
                                NSLog("[K8sNN] Simple test error: \(errorDict)")
                            } else {
                                NSLog("[K8sNN] Simple test success: \(result)")
                            }
                        } else {
                            NSLog("[K8sNN] Failed to create simple AppleScript")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Usage Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Use")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("1.")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("Press your hotkey to open the cluster selector")
                    }
                    
                    HStack(spacing: 8) {
                        Text("2.")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("Type to search for clusters")
                    }
                    
                    HStack(spacing: 8) {
                        Text("3.")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("Use ↑↓ arrow keys to navigate")
                    }
                    
                    HStack(spacing: 8) {
                        Text("4.")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("Press Enter to authenticate or open terminal")
                    }
                    
                    HStack(spacing: 8) {
                        Text("5.")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("Press Escape to close")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 420)
        .background(.regularMaterial)
        .onAppear {
            tempHotkey = settingsManager.hotkey
        }
        .onChange(of: settingsManager.isHotkeyEnabled) { _, _ in
            settingsManager.saveSettings()
        }
    }
    
    private func startRecording() {
        isRecordingHotkey = true
        tempHotkey = ""
        
        // Set up key monitoring
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if isRecordingHotkey {
                handleKeyEvent(event)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecordingHotkey = false
        if !tempHotkey.isEmpty {
            settingsManager.hotkey = tempHotkey
            settingsManager.saveSettings()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var hotkeyString = ""
        
        // Add modifier symbols
        if modifierFlags.contains(.command) {
            hotkeyString += "⌘"
        }
        if modifierFlags.contains(.shift) {
            hotkeyString += "⇧"
        }
        if modifierFlags.contains(.option) {
            hotkeyString += "⌥"
        }
        if modifierFlags.contains(.control) {
            hotkeyString += "⌃"
        }
        
        // Add the key character
        if event.type == .keyDown {
            if let characters = event.charactersIgnoringModifiers?.uppercased() {
                hotkeyString += characters
                tempHotkey = hotkeyString
                
                // Stop recording after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    stopRecording()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}

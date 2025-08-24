import SwiftUI

struct SettingsMenuView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var tempHotkey: String = ""
    @State private var isRecordingHotkey = false
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with glass effect
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.blue.gradient)
                    .font(.title2)
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                GlassButton(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
                .help("Close settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
            
            // Settings content with glass background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hotkey Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Global Hotkey")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Set a keyboard shortcut to quickly open the cluster selector")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            Toggle("Enable hotkey", isOn: $settingsManager.isHotkeyEnabled)
                                .toggleStyle(.switch)
                                .onChange(of: settingsManager.isHotkeyEnabled) { _, _ in
                                    settingsManager.saveSettings()
                                }
                            
                            HotkeyRecordButton(
                                isRecording: isRecordingHotkey,
                                hotkey: settingsManager.hotkey,
                                action: {
                                    if isRecordingHotkey {
                                        stopRecording()
                                    } else {
                                        startRecording()
                                    }
                                }
                            )
                            .buttonStyle(.plain)
                            .disabled(!settingsManager.isHotkeyEnabled)
                            
                            if isRecordingHotkey {
                                Text("Press the key combination you want to use")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Terminal Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Terminal Application")
                            .font(.subheadline)
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
                    
                    Divider()
                    
                    // Usage Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Use")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            instructionRow("1.", "Press your hotkey to open the cluster selector")
                            instructionRow("2.", "Type to search for clusters")
                            instructionRow("3.", "Use ↑↓ arrow keys to navigate")
                            instructionRow("4.", "Press Enter to authenticate or open terminal")
                            instructionRow("5.", "Press Escape to close")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
        }
        .onAppear {
            tempHotkey = settingsManager.hotkey
        }
    }
    
    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            Text(text)
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

// MARK: - Hotkey Record Button Component
struct HotkeyRecordButton: View {
    let isRecording: Bool
    let hotkey: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRecording {
                    Text("Press keys...")
                        .foregroundStyle(.orange)
                } else {
                    Text(hotkey)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundFill)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderStroke, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundFill: Color {
        if isRecording {
            return .orange.opacity(isHovered ? 0.15 : 0.1)
        } else {
            return .secondary.opacity(isHovered ? 0.15 : 0.1)
        }
    }

    private var borderStroke: Color {
        if isRecording {
            return .orange.opacity(isHovered ? 0.8 : 0.6)
        } else {
            return .secondary.opacity(isHovered ? 0.5 : 0.3)
        }
    }
}

#Preview {
    SettingsMenuView(onClose: {})
        .environmentObject(SettingsManager())
        .frame(width: 340)
}

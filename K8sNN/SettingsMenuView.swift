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
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
                .help("Back to main menu")
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

                    // Multi-Cluster kubectl Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Multi-Cluster kubectl")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Multi-cluster kubectl functionality is now integrated into the main spotlight interface. Use the toggle at the top to switch between cluster selection and multi-cluster kubectl modes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Safety Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Safety & Security")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Configure safety features for multi-cluster kubectl commands")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Toggle("Prevent delete commands", isOn: $settingsManager.preventDeleteCommands)
                                .toggleStyle(.switch)
                                .onChange(of: settingsManager.preventDeleteCommands) { _, _ in
                                    settingsManager.saveSettings()
                                }

                            Spacer()

                            if settingsManager.preventDeleteCommands {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("Protected")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("Unprotected")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        Text("When enabled, commands containing 'delete', 'rm', or 'remove' will be blocked to prevent accidental data loss.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Menu Bar Size Settings
                    MenuBarSizeSettings()

                    Divider()

                    // Cluster Sorting Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cluster Sorting")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Choose how clusters are ordered in the menu and spotlight")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Sort Order", selection: $settingsManager.clusterSortOrder) {
                            ForEach(ClusterSortOrder.allCases, id: \.self) { sortOrder in
                                Text(sortOrder.displayName).tag(sortOrder)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: settingsManager.clusterSortOrder) { _, _ in
                            settingsManager.saveSettings()
                        }
                    }

                    Divider()

                    // Custom Login URLs
                    CustomLoginURLsSection()

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

// MARK: - Custom Login URLs Section
struct CustomLoginURLsSection: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var kubernetesManager: KubernetesManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cluster Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Customize login URLs and commands for clusters. Configure SSH tunnels or other setup commands.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if kubernetesManager.clusters.isEmpty {
                Text("No clusters found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(kubernetesManager.sortedClusters(using: settingsManager.clusterSortOrder)) { cluster in
                        ClusterLoginURLRow(cluster: cluster)
                    }
                }
            }
        }
    }
}

// MARK: - Cluster Login URL Row
struct ClusterLoginURLRow: View {
    let cluster: KubernetesCluster
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var editedURL: String = ""
    @State private var editedCommand: String = ""
    @State private var isEditingURL = false
    @State private var isEditingCommand = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cluster name and status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if cluster.usesDexAuth(using: settingsManager) {
                        Text("Dex Authentication")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Local cluster")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Spacer()

                // Reset button for custom URLs
                if settingsManager.getCustomLoginURL(for: cluster.name) != nil {
                    GlassButton(action: {
                        settingsManager.removeCustomLoginURL(for: cluster.name)
                        editedURL = cluster.autoGeneratedLoginURL ?? ""
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .help("Reset to auto-generated URL")
                }
            }

            // URL input field - always show for all clusters
            if true { // Always show login URL option
                VStack(alignment: .leading, spacing: 4) {
                    Text("Login URL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        TextField("Login URL", text: $editedURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit {
                                saveURL()
                            }
                            .onChange(of: editedURL) { _, newValue in
                                if newValue != currentDisplayURL {
                                    isEditingURL = true
                                } else {
                                    isEditingURL = false
                                }
                            }

                        if isEditingURL {
                            GlassButton(action: saveURL) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                            .help("Save URL")
                        }
                    }
                }
            }

            // Command input field
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Command (e.g. ssh proxy)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    TextField("ssh -N -L 6443:10.1.2.3:6443 server.com", text: $editedCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            saveCommand()
                        }
                        .onChange(of: editedCommand) { _, newValue in
                            if newValue != currentDisplayCommand {
                                isEditingCommand = true
                            } else {
                                isEditingCommand = false
                            }
                        }

                    if isEditingCommand {
                        GlassButton(action: saveCommand) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green)
                        }
                        .help("Save Command")
                    }

                    if settingsManager.getCustomCommand(for: cluster.name) != nil {
                        GlassButton(action: {
                            settingsManager.removeCustomCommand(for: cluster.name)
                            editedCommand = ""
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .help("Remove Custom Command")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? .blue.opacity(0.03) : .secondary.opacity(0.03))
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            editedURL = currentDisplayURL
            editedCommand = currentDisplayCommand
        }
    }

    private var currentDisplayURL: String {
        return cluster.loginURL(using: settingsManager) ?? ""
    }

    private var currentDisplayCommand: String {
        return settingsManager.getCustomCommand(for: cluster.name) ?? ""
    }

    private func saveURL() {
        let trimmedURL = editedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            settingsManager.removeCustomLoginURL(for: cluster.name)
            editedURL = cluster.autoGeneratedLoginURL ?? ""
        } else {
            settingsManager.setCustomLoginURL(for: cluster.name, url: trimmedURL)
        }
        isEditingURL = false
    }

    private func saveCommand() {
        let trimmedCommand = editedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsManager.setCustomCommand(for: cluster.name, command: trimmedCommand)
        isEditingCommand = false
    }
}

// MARK: - Menu Bar Size Settings
struct MenuBarSizeSettings: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showSavedNotification = false
    @State private var notificationTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Size")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Adjust the width and height of the menu bar popup")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                // Width controls
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Width: \(Int(settingsManager.menuBarWidth))px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)

                        Spacer()

                        if showSavedNotification {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("Saved")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .fontWeight(.medium)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        Button("Reset") {
                            settingsManager.menuBarWidth = 420.0
                            settingsManager.menuBarHeight = 500.0
                            settingsManager.saveSettings()
                            showSaveNotification()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    Slider(value: $settingsManager.menuBarWidth, in: 300...600, step: 10)
                        .onChange(of: settingsManager.menuBarWidth) { _, _ in
                            settingsManager.saveSettings()
                            showSaveNotification()
                        }
                }

                // Height controls
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Height: \(Int(settingsManager.menuBarHeight))px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)

                        Spacer()
                    }

                    Slider(value: $settingsManager.menuBarHeight, in: 300...800, step: 10)
                        .onChange(of: settingsManager.menuBarHeight) { _, _ in
                            settingsManager.saveSettings()
                            showSaveNotification()
                        }
                }
            }
        }
    }

    private func showSaveNotification() {
        // Cancel existing timer
        notificationTimer?.invalidate()

        // Show notification with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            showSavedNotification = true
        }

        // Hide after 2 seconds
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showSavedNotification = false
            }
        }
    }
}

#Preview {
    SettingsMenuView(onClose: {})
        .environmentObject(SettingsManager())
        .frame(width: 340)
}

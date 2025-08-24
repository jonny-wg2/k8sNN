import SwiftUI
import AppKit

class SpotlightOverlayWindow: NSWindow {
    private var clickOutsideMonitor: Any?
    private var localMonitor: Any?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.canHide = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Center the window on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = self.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2 + 100 // Slightly above center like Spotlight
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }

        setupEventMonitors()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    private func setupEventMonitors() {
        // Monitor for clicks outside the window
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }

            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = self.frame

            // Check if click is outside our window
            if !windowFrame.contains(mouseLocation) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .hideSpotlight, object: "clickOutside")
                }
            }
        }

        // Monitor for local events (like Escape key)
        // Note: Don't handle Cmd+Shift+K here as it's handled by the global hotkey
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Handle Escape key
            if event.keyCode == 53 { // Escape key
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .hideSpotlight, object: "escKey")
                }
                return nil // Consume the event
            }

            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        removeEventMonitors()
    }

    override func close() {
        print("SpotlightOverlayWindow.close() called")
        removeEventMonitors()
        super.close()
    }

    override func resignKey() {
        super.resignKey()
        // Don't automatically close when window loses focus
        // Let the hotkey control the toggle behavior
        print("SpotlightOverlayWindow.resignKey() called - not auto-closing")
    }
}

struct SpotlightOverlay: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchBarHovered = false

    var filteredClusters: [KubernetesCluster] {
        let all = kubernetesManager.sortedClusters(using: settingsManager.clusterSortOrder)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return all }

        let normalized = query.folding(options: .diacriticInsensitive, locale: .current)
        return all.filter { cluster in
            cluster.name.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title2)

                TextField("Search clusters...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($isSearchFocused)
                    .onSubmit {
                        authenticateSelectedCluster()
                    }

                if !searchText.isEmpty {
                    CompactGlassButton(action: {
                        searchText = ""
                        selectedIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(searchBarBorderColor, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.2), value: isSearchBarHovered)
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            )
            .scaleEffect(isSearchBarHovered ? 1.005 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSearchBarHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchBarHovered = hovering
                }
            }

            if !filteredClusters.isEmpty {
                // Results list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(filteredClusters.enumerated()), id: \.element.id) { index, cluster in
                                SpotlightClusterRow(
                                    cluster: cluster,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        selectedIndex = index
                                        authenticateSelectedCluster()
                                    }
                                )
                                .id(cluster.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 300)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard newIndex >= 0 && newIndex < filteredClusters.count else { return }
                        let targetId = filteredClusters[newIndex].id
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 600, height: 400)
        .background(.clear)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in
            if selectedIndex >= filteredClusters.count {
                selectedIndex = max(0, filteredClusters.count - 1)
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredClusters.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            authenticateSelectedCluster()
            return .handled
        }
        .onKeyPress(.escape) {
            NotificationCenter.default.post(name: .hideSpotlight, object: "escKeySwiftUI")
            return .handled
        }
    }

    // Computed property for search bar border color
    private var searchBarBorderColor: Color {
        if isSearchFocused {
            return .blue.opacity(0.4)
        } else if isSearchBarHovered {
            return .blue.opacity(0.2)
        } else {
            return .clear
        }
    }

    private func authenticateSelectedCluster() {
        NSLog("[K8sNN] authenticateSelectedCluster() called")
        guard selectedIndex < filteredClusters.count else {
            NSLog("[K8sNN] selectedIndex \(selectedIndex) >= filteredClusters.count \(filteredClusters.count)")
            return
        }
        let cluster = filteredClusters[selectedIndex]

        // Check for option key modifier
        let useSecondary = NSEvent.modifierFlags.contains(.option)
        let primaryAction = cluster.primaryActionType(using: settingsManager)
        let secondaryAction = cluster.secondaryActionType(using: settingsManager)

        let actionToExecute = useSecondary ? (secondaryAction ?? primaryAction) : primaryAction

        NSLog("[K8sNN] Spotlight selected cluster: name=\(cluster.name), actionType=\(actionToExecute), useSecondary=\(useSecondary)")

        switch actionToExecute {
        case .openTerminal:
            NSLog("[K8sNN] Attempting to open terminal for context \(cluster.name)")
            let ok = settingsManager.openTerminalWithContext(cluster.name)
            NSLog("[K8sNN] openTerminalWithContext returned: \(ok)")

        case .runCommand:
            if let command = settingsManager.getCustomCommand(for: cluster.name) {
                NSLog("[K8sNN] Running custom command for cluster \(cluster.name): \(command)")
                let success = settingsManager.runCustomCommand(command)
                NSLog("[K8sNN] runCustomCommand returned: \(success)")
            }

        case .openLoginURL:
            NSLog("[K8sNN] Opening login page for unauthenticated cluster \(cluster.name)")
            kubernetesManager.openLoginPage(for: cluster, using: settingsManager)

        case .none:
            NSLog("[K8sNN] No action available for cluster \(cluster.name)")
        }

        // Hide the overlay after action
        NSLog("[K8sNN] Hiding spotlight overlay")
        NotificationCenter.default.post(name: .hideSpotlight, object: nil)
    }
}

struct SpotlightClusterRow: View {
    let cluster: KubernetesCluster
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Status indicator with enhanced glow on hover
                Circle()
                    .fill(cluster.isAuthenticated ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: cluster.isAuthenticated ? .green.opacity(0.4) : .red.opacity(0.4),
                        radius: (isSelected || isHovered) ? 4 : 3,
                        x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(cluster.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if cluster.usesDexAuth(using: settingsManager) {
                        Text(cluster.clusterName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Local cluster")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Spacer()

                // Status text and action with hover effects
                VStack(alignment: .trailing, spacing: 2) {
                    let primaryAction = cluster.primaryActionType(using: settingsManager)
                    let hasSecondary = cluster.hasSecondaryAction(using: settingsManager)

                    // Primary action
                    HStack(spacing: 4) {
                        switch primaryAction {
                        case .openTerminal:
                            Text("Open Terminal")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                                .opacity((isSelected || isHovered) ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                            Image(systemName: "terminal.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.blue)
                                .scaleEffect((isSelected || isHovered) ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                        case .runCommand:
                            Text("Run Command")
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .fontWeight(.medium)
                                .opacity((isSelected || isHovered) ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.purple)
                                .scaleEffect((isSelected || isHovered) ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                        case .openLoginURL:
                            Text("Login Required")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                                .opacity((isSelected || isHovered) ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.blue)
                                .scaleEffect((isSelected || isHovered) ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)

                        case .none:
                            Text("No Action")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                                .opacity((isSelected || isHovered) ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)
                        }
                    }

                    // Secondary action indicator
                    if hasSecondary {
                        if let secondaryAction = cluster.secondaryActionType(using: settingsManager) {
                            HStack(spacing: 4) {
                                switch secondaryAction {
                                case .runCommand:
                                    Text("⌥ Run Command")
                                        .font(.caption2)
                                        .foregroundStyle(.purple.opacity(0.7))
                                        .fontWeight(.medium)
                                        .opacity((isSelected || isHovered) ? 1.0 : 0.6)
                                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)

                                case .openLoginURL:
                                    Text("⌥ Open Login")
                                        .font(.caption2)
                                        .foregroundStyle(.orange.opacity(0.7))
                                        .fontWeight(.medium)
                                        .opacity((isSelected || isHovered) ? 1.0 : 0.6)
                                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)

                                default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundFill)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderStroke, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    // Computed properties for elegant glass hover effects
    private var backgroundFill: Color {
        if isSelected {
            return .blue.opacity(0.15)
        } else if isHovered {
            return .blue.opacity(0.08)
        } else {
            return .clear
        }
    }

    private var borderStroke: Color {
        if isSelected {
            return .blue.opacity(0.3)
        } else if isHovered {
            return .blue.opacity(0.2)
        } else {
            return .clear
        }
    }
}

extension Notification.Name {
    static let hideSpotlight = Notification.Name("hideSpotlight")
}

import SwiftUI
import AppKit

// MARK: - Visual Effect View Wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Glass Card Component

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let material: NSVisualEffectView.Material
    let borderOpacity: Double
    let shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = 16,
        material: NSVisualEffectView.Material = .hudWindow,
        borderOpacity: Double = 0.2,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.borderOpacity = borderOpacity
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                VisualEffectView(material: material)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: shadowRadius/2)
    }
}

// MARK: - Glass Input Field Component

struct GlassTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool

    init(_ title: String, text: Binding<String>, placeholder: String = "", isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                VisualEffectView(material: .menu, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Glass Button Component
struct GlassButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    @State private var isHovered = false
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? .blue.opacity(0.08) : .clear)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? .blue.opacity(0.15) : .clear, lineWidth: 0.5)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Convenience initializer for text buttons
extension GlassButton where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - Compact Glass Button (for smaller spaces like search bar)
struct CompactGlassButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    @State private var isHovered = false
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .blue.opacity(0.08) : .clear)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? .blue.opacity(0.15) : .clear, lineWidth: 0.5)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Multi-Cluster Command Components

struct SimpleMultiClusterView: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var commandText: String = ""
    @State private var results: [ClusterResult] = []
    @State private var isExecuting: Bool = false
    @State private var validationError: String? = nil

    var authenticatedClusters: [KubernetesCluster] {
        kubernetesManager.clusters.filter { $0.isAuthenticated }
    }

    var body: some View {
        GlassCard(
            cornerRadius: 24,
            material: .hudWindow,
            borderOpacity: 0.3,
            shadowRadius: 20
        ) {
            VStack(spacing: 0) {
                headerView

                VStack(spacing: 20) {
                    commandInputView
                    executeButtonView
                    resultsView
                }
                .padding(24)
            }
            .frame(width: 800, height: 700)
        }
        .onAppear {
            // Initialize validation when view appears
            validateCommand(commandText)
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.blue.gradient)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi-Cluster kubectl")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Execute commands across multiple clusters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(authenticatedClusters.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)

                Text("active clusters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            VisualEffectView(material: .menu, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var commandInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Command")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if settingsManager.preventDeleteCommands {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Delete protection enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 0) {
                Text("kubectl")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
                    .padding(.leading, 16)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("get pods --all-namespaces", text: $commandText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(validationError != nil ? .red.opacity(0.5) : .clear, lineWidth: 1)
                    )
                    .onChange(of: commandText) { _, newValue in
                        validateCommand(newValue)
                    }
            }
            .background(
                VisualEffectView(material: .menu, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )

            if let error = validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }

    private var executeButtonView: some View {
        HStack {
            if isExecuting {
                HStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Executing on \(authenticatedClusters.count) clusters...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Running commands in parallel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    VisualEffectView(material: .menu, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.blue.opacity(0.4), lineWidth: 1)
                )
            } else {
                Spacer()

                Button(action: executeCommand) {
                    HStack(spacing: 10) {
                        Image(systemName: canExecute ? "play.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .semibold))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Execute Command")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("on \(authenticatedClusters.count) clusters")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(canExecute ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.gray))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: canExecute ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!canExecute)
                .buttonStyle(.plain)
                .scaleEffect(canExecute ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: canExecute)
            }
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !results.isEmpty {
                Text("Results")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { result in
                            ClusterResultView(result: result)
                        }
                    }
                }
            }
        }
    }

    private var canExecute: Bool {
        !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !authenticatedClusters.isEmpty &&
        !isExecuting &&
        validationError == nil
    }

    private func validateCommand(_ command: String) {
        guard !command.isEmpty else {
            validationError = nil
            return
        }

        let validation = settingsManager.validateKubectlCommand(command)
        validationError = validation.isValid ? nil : validation.errorMessage
    }

    private func executeCommand() {
        let trimmedCommand = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        isExecuting = true
        results = []

        // Create initial results for all clusters
        results = authenticatedClusters.map { cluster in
            ClusterResult(clusterName: cluster.name, command: trimmedCommand, status: .running)
        }

        // Execute commands in parallel
        for (index, cluster) in authenticatedClusters.enumerated() {
            executeCommandOnCluster(cluster: cluster, command: trimmedCommand, resultIndex: index)
        }
    }

    private func executeCommandOnCluster(cluster: KubernetesCluster, command: String, resultIndex: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: findKubectlPath())
            process.arguments = ["--context", cluster.name] + command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let startTime = Date()

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                let duration = Date().timeIntervalSince(startTime)

                DispatchQueue.main.async {
                    if resultIndex < self.results.count {
                        self.results[resultIndex].output = output
                        self.results[resultIndex].errorOutput = errorOutput
                        self.results[resultIndex].duration = duration
                        self.results[resultIndex].status = process.terminationStatus == 0 ? .success : .failed

                        // Check if all commands are done
                        if self.results.allSatisfy({ $0.status != .running }) {
                            self.isExecuting = false
                        }
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    if resultIndex < self.results.count {
                        self.results[resultIndex].errorOutput = "Failed to execute: \(error.localizedDescription)"
                        self.results[resultIndex].status = .failed
                        self.results[resultIndex].duration = Date().timeIntervalSince(startTime)

                        // Check if all commands are done
                        if self.results.allSatisfy({ $0.status != .running }) {
                            self.isExecuting = false
                        }
                    }
                }
            }
        }
    }

    private func findKubectlPath() -> String {
        let commonPaths = [
            "/usr/local/bin/kubectl",
            "/opt/homebrew/bin/kubectl",
            "/usr/bin/kubectl"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "/usr/local/bin/kubectl" // fallback
    }
}

struct ClusterResult: Identifiable {
    let id = UUID()
    let clusterName: String
    let command: String
    var output: String = ""
    var errorOutput: String = ""
    var status: ResultStatus = .running
    var duration: TimeInterval = 0

    enum ResultStatus {
        case running, success, failed
    }

    var displayOutput: String {
        if !output.isEmpty {
            return output
        } else if !errorOutput.isEmpty {
            return errorOutput
        } else {
            return "No output"
        }
    }
}

struct ClusterResultView: View {
    let result: ClusterResult
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 14, weight: .medium))

                Text(result.clusterName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if result.duration > 0 {
                    Text("(\(String(format: "%.1fs", result.duration)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            // Content
            if isExpanded && !result.displayOutput.isEmpty {
                ScrollView {
                    Text(result.displayOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .background(
            VisualEffectView(material: .menu, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var statusIcon: String {
        switch result.status {
        case .running:
            return "clock"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .running:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
}

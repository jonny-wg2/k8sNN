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

// MARK: - Floating Multi-Cluster kubectl Interface

struct FloatingMultiClusterView: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var commandText: String = ""
    @State private var results: [ClusterResult] = []
    @State private var isExecuting: Bool = false
    @State private var validationError: String? = nil
    @Environment(\.dismiss) private var dismiss

    var authenticatedClusters: [KubernetesCluster] {
        kubernetesManager.clusters.filter { $0.isAuthenticated }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Command input bar (similar to spotlight search)
            commandInputBar

            // Results grid
            if !results.isEmpty {
                resultsGrid
            }
        }
        .padding(24)
        .frame(width: 800)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .onAppear {
            validateCommand(commandText)
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private var commandInputBar: some View {
        HStack(spacing: 0) {
            // kubectl prefix
            Text("kubectl")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.blue)
                .fontWeight(.semibold)
                .padding(.leading, 20)
                .padding(.vertical, 16)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Command input
            TextField("get pods --all-namespaces", text: $commandText)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .monospaced))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(validationError != nil ? .red.opacity(0.5) : .clear, lineWidth: 1)
                )
                .onChange(of: commandText) { _, newValue in
                    validateCommand(newValue)
                }
                .onSubmit {
                    if canExecute {
                        executeCommand()
                    }
                }

            // Execute button
            if isExecuting {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.blue)
                    Text("Running...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Button(action: executeCommand) {
                    HStack(spacing: 8) {
                        Image(systemName: canExecute ? "play.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Execute")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canExecute ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.gray))
                    )
                }
                .disabled(!canExecute)
                .buttonStyle(.plain)
                .scaleEffect(canExecute ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: canExecute)
            }
        }
        .background(
            VisualEffectView(material: .menu, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(results) { result in
                FloatingClusterResultView(result: result)
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

struct FloatingClusterResultView: View {
    let result: ClusterResult
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 16, weight: .medium))

                Text(result.clusterName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if result.duration > 0 {
                    Text("\(String(format: "%.1fs", result.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // Content
            if !result.displayOutput.isEmpty {
                ScrollView {
                    Text(result.displayOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            VisualEffectView(material: .menu, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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
            borderOpacity: 0.0, // Remove border
            shadowRadius: 20
        ) {
            VStack(spacing: 0) {
                headerView

                VStack(spacing: 20) {
                    commandInputView
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
            Image(systemName: "terminal.fill")
                .foregroundStyle(.blue.gradient)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Show cluster names
            HStack(spacing: 12) {
                ForEach(authenticatedClusters.prefix(3), id: \.name) { cluster in
                    Text(cluster.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.blue.opacity(0.3), lineWidth: 0.5)
                        )
                }

                if authenticatedClusters.count > 3 {
                    Text("+\(authenticatedClusters.count - 3)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            VisualEffectView(material: .menu, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
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
                    .onSubmit {
                        if canExecute {
                            executeCommand()
                        }
                    }

                // Execute button in the command bar
                if isExecuting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.blue)
                        Text("Running...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Button(action: executeCommand) {
                        HStack(spacing: 6) {
                            Image(systemName: canExecute ? "play.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Execute")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canExecute ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.gray))
                        )
                    }
                    .disabled(!canExecute)
                    .buttonStyle(.plain)
                    .scaleEffect(canExecute ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: canExecute)
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

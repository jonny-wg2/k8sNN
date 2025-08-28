import SwiftUI
import Foundation

struct SimpleMultiClusterView: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var commandText: String = ""
    @State private var results: [ClusterResult] = []
    @State private var isExecuting: Bool = false
    @State private var selectedCommandType: CommandType = .kubectl

    var authenticatedClusters: [KubernetesCluster] {
        kubernetesManager.clusters.filter { $0.isAuthenticated }
    }

    var body: some View {
        VStack(spacing: 16) {
            headerView
            commandInputView
            executeButtonView
            resultsView
        }
        .padding(20)
        .frame(width: settingsManager.multiClusterWindowWidth, height: settingsManager.multiClusterWindowHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Glass Chip helper for readability
    private func GlassChip(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(Capsule())
            )
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.blue.gradient)
                .font(.title2)

            Text("Multi-Cluster kubectl")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(Capsule())
                )

            Spacer()

            Text("\(authenticatedClusters.count) active clusters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var commandInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command")
                GlassChip("Target Clusters")
                GlassButton("Select All") {
                    if authenticatedClusters.count == results.count { /* noop in simple view */ }
                }
                .font(.caption)
                .foregroundStyle(.blue)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(authenticatedClusters, id: \.id) { cluster in
                            Text(cluster.name)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                }

                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                // Elegant command type selector with liquid glass effect
                Menu {
                    ForEach(CommandType.allCases, id: \.self) { commandType in
                        Button(action: {
                            selectedCommandType = commandType
                        }) {
                            HStack {
                                Text(commandType.displayName)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                Spacer()
                                if selectedCommandType == commandType {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                if selectedCommandType == commandType {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.blue.opacity(0.1))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(selectedCommandType.displayName)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .scaleEffect(0.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.secondary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.secondary.opacity(0.1), lineWidth: 0.5)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .secondary.opacity(0.05), radius: 4, x: 0, y: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .padding(.leading, 4)

                TextField(selectedCommandType.placeholderCommand, text: $commandText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.tertiary, lineWidth: 1)
                    )
            }
        }
    }

    private var executeButtonView: some View {
        HStack {
            if isExecuting {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)

                    Text("Executing on \(authenticatedClusters.count) clusters...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Spacer()

                Button(action: executeCommand) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Execute on \(authenticatedClusters.count) clusters")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canExecute ? .blue.gradient : .gray.gradient)
                    )
                }
                .disabled(!canExecute)
                .buttonStyle(.plain)
            }
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !results.isEmpty {
                GeometryReader { geo in
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    let rows = max(1, Int(ceil(Double(results.count) / 2.0)))
                    let verticalSpacing: CGFloat = 12
                    let totalSpacing = CGFloat(max(0, rows - 1)) * verticalSpacing
                    let availableHeight = max(0, geo.size.height - totalSpacing)
                    let cardHeight = max(140, availableHeight / CGFloat(rows))

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: verticalSpacing) {
                            ForEach(results) { result in
                                ClusterResultView(result: result)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: cardHeight)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }

    private var canExecute: Bool {
        !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !authenticatedClusters.isEmpty &&
        !isExecuting
    }

    private func executeCommand() {
        let trimmedCommand = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        isExecuting = true
        results = []

        // Create initial results for all clusters
        results = authenticatedClusters.map { cluster in
            ClusterResult(clusterName: cluster.name, command: trimmedCommand, commandType: selectedCommandType, status: .running)
        }

        // Execute commands in parallel
        for (index, cluster) in authenticatedClusters.enumerated() {
            executeCommandOnCluster(cluster: cluster, command: trimmedCommand, resultIndex: index, commandType: selectedCommandType)
        }
    }

    private func executeCommandOnCluster(cluster: KubernetesCluster, command: String, resultIndex: Int, commandType: CommandType) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let commandPath = self.settingsManager.findCommandPath(for: commandType)
            process.executableURL = URL(fileURLWithPath: commandPath)

            // Build arguments based on command type
            let commandComponents = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            var args: [String] = []

            switch commandType {
            case .kubectl:
                args = ["--context", cluster.name] + commandComponents
            case .flux:
                args = ["--context", cluster.name] + commandComponents
            }

            process.arguments = args

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
        // Common kubectl locations
        let commonPaths = [
            "/usr/local/bin/kubectl",
            "/opt/homebrew/bin/kubectl",
            "/usr/bin/kubectl",
            "/bin/kubectl"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find kubectl in PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["kubectl"]

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
            // Fall back to default
        }

        // Default fallback
        return "/usr/local/bin/kubectl"
    }
}

struct ClusterResult: Identifiable {
    let id = UUID()
    let clusterName: String
    let command: String
    let commandType: CommandType
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
                .frame(minHeight: 120)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.tertiary.opacity(0.5), lineWidth: 1)
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

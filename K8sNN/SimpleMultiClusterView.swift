import SwiftUI
import Foundation

struct SimpleMultiClusterView: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @State private var commandText: String = ""
    @State private var results: [ClusterResult] = []
    @State private var isExecuting: Bool = false
    
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
        .frame(width: 700, height: 600)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.blue.gradient)
                .font(.title2)
            
            Text("Multi-Cluster kubectl")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text("\(authenticatedClusters.count) active clusters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var commandInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Text("kubectl")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                TextField("get pods", text: $commandText)
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
        !isExecuting
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

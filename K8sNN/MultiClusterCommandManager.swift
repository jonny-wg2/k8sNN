import Foundation
import Combine

class MultiClusterCommandManager: ObservableObject {
    @Published var currentSession: CommandExecutionSession?
    @Published var commandHistory: [MultiClusterCommand] = []
    @Published var isExecuting: Bool = false
    
    private let kubernetesManager: KubernetesManager
    private var cancellables = Set<AnyCancellable>()
    private var executionTasks: [Task<Void, Never>] = []
    
    // Configuration
    var maxConcurrentExecutions: Int = 10
    var defaultTimeout: TimeInterval = 30.0
    var maxHistoryItems: Int = 50
    
    init(kubernetesManager: KubernetesManager) {
        self.kubernetesManager = kubernetesManager
        loadCommandHistory()
    }
    
    // MARK: - Command Execution
    
    func executeCommand(_ command: String, on clusterNames: [String], commandType: CommandType = .kubectl) {
        guard !isExecuting else {
            NSLog("[MultiClusterCommandManager] Already executing a command")
            return
        }

        guard !clusterNames.isEmpty else {
            NSLog("[MultiClusterCommandManager] No clusters selected")
            return
        }

        NSLog("[MultiClusterCommandManager] Executing \(commandType.displayName) command '\(command)' on \(clusterNames.count) clusters")

        let multiClusterCommand = MultiClusterCommand(command: command, targetClusters: clusterNames, commandType: commandType)
        let session = CommandExecutionSession(command: command, targetClusters: clusterNames, commandType: commandType)

        // Update state
        isExecuting = true
        currentSession = session

        // Add to history
        addToHistory(multiClusterCommand)

        // Execute in parallel
        executeCommandInParallel(session: session)
    }
    
    private func executeCommandInParallel(session: CommandExecutionSession) {
        let semaphore = DispatchSemaphore(value: maxConcurrentExecutions)
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "com.k8snn.multicluster.results", attributes: .concurrent)
        
        for clusterName in session.targetClusters {
            group.enter()
            
            let task = Task {
                semaphore.wait()
                defer {
                    semaphore.signal()
                    group.leave()
                }
                
                let result = await executeCommandOnCluster(
                    command: session.command,
                    clusterName: clusterName,
                    commandType: session.commandType
                )
                
                await MainActor.run {
                    if let currentSession = self.currentSession,
                       currentSession.id == session.id {
                        self.currentSession?.results.append(result)
                        self.updateSessionProgress()
                    }
                }
            }
            
            executionTasks.append(task)
        }
        
        // Wait for all tasks to complete
        Task {
            group.wait()
            
            await MainActor.run {
                self.completeExecution()
            }
        }
    }
    
    private func executeCommandOnCluster(command: String, clusterName: String, commandType: CommandType) async -> ClusterCommandResult {
        var result = ClusterCommandResult(clusterName: clusterName, command: command, commandType: commandType)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let commandPath = self.findCommandPath(for: commandType)
                process.executableURL = URL(fileURLWithPath: commandPath)

                // Parse command and build arguments
                let commandComponents = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                var args: [String] = []

                // Add context argument for kubectl, namespace for flux
                switch commandType {
                case .kubectl:
                    args = ["--context", clusterName]
                    args.append(contentsOf: commandComponents)
                    args.append("--request-timeout=\(Int(self.defaultTimeout))s")
                case .flux:
                    // Flux uses --context for kubeconfig context
                    args = ["--context", clusterName]
                    args.append(contentsOf: commandComponents)
                    args.append("--timeout=\(Int(self.defaultTimeout))s")
                }

                process.arguments = args
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    
                    // Set up timeout
                    let timeoutTask = DispatchWorkItem {
                        if process.isRunning {
                            process.terminate()
                            result.status = .timeout
                            result.errorOutput = "Command timed out after \(self.defaultTimeout) seconds"
                        }
                    }
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + self.defaultTimeout, execute: timeoutTask)
                    
                    process.waitUntilExit()
                    timeoutTask.cancel()
                    
                    // Read output
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    result.output = String(data: outputData, encoding: .utf8) ?? ""
                    result.errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    result.exitCode = process.terminationStatus
                    result.endTime = Date()
                    
                    if process.terminationStatus == 0 {
                        result.status = .success
                    } else {
                        result.status = .failed
                    }
                    
                } catch {
                    result.status = .failed
                    result.errorOutput = "Failed to execute command: \(error.localizedDescription)"
                    result.endTime = Date()
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    private func updateSessionProgress() {
        guard let session = currentSession else { return }
        
        let completedCount = session.results.filter { $0.isComplete }.count
        let totalCount = session.targetClusters.count
        
        currentSession?.progress = Double(completedCount) / Double(totalCount)
        
        NSLog("[MultiClusterCommandManager] Progress: \(completedCount)/\(totalCount)")
    }
    
    private func completeExecution() {
        guard let session = currentSession else { return }
        
        currentSession?.endTime = Date()
        currentSession?.progress = 1.0
        
        let successCount = session.successCount
        let totalCount = session.targetClusters.count
        
        if successCount == totalCount {
            currentSession?.status = .completed
        } else if successCount == 0 {
            currentSession?.status = .failed
        } else {
            currentSession?.status = .completed // Partial success
        }
        
        isExecuting = false
        
        // Clean up tasks
        executionTasks.removeAll()
        
        NSLog("[MultiClusterCommandManager] Execution completed: \(successCount)/\(totalCount) successful")
    }
    
    // MARK: - Session Management
    
    func cancelExecution() {
        guard isExecuting else { return }
        
        NSLog("[MultiClusterCommandManager] Cancelling execution")
        
        // Cancel all running tasks
        for task in executionTasks {
            task.cancel()
        }
        executionTasks.removeAll()
        
        // Update session status
        currentSession?.status = .cancelled
        currentSession?.endTime = Date()
        
        isExecuting = false
    }
    
    func clearCurrentSession() {
        currentSession = nil
    }
    
    // MARK: - Command History
    
    private func addToHistory(_ command: MultiClusterCommand) {
        commandHistory.insert(command, at: 0)
        
        // Limit history size
        if commandHistory.count > maxHistoryItems {
            commandHistory = Array(commandHistory.prefix(maxHistoryItems))
        }
        
        saveCommandHistory()
    }
    
    func getRecentCommands(limit: Int = 10) -> [String] {
        return Array(Set(commandHistory.prefix(limit).map { $0.command }))
    }
    
    // MARK: - Persistence
    
    private func saveCommandHistory() {
        // Implementation for saving command history to UserDefaults or file
        // For now, we'll keep it in memory
    }
    
    private func loadCommandHistory() {
        // Implementation for loading command history from UserDefaults or file
        // For now, we'll start with empty history
    }
    
    // MARK: - Utility Methods
    
    func getAuthenticatedClusters() -> [String] {
        return kubernetesManager.clusters
            .filter { $0.isAuthenticated }
            .map { $0.name }
    }
    
    func getAllClusters() -> [String] {
        return kubernetesManager.clusters.map { $0.name }
    }
    
    func validateCommand(_ command: String) -> Bool {
        // Basic validation - ensure command is not empty and doesn't contain dangerous operations
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedCommand.isEmpty else { return false }
        
        // Block potentially dangerous commands
        let dangerousCommands = ["delete", "rm", "remove", "destroy"]
        let commandLower = trimmedCommand.lowercased()
        
        for dangerous in dangerousCommands {
            if commandLower.contains(dangerous) {
                return false
            }
        }
        
        return true
    }

    private func findCommandPath(for commandType: CommandType) -> String {
        switch commandType {
        case .kubectl:
            return findKubectlPath()
        case .flux:
            return findFluxPath()
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
        return findCommandInPath("kubectl") ?? "/usr/local/bin/kubectl"
    }

    private func findFluxPath() -> String {
        // Common flux locations
        let commonPaths = [
            "/usr/local/bin/flux",
            "/opt/homebrew/bin/flux",
            "/usr/bin/flux",
            "/bin/flux"
        ]

        for path in commonPaths {
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
}

import Foundation
import Combine
import AppKit

class KubernetesManager: ObservableObject {
    @Published var clusters: [KubernetesCluster] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var timer: Timer?
    private let configPath: String
    
    init() {
        // Try to find kubectl config in various locations
        self.configPath = Self.findKubectlConfigPath()

        loadClusters()
        startPeriodicCheck()
    }

    private static func findKubectlConfigPath() -> String {
        // Possible kubectl config locations
        let possiblePaths = [
            // Standard location
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kube/config").path,
            // Environment variable
            ProcessInfo.processInfo.environment["KUBECONFIG"] ?? "",
            // Alternative locations
            "/Users/\(NSUserName())/.kube/config",
            "\(NSHomeDirectory())/.kube/config"
        ]

        for path in possiblePaths {
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Default fallback
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kube/config").path
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func loadClusters() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            do {
                let clusters = try self.parseKubernetesConfig()

                DispatchQueue.main.async {
                    self.clusters = clusters
                    self.isLoading = false
                    self.checkAllClustersAuthentication()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load clusters: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func parseKubernetesConfig() throws -> [KubernetesCluster] {
        // Use kubectl directly instead of trying to read the config file
        // This avoids sandboxing issues
        let contexts = try getKubectlContexts()
        return contexts.sorted { $0.name < $1.name }
    }

    private func getKubectlContexts() throws -> [KubernetesCluster] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: findKubectlPath())
        process.arguments = ["config", "get-contexts", "-o", "name"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "K8sNN", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get kubectl contexts"])
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "K8sNN", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse kubectl output"])
        }

        var clusters: [KubernetesCluster] = []
        let contextNames = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)

        for contextName in contextNames {
            let trimmedName = contextName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                // Get cluster info for this context
                if let clusterInfo = try? getClusterInfo(for: trimmedName) {
                    clusters.append(clusterInfo)
                }
            }
        }

        return clusters
    }

    private func getClusterInfo(for contextName: String) throws -> KubernetesCluster {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: findKubectlPath())
        process.arguments = ["config", "view", "--context", contextName, "-o", "jsonpath={.contexts[?(@.name==\"\(contextName)\")]}"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // For now, create a basic cluster object
        // We'll extract the cluster name from the context name
        let clusterName = extractClusterName(from: contextName)

        return KubernetesCluster(
            name: contextName,
            clusterName: clusterName,
            authInfo: contextName, // Simplified for now
            namespace: nil
        )
    }

    private func extractClusterName(from contextName: String) -> String {
        // Extract cluster name from context name
        // Example: "j0nny-alpha.tky.prod.wgtwo.com" -> "alpha.tky.prod.wgtwo.com"
        if contextName.contains("-") && contextName.contains(".") {
            let components = contextName.components(separatedBy: "-")
            if components.count > 1 {
                return components.dropFirst().joined(separator: "-")
            }
        }
        return contextName
    }
    
    func checkAllClustersAuthentication() {
        for i in clusters.indices {
            checkClusterAuthentication(at: i)
        }
    }
    
    private func checkClusterAuthentication(at index: Int) {
        guard index < clusters.count else { return }
        
        let cluster = clusters[index]
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let isAuthenticated = self.testClusterConnection(cluster: cluster)
            
            DispatchQueue.main.async {
                if index < self.clusters.count {
                    self.clusters[index].isAuthenticated = isAuthenticated
                    self.clusters[index].lastChecked = Date()
                }
            }
        }
    }
    
    private func testClusterConnection(cluster: KubernetesCluster) -> Bool {
        // Try multiple authentication checks in order of preference

        // First try: List pods (most reliable)
        if testClusterWithCommand(cluster: cluster, command: ["get", "pods", "--limit=1"]) {
            return true
        }

        // Second try: List namespaces (less privileged)
        if testClusterWithCommand(cluster: cluster, command: ["get", "namespaces", "--limit=1"]) {
            return true
        }

        // Third try: Get cluster info
        if testClusterWithCommand(cluster: cluster, command: ["cluster-info", "--request-timeout=5s"]) {
            return true
        }

        // Fourth try: Auth can-i (fallback)
        return testClusterWithCommand(cluster: cluster, command: ["auth", "can-i", "get", "pods"])
    }

    private func testClusterWithCommand(cluster: KubernetesCluster, command: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: findKubectlPath())

        var args = ["--context", cluster.name]
        args.append(contentsOf: command)
        args.append("--request-timeout=5s")

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func openLoginPage(for cluster: KubernetesCluster) {
        guard let loginURL = cluster.loginURL,
              let url = URL(string: loginURL) else {
            print("[K8sNN] No login URL for cluster: \(cluster.name)")
            return
        }
        print("[K8sNN] Opening login URL: \(loginURL)")
        NSWorkspace.shared.open(url)
    }

    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAllClustersAuthentication()
        }
    }
    
    func refreshClusters() {
        checkAllClustersAuthentication()
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



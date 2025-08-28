import Foundation

// MARK: - Command Types

enum CommandType: String, CaseIterable {
    case kubectl = "kubectl"
    case flux = "flux"

    var displayName: String {
        switch self {
        case .kubectl:
            return "kubectl"
        case .flux:
            return "flux"
        }
    }

    var placeholderCommand: String {
        switch self {
        case .kubectl:
            return "get pods --all-namespaces"
        case .flux:
            return "get kustomizations"
        }
    }
}

// MARK: - Multi-Cluster Command Models

struct MultiClusterCommand: Identifiable {
    let id = UUID()
    let command: String
    let targetClusters: [String] // cluster names
    let createdAt: Date
    let commandType: CommandType
    var executionSession: CommandExecutionSession?

    init(command: String, targetClusters: [String], commandType: CommandType = .kubectl) {
        self.command = command
        self.targetClusters = targetClusters
        self.createdAt = Date()
        self.commandType = commandType
    }
}

struct CommandExecutionSession: Identifiable {
    let id = UUID()
    let command: String
    let targetClusters: [String]
    let startTime: Date
    let commandType: CommandType
    var endTime: Date?
    var status: ExecutionStatus
    var results: [ClusterCommandResult]
    var progress: Double // 0.0 to 1.0

    init(command: String, targetClusters: [String], commandType: CommandType = .kubectl) {
        self.command = command
        self.targetClusters = targetClusters
        self.startTime = Date()
        self.commandType = commandType
        self.status = .running
        self.results = []
        self.progress = 0.0
    }

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var isComplete: Bool {
        return status == .completed || status == .failed
    }

    var successCount: Int {
        return results.filter { $0.status == .success }.count
    }

    var failureCount: Int {
        return results.filter { $0.status == .failed }.count
    }
}

struct ClusterCommandResult: Identifiable {
    let id = UUID()
    let clusterName: String
    let command: String
    let startTime: Date
    let commandType: CommandType
    var endTime: Date?
    var status: CommandResultStatus
    var output: String
    var errorOutput: String
    var exitCode: Int32?

    init(clusterName: String, command: String, commandType: CommandType = .kubectl) {
        self.clusterName = clusterName
        self.command = command
        self.startTime = Date()
        self.commandType = commandType
        self.status = .running
        self.output = ""
        self.errorOutput = ""
    }

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var isComplete: Bool {
        return status == .success || status == .failed || status == .timeout
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

enum ExecutionStatus {
    case running
    case completed
    case failed
    case cancelled
}

enum CommandResultStatus {
    case running
    case success
    case failed
    case timeout
    case cancelled
}

// MARK: - Command Templates

struct CommandTemplate: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let description: String
    let category: CommandCategory

    static let defaultTemplates: [CommandTemplate] = [
        CommandTemplate(
            name: "List Pods",
            command: "get pods --all-namespaces",
            description: "List all pods across all namespaces",
            category: .pods
        ),
        CommandTemplate(
            name: "List Nodes",
            command: "get nodes -o wide",
            description: "List all nodes with detailed information",
            category: .nodes
        ),
        CommandTemplate(
            name: "Cluster Info",
            command: "cluster-info",
            description: "Display cluster information",
            category: .cluster
        ),
        CommandTemplate(
            name: "List Services",
            command: "get services --all-namespaces",
            description: "List all services across all namespaces",
            category: .services
        ),
        CommandTemplate(
            name: "List Deployments",
            command: "get deployments --all-namespaces",
            description: "List all deployments across all namespaces",
            category: .workloads
        ),
        CommandTemplate(
            name: "Resource Usage",
            command: "top nodes",
            description: "Show resource usage for nodes",
            category: .monitoring
        )
    ]
}

enum CommandCategory: String, CaseIterable {
    case pods = "Pods"
    case nodes = "Nodes"
    case services = "Services"
    case workloads = "Workloads"
    case cluster = "Cluster"
    case monitoring = "Monitoring"
    case custom = "Custom"
}

struct KubernetesCluster: Identifiable, Codable {
    let id: UUID
    let name: String
    let clusterName: String
    let authInfo: String
    let namespace: String?
    var isAuthenticated: Bool
    var lastChecked: Date

    init(name: String, clusterName: String, authInfo: String, namespace: String?) {
        self.id = UUID()
        self.name = name
        self.clusterName = clusterName
        self.authInfo = authInfo
        self.namespace = namespace
        self.isAuthenticated = false
        self.lastChecked = Date()
    }
    
    // Computed property to get the login URL
    var loginURL: String? {
        return loginURL(using: nil)
    }

    // Method to get login URL with optional custom URL override
    func loginURL(using settingsManager: SettingsManager?) -> String? {
        // First check if there's a custom URL configured
        if let settingsManager = settingsManager,
           let customURL = settingsManager.getCustomLoginURL(for: name) {
            return customURL
        }

        // Fall back to auto-generated URL
        return autoGeneratedLoginURL
    }

    // Auto-generated login URL (original logic)
    var autoGeneratedLoginURL: String? {
        // Extract the domain from cluster name
        // Example: j0nny-echo.pdx.prod.wgtwo.com -> login.echo.pdx.prod.wgtwo.com
        // First try the full name (for contexts like "j0nny-echo.pdx.prod.wgtwo.com")
        let fullName = name.contains(".") ? name : clusterName
        let components = fullName.split(separator: ".")

        if components.count >= 4 {
            let firstPart = String(components[0]) // j0nny-echo
            let region = components[1] // pdx
            let environment = components[2] // prod
            let domain = components[3] // wgtwo
            let tld = components.count > 4 ? String(components[4]) : "com" // com

            // Extract cluster name from first part (remove user prefix)
            var clusterPart = firstPart
            if firstPart.contains("-") {
                let parts = firstPart.split(separator: "-", maxSplits: 1)
                if parts.count > 1 {
                    clusterPart = String(parts[1]) // echo
                }
            }

            // Handle different environments
            if environment == "prod" || environment == "dev" || environment == "infrasvc" {
                return "https://login.\(clusterPart).\(region).\(environment).\(domain).\(tld)"
            }
        }

        // Special handling for dub.dev and dub.prod patterns
        // Example: j0nny-dub.prod.wgtwo.com -> login.dub.prod.wgtwo.com
        if components.count == 4 {
            let firstPart = String(components[0]) // j0nny-dub
            let environment = components[1] // prod
            let domain = components[2] // wgtwo
            let tld = components[3] // com

            // Extract cluster name from first part (remove user prefix)
            var clusterPart = firstPart
            if firstPart.contains("-") {
                let parts = firstPart.split(separator: "-", maxSplits: 1)
                if parts.count > 1 {
                    clusterPart = String(parts[1]) // dub
                }
            }

            // Handle dub.dev and dub.prod patterns
            if (environment == "prod" || environment == "dev") && domain == "wgtwo" {
                return "https://login.\(clusterPart).\(environment).\(domain).\(tld)"
            }
        }

        return nil
    }
    
    // Check if this cluster uses Dex authentication (has a login URL)
    var usesDexAuth: Bool {
        return loginURL != nil
    }

    // Check if this cluster uses Dex authentication with settings manager context
    func usesDexAuth(using settingsManager: SettingsManager?) -> Bool {
        return loginURL(using: settingsManager) != nil
    }

    // Determine the primary action type for this cluster
    func primaryActionType(using settingsManager: SettingsManager?) -> ClusterActionType {
        if isAuthenticated {
            return .openTerminal
        } else if let settingsManager = settingsManager,
                  settingsManager.getCustomCommand(for: name) != nil {
            return .runCommand
        } else if usesDexAuth(using: settingsManager) {
            return .openLoginURL
        } else {
            return .none
        }
    }

    // Check if cluster has a secondary action available
    func hasSecondaryAction(using settingsManager: SettingsManager?) -> Bool {
        guard let settingsManager = settingsManager else { return false }

        let hasCommand = settingsManager.getCustomCommand(for: name) != nil
        let hasLoginURL = usesDexAuth(using: settingsManager)

        // Secondary action exists if both command and login URL are available
        return hasCommand && hasLoginURL
    }

    // Get the secondary action type
    func secondaryActionType(using settingsManager: SettingsManager?) -> ClusterActionType? {
        guard hasSecondaryAction(using: settingsManager) else { return nil }

        // If primary is command, secondary is login URL
        if primaryActionType(using: settingsManager) == .runCommand {
            return .openLoginURL
        }
        // If primary is login URL, secondary is command
        else if primaryActionType(using: settingsManager) == .openLoginURL {
            return .runCommand
        }

        return nil
    }

    // Legacy method for backward compatibility
    func actionType(using settingsManager: SettingsManager?) -> ClusterActionType {
        return primaryActionType(using: settingsManager)
    }
}

// Enum to represent different cluster action types
enum ClusterActionType {
    case openTerminal    // Authenticated cluster - open terminal with context
    case runCommand      // Custom command configured - run the command
    case openLoginURL    // Dex auth available - open login URL
    case none           // No action available
}

struct KubernetesConfig: Codable {
    let clusters: [ClusterInfo]
    let contexts: [ContextInfo]
    let users: [UserInfo]
    let currentContext: String?
    
    private enum CodingKeys: String, CodingKey {
        case clusters
        case contexts
        case users
        case currentContext = "current-context"
    }
}

struct ClusterInfo: Codable {
    let name: String
    let cluster: ClusterDetails
}

struct ClusterDetails: Codable {
    let server: String
}

struct ContextInfo: Codable {
    let name: String
    let context: ContextDetails
}

struct ContextDetails: Codable {
    let cluster: String
    let user: String
    let namespace: String?
}

struct UserInfo: Codable {
    let name: String
    let user: UserDetails
}

struct UserDetails: Codable {
    let authProvider: AuthProvider?
    let token: String?
    let clientCertificateData: String?
    let clientKeyData: String?
    
    private enum CodingKeys: String, CodingKey {
        case authProvider = "auth-provider"
        case token
        case clientCertificateData = "client-certificate-data"
        case clientKeyData = "client-key-data"
    }
}

struct AuthProvider: Codable {
    let name: String
    let config: AuthProviderConfig
}

struct AuthProviderConfig: Codable {
    let idpIssuerUrl: String?
    let clientId: String?
    let clientSecret: String?
    let refreshToken: String?
    let idToken: String?
    
    private enum CodingKeys: String, CodingKey {
        case idpIssuerUrl = "idp-issuer-url"
        case clientId = "client-id"
        case clientSecret = "client-secret"
        case refreshToken = "refresh-token"
        case idToken = "id-token"
    }
}

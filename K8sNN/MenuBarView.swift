import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingSettings {
                SettingsMenuView(onClose: {
                    withAnimation {
                        showingSettings = false
                    }
                })
                .environmentObject(settingsManager)
                .transition(.move(edge: .trailing))
            } else {
                clusterListView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSettings)
        .frame(width: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        .onAppear {
            if kubernetesManager.clusters.isEmpty {
                kubernetesManager.loadClusters()
            }
        }
    }

    private var clusterListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with glass effect
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.blue.gradient)
                    .font(.title2)
                Text("K8s Clusters")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                GlassButton(action: {
                    kubernetesManager.refreshClusters()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
                .help("Refresh clusters")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
            
            // Clusters list with glass background
            if kubernetesManager.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.blue)
                    Text("Loading clusters...")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
            } else if let errorMessage = kubernetesManager.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange.gradient)
                            .font(.title3)
                        Text("Error")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
            } else if kubernetesManager.clusters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No clusters found")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Make sure kubectl is configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(kubernetesManager.clusters) { cluster in
                            ClusterRowView(cluster: cluster)
                                .environmentObject(kubernetesManager)
                                .environmentObject(settingsManager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 400)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
            }
            
            // Footer with glass effect
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(kubernetesManager.clusters.count) clusters")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if settingsManager.isHotkeyEnabled {
                        Text("Press \(settingsManager.hotkey) for quick access")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                let authenticatedCount = kubernetesManager.clusters.filter { $0.isAuthenticated }.count
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(authenticatedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                    .help("Authenticated clusters")

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("\(kubernetesManager.clusters.count - authenticatedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                    .help("Unauthenticated clusters")
                }

                GlassButton("Settings") {
                    withAnimation {
                        showingSettings.toggle()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

                GlassButton("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
        }
    }
}

struct ClusterRowView: View {
    let cluster: KubernetesCluster
    @EnvironmentObject var kubernetesManager: KubernetesManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            handleClusterAction()
        }) {
            HStack(spacing: 14) {
                // Status indicator with glow effect
                Circle()
                    .fill(cluster.isAuthenticated ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: cluster.isAuthenticated ? .green.opacity(0.4) : .red.opacity(0.4),
                        radius: isHovered ? 4 : 2,
                        x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHovered)

                VStack(alignment: .leading, spacing: 3) {
                    Text(cluster.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if cluster.usesDexAuth {
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

                // Action indicator and status
                if cluster.isAuthenticated {
                    Text("Open Terminal")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                        .opacity(isHovered ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)

                    Image(systemName: "terminal.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                        .opacity(isHovered ? 1.0 : 0.7)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                } else if cluster.usesDexAuth {
                    Text("Login Required")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
                        .opacity(isHovered ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)

                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                        .opacity(isHovered ? 1.0 : 0.7)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                }

                // Last checked time
                if cluster.lastChecked != Date(timeIntervalSince1970: 0) {
                    Text(timeAgoString(from: cluster.lastChecked))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fontWeight(.medium)
                        .frame(width: 35, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? .blue.opacity(0.08) : .clear)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? .blue.opacity(0.15) : .clear, lineWidth: 0.5)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .help(helpText)
    }

    private func handleClusterAction() {
        NSLog("[K8sNN] MenuBar cluster action: name=\(cluster.name), isAuthenticated=\(cluster.isAuthenticated), usesDexAuth=\(cluster.usesDexAuth)")

        if cluster.isAuthenticated {
            NSLog("[K8sNN] Attempting to open terminal for context \(cluster.name)")
            let success = settingsManager.openTerminalWithContext(cluster.name)
            NSLog("[K8sNN] openTerminalWithContext returned: \(success)")
        } else if cluster.usesDexAuth {
            NSLog("[K8sNN] Opening login page for unauthenticated cluster \(cluster.name)")
            kubernetesManager.openLoginPage(for: cluster)
        } else {
            NSLog("[K8sNN] Cluster not authenticated and no Dex auth; no action taken")
        }
    }

    private var helpText: String {
        if cluster.isAuthenticated {
            return "Click to open terminal with context '\(cluster.name)'"
        } else if cluster.usesDexAuth {
            return "Click to open login page"
        } else {
            return "Cluster not configured for authentication"
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(KubernetesManager())
}

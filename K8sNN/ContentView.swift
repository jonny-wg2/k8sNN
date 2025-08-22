import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "server.rack")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("K8sNN")
                .font(.title)
            Text("Kubernetes cluster authentication monitor")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

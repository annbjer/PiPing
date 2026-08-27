#if os(iOS)
import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Sent through iCloud") {
                Label("A random event identifier", systemImage: "number")
                Label("A timestamp", systemImage: "clock")
            }
            Section("Never sent") {
                Text("Prompts, responses, code, logs, paths, files, terminal data, model names, and approvals.")
            }
            Section("Control") {
                Text("PiPing Phase 1 has no return channel and exposes no notification actions.")
            }
        }
        .navigationTitle("Privacy")
    }
}
#endif

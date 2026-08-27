import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    let store: MacAppStore

    var body: some View {
        Group {
            Label(store.status.label, systemImage: store.status.symbol)
            Text("Threshold: \(Int(store.minimumDuration))s")
            Divider()
            Button("Open PiPing") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            SettingsLink()
            Divider()
            Button("Quit PiPing") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            store.acknowledgeAttention()
        }
    }
}

import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    let store: MacAppStore

    var body: some View {
        Group {
            Label(store.status.label, systemImage: store.status.symbol)
            Text(thresholdLabel)
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSMenu.didBeginTrackingNotification
            )
        ) { notification in
            guard let menu = notification.object as? NSMenu,
                  menu.items.contains(where: { $0.title == "Quit PiPing" }) else {
                return
            }
            store.acknowledgeAttention()
        }
    }

    private var thresholdLabel: String {
        if store.notificationThreshold == .everyCompletion {
            return "Threshold: Every completion"
        }
        return "Threshold: \(Int(store.minimumDuration))s"
    }
}

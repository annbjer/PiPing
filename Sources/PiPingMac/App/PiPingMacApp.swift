import AppKit
import PiPingCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct PiPingMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = MacAppStore()

    var body: some Scene {
        Window("PiPing", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 560, height: 440)

        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            MenuBarLabel(hasUnreadAttention: store.hasUnreadAttention)
        }

        Settings {
            SettingsView()
        }
    }
}

import AppKit
import PiPingCore
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
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

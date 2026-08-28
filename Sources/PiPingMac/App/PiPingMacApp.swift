import AppKit
import PiPingCore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store: MacAppStore

    override convenience init() {
        self.init(store: MacAppStore())
    }

    init(store: MacAppStore) {
        self.store = store
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([
            SystemLocalNotificationService.attentionCategory
        ])
        notificationCenter.delegate = self
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        await acknowledgeNotification(identifier: identifier)
    }

    func acknowledgeNotification(identifier: String) {
        store.acknowledgeAttention(notificationIdentifier: identifier)
    }
}

@main
struct PiPingMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("PiPing", id: "main") {
            ContentView(store: appDelegate.store)
        }
        .defaultSize(width: 560, height: 440)

        MenuBarExtra {
            MenuBarContent(store: appDelegate.store)
        } label: {
            MenuBarLabel(hasUnreadAttention: appDelegate.store.hasUnreadAttention)
        }

        Settings {
            SettingsView(store: appDelegate.store)
        }
    }
}

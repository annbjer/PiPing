import AppKit
import PiPingCore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store: MacAppStore
    private let listenerStarter: @MainActor () -> Void

    override convenience init() {
        self.init(store: MacAppStore())
    }

    init(
        store: MacAppStore,
        listenerStarter: (@MainActor () -> Void)? = nil
    ) {
        self.store = store
        self.listenerStarter = listenerStarter ?? { store.startListening() }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([
            SystemLocalNotificationService.attentionCategory
        ])
        notificationCenter.delegate = self
        startListenerForApplicationLaunch()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startListenerForApplicationLaunch() {
        listenerStarter()
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

#if os(iOS)
import PiPingCore
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class RemoteNotificationRegistrar {
    static let shared = RemoteNotificationRegistrar()

    private let waiter = RemoteNotificationRegistrationWaiter()

    func register() async throws {
        try await waiter.wait {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister() {
        waiter.didRegister()
    }

    func didFail() {
        waiter.didFail()
    }
}

final class PiPingIOSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in RemoteNotificationRegistrar.shared.didRegister() }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        Task { @MainActor in RemoteNotificationRegistrar.shared.didFail() }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@main
struct PiPingIOSApp: App {
    @UIApplicationDelegateAdaptor(PiPingIOSAppDelegate.self) private var appDelegate
    @State private var store = MobileSetupStore()

    var body: some Scene {
        WindowGroup {
            MobileRootView(store: store)
        }
    }
}
#else
import Foundation

@main
enum PiPingIOSBuildPlaceholder {
    static func main() {
        print("PiPingIOS is an iOS application target.")
    }
}
#endif

#if os(iOS)
import Observation
@preconcurrency import CloudKit
import PiPingCloudKit
import PiPingCore
import UIKit
import UserNotifications

@MainActor
@Observable
final class MobileSetupStore {
    enum SetupStatus: Equatable {
        case notConfigured
        case configuring
        case ready
        case notificationsDenied
        case iCloudUnavailable
        case registrationRestartRequired
        case failed

        var label: String {
            switch self {
            case .notConfigured: "Not configured"
            case .configuring: "Configuring"
            case .ready: "Ready"
            case .notificationsDenied: "Notifications are off"
            case .iCloudUnavailable: "iCloud is unavailable"
            case .registrationRestartRequired: "Restart PiPing to retry"
            case .failed: "Setup needs attention"
            }
        }
    }

    private let center: UNUserNotificationCenter
    private let containerIdentifier: String?
    private let registrar: RemoteNotificationRegistrar

    private(set) var status: SetupStatus = .notConfigured

    init(
        center: UNUserNotificationCenter = .current(),
        containerIdentifier: String? = CloudKitConfiguration.containerIdentifier(),
        registrar: RemoteNotificationRegistrar = .shared
    ) {
        self.center = center
        self.containerIdentifier = containerIdentifier
        self.registrar = registrar
    }

    func refreshExistingConfiguration() async {
        guard FeatureGates.cloudKitActivationEnabled,
              let containerIdentifier else {
            status = .notConfigured
            return
        }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            status = .notificationsDenied
            return
        case .notDetermined:
            status = .notConfigured
            return
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            status = .failed
            return
        }

        status = .configuring
        do {
            let container = CloudKitConfiguration.container(identifier: containerIdentifier)
            guard try await container.accountStatus() == .available else {
                status = .iCloudUnavailable
                return
            }
            let installer = CloudKitSubscriptionInstaller(
                containerIdentifier: containerIdentifier
            )
            guard try await installer.isInstalled() else {
                status = .notConfigured
                return
            }
            try await registrar.register()
            status = .ready
        } catch {
            setFailureStatus(for: error)
        }
    }

    func configureAfterExplicitApproval() async {
        guard FeatureGates.cloudKitActivationEnabled else {
            status = .failed
            return
        }
        guard status != .configuring else { return }
        status = .configuring
        do {
            guard let containerIdentifier else {
                status = .failed
                return
            }
            let container = CloudKitConfiguration.container(identifier: containerIdentifier)
            guard try await container.accountStatus() == .available else {
                status = .iCloudUnavailable
                return
            }
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            guard allowed else {
                status = .notificationsDenied
                return
            }
            try await registrar.register()
            _ = try await CloudKitSubscriptionInstaller(
                containerIdentifier: containerIdentifier
            ).installIfNeeded()
            status = .ready
        } catch {
            setFailureStatus(for: error)
        }
    }

    private func setFailureStatus(for error: any Error) {
        guard let registrationError = error as? RemoteNotificationRegistrationError else {
            status = .failed
            return
        }
        switch registrationError {
        case .timedOut, .cancelled, .restartRequired:
            status = .registrationRestartRequired
        case .registrationFailed, .alreadyInProgress:
            status = .failed
        }
    }
}
#endif

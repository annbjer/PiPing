import PiPingCore
import UserNotifications

enum LocalNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

protocol LocalNotificationDelivering: Sendable {
    func authorization() async -> LocalNotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func deliver(_ event: AttentionEvent) async throws
}

enum LocalNotificationDeliveryError: Error {
    case notAuthorized
}

final class SystemLocalNotificationService: LocalNotificationDelivering, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorization() async -> LocalNotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func deliver(_ event: AttentionEvent) async throws {
        guard await authorization() == .authorized else {
            throw LocalNotificationDeliveryError.notAuthorized
        }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }
}

import Foundation

public enum NotificationThreshold: Int, CaseIterable, Identifiable, Sendable {
    case everyCompletion = 0
    case fifteenSeconds = 15
    case thirtySeconds = 30

    public var id: Int { rawValue }

    public var minimumDuration: TimeInterval {
        TimeInterval(rawValue)
    }
}

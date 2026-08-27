import Foundation

public enum LocalSignal: String, CaseIterable, Sendable {
    case start
    case settled

    public var wireValue: String { rawValue + "\n" }

    public init?(wireValue: String) {
        switch wireValue {
        case "start", "start\n":
            self = .start
        case "settled", "settled\n":
            self = .settled
        default:
            return nil
        }
    }
}

public enum GateDecision: Equatable, Sendable {
    case started
    case ignoredDuplicateStart
    case ignoredMissingStart
    case ignoredTooShort(elapsed: TimeInterval)
    case attention(elapsed: TimeInterval)
}

public struct LifecycleGate: Sendable {
    public static let defaultMinimumDuration: TimeInterval = 30

    public private(set) var minimumDuration: TimeInterval
    private var startedAt: Date?

    public init(minimumDuration: TimeInterval = Self.defaultMinimumDuration) {
        precondition(minimumDuration >= 0)
        self.minimumDuration = minimumDuration
    }

    public var isTracking: Bool { startedAt != nil }

    public mutating func reset() {
        startedAt = nil
    }

    public mutating func updateMinimumDuration(_ minimumDuration: TimeInterval) {
        precondition(minimumDuration >= 0)
        self.minimumDuration = minimumDuration
    }

    public mutating func receive(_ signal: LocalSignal, at now: Date) -> GateDecision {
        switch signal {
        case .start:
            guard startedAt == nil else { return .ignoredDuplicateStart }
            startedAt = now
            return .started
        case .settled:
            guard let start = startedAt else { return .ignoredMissingStart }
            startedAt = nil
            let elapsed = max(0, now.timeIntervalSince(start))
            guard elapsed >= minimumDuration else {
                return .ignoredTooShort(elapsed: elapsed)
            }
            return .attention(elapsed: elapsed)
        }
    }
}

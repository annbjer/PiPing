import Foundation

public enum LocalSignal: String, CaseIterable, Sendable {
    case start
    case settled
}

/// A random, extension-instance identifier used only to pair local lifecycle
/// signals. It is not a Pi session identifier and is never sent to CloudKit.
public struct LocalSessionToken: Equatable, Hashable, Sendable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }

    public init?(wireValue: String) {
        guard wireValue.count == 36,
              let uuid = UUID(uuidString: wireValue),
              uuid.uuidString.lowercased() == wireValue.lowercased() else {
            return nil
        }
        self.uuid = uuid
    }

    public var wireValue: String { uuid.uuidString.lowercased() }
}

public struct LocalLifecycleEvent: Equatable, Sendable {
    public static let maximumLineByteCount = 64

    public let signal: LocalSignal
    public let sessionToken: LocalSessionToken

    public init(signal: LocalSignal, sessionToken: LocalSessionToken) {
        self.signal = signal
        self.sessionToken = sessionToken
    }

    public init?(wireValue: String) {
        let line: Substring
        if wireValue.hasSuffix("\n") {
            line = wireValue.dropLast()
        } else {
            line = Substring(wireValue)
        }
        guard !line.isEmpty,
              !line.contains("\n"),
              line.utf8.count <= Self.maximumLineByteCount else {
            return nil
        }
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let signal = LocalSignal(rawValue: String(parts[0])),
              let sessionToken = LocalSessionToken(wireValue: String(parts[1])) else {
            return nil
        }
        self.init(signal: signal, sessionToken: sessionToken)
    }

    public var wireValue: String {
        "\(signal.rawValue) \(sessionToken.wireValue)\n"
    }
}

public enum GateDecision: Equatable, Sendable {
    case started
    case restartedFromLatestStart
    case ignoredMissingStart
    case ignoredTooShort(elapsed: TimeInterval)
    case ignoredCapacity
    case attention(elapsed: TimeInterval)
}

public struct LifecycleGate: Sendable {
    public static let defaultMinimumDuration: TimeInterval = 30
    public static let defaultMaximumTrackedSessions = 256
    public static let defaultMaximumTrackingDuration: TimeInterval = 7 * 24 * 60 * 60

    public private(set) var minimumDuration: TimeInterval
    private let maximumTrackedSessions: Int
    private let maximumTrackingDuration: TimeInterval
    private var startedAtBySession: [LocalSessionToken: Date] = [:]

    public init(
        minimumDuration: TimeInterval = Self.defaultMinimumDuration,
        maximumTrackedSessions: Int = Self.defaultMaximumTrackedSessions,
        maximumTrackingDuration: TimeInterval = Self.defaultMaximumTrackingDuration
    ) {
        precondition(minimumDuration >= 0)
        precondition(maximumTrackedSessions > 0)
        precondition(maximumTrackingDuration > 0)
        self.minimumDuration = minimumDuration
        self.maximumTrackedSessions = maximumTrackedSessions
        self.maximumTrackingDuration = maximumTrackingDuration
    }

    public var isTracking: Bool { !startedAtBySession.isEmpty }
    public var trackedSessionCount: Int { startedAtBySession.count }

    public mutating func reset() {
        startedAtBySession.removeAll(keepingCapacity: true)
    }

    public mutating func updateMinimumDuration(_ minimumDuration: TimeInterval) {
        precondition(minimumDuration >= 0)
        self.minimumDuration = minimumDuration
    }

    public mutating func receive(
        _ event: LocalLifecycleEvent,
        at now: Date
    ) -> GateDecision {
        discardExpiredSessions(at: now)

        switch event.signal {
        case .start:
            let replacedExistingStart = startedAtBySession[event.sessionToken] != nil
            guard replacedExistingStart
                    || startedAtBySession.count < maximumTrackedSessions else {
                return .ignoredCapacity
            }
            startedAtBySession[event.sessionToken] = now
            return replacedExistingStart ? .restartedFromLatestStart : .started
        case .settled:
            guard let start = startedAtBySession.removeValue(
                forKey: event.sessionToken
            ) else {
                return .ignoredMissingStart
            }
            let elapsed = max(0, now.timeIntervalSince(start))
            guard elapsed >= minimumDuration else {
                return .ignoredTooShort(elapsed: elapsed)
            }
            return .attention(elapsed: elapsed)
        }
    }

    private mutating func discardExpiredSessions(at now: Date) {
        startedAtBySession = startedAtBySession.filter { _, startedAt in
            now.timeIntervalSince(startedAt) <= maximumTrackingDuration
        }
    }
}

import Foundation
import Testing
@testable import PiPingCore

@Suite("Lifecycle gate")
struct LifecycleGateTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let firstToken = LocalSessionToken(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )
    private let secondToken = LocalSessionToken(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    )

    @Test("uses a thirty-second default threshold")
    func defaultThreshold() {
        #expect(LifecycleGate.defaultMinimumDuration == 30)
        #expect(NotificationThreshold.thirtySeconds.minimumDuration == 30)
        #expect(NotificationThreshold.allCases.map(\.rawValue) == [0, 15, 30])
    }

    @Test("can notify for every completed run")
    func everyCompletion() {
        var gate = LifecycleGate(
            minimumDuration: NotificationThreshold.everyCompletion.minimumDuration
        )
        #expect(gate.receive(event(.start, firstToken), at: start) == .started)
        #expect(
            gate.receive(event(.settled, firstToken), at: start)
                == .attention(elapsed: 0)
        )
    }

    @Test("updates the threshold without discarding active runs")
    func updatesThreshold() {
        var gate = LifecycleGate()
        #expect(gate.receive(event(.start, firstToken), at: start) == .started)
        gate.updateMinimumDuration(15)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(16)
            ) == .attention(elapsed: 16)
        )
    }

    @Test("ignores a settled signal without a matching start")
    func missingStart() {
        var gate = LifecycleGate()
        #expect(
            gate.receive(event(.settled, firstToken), at: start)
                == .ignoredMissingStart
        )
    }

    @Test("tracks overlapping sessions independently")
    func overlappingSessions() {
        var gate = LifecycleGate()
        #expect(gate.receive(event(.start, firstToken), at: start) == .started)
        #expect(
            gate.receive(
                event(.start, secondToken),
                at: start.addingTimeInterval(10)
            ) == .started
        )
        #expect(gate.trackedSessionCount == 2)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(31)
            ) == .attention(elapsed: 31)
        )
        #expect(gate.trackedSessionCount == 1)
        #expect(
            gate.receive(
                event(.settled, secondToken),
                at: start.addingTimeInterval(40)
            ) == .attention(elapsed: 30)
        )
        #expect(!gate.isTracking)
    }

    @Test("many overlapping sessions settle independently out of order")
    func manyOverlappingSessions() {
        let tokens = (1...50).map { value in
            LocalSessionToken(
                uuid: UUID(
                    uuidString: String(
                        format: "00000000-0000-0000-0000-%012x",
                        value
                    )
                )!
            )
        }
        var gate = LifecycleGate()

        for token in tokens {
            #expect(gate.receive(event(.start, token), at: start) == .started)
        }
        #expect(gate.trackedSessionCount == tokens.count)

        for token in tokens.reversed() {
            #expect(
                gate.receive(
                    event(.settled, token),
                    at: start.addingTimeInterval(30)
                ) == .attention(elapsed: 30)
            )
        }
        #expect(!gate.isTracking)
    }

    @Test("a newer start replaces only the same session's stale state")
    func latestStartWinsPerSession() {
        var gate = LifecycleGate()
        #expect(gate.receive(event(.start, firstToken), at: start) == .started)
        #expect(gate.receive(event(.start, secondToken), at: start) == .started)
        #expect(
            gate.receive(
                event(.start, firstToken),
                at: start.addingTimeInterval(20)
            ) == .restartedFromLatestStart
        )
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(31)
            ) == .ignoredTooShort(elapsed: 11)
        )
        #expect(
            gate.receive(
                event(.settled, secondToken),
                at: start.addingTimeInterval(31)
            ) == .attention(elapsed: 31)
        )
    }

    @Test("a mismatched settled signal does not consume another session")
    func mismatchedSettled() {
        var gate = LifecycleGate()
        _ = gate.receive(event(.start, firstToken), at: start)
        #expect(
            gate.receive(event(.settled, secondToken), at: start)
                == .ignoredMissingStart
        )
        #expect(gate.trackedSessionCount == 1)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(30)
            ) == .attention(elapsed: 30)
        )
    }

    @Test("keeps short work quiet and resets only that session")
    func shortRun() {
        var gate = LifecycleGate()
        _ = gate.receive(event(.start, firstToken), at: start)
        _ = gate.receive(event(.start, secondToken), at: start)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(29)
            ) == .ignoredTooShort(elapsed: 29)
        )
        #expect(gate.trackedSessionCount == 1)
        #expect(
            gate.receive(
                event(.settled, secondToken),
                at: start.addingTimeInterval(30)
            ) == .attention(elapsed: 30)
        )
    }

    @Test("accepts work at the exact threshold")
    func exactThreshold() {
        var gate = LifecycleGate()
        _ = gate.receive(event(.start, firstToken), at: start)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(30)
            ) == .attention(elapsed: 30)
        )
    }

    @Test("bounds abandoned session state")
    func capacityBound() {
        var gate = LifecycleGate(maximumTrackedSessions: 1)
        #expect(gate.receive(event(.start, firstToken), at: start) == .started)
        #expect(
            gate.receive(event(.start, secondToken), at: start)
                == .ignoredCapacity
        )
        #expect(gate.trackedSessionCount == 1)
    }

    @Test("expires abandoned session state")
    func expiration() {
        var gate = LifecycleGate(maximumTrackingDuration: 60)
        _ = gate.receive(event(.start, firstToken), at: start)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(61)
            ) == .ignoredMissingStart
        )
    }

    @Test("explicit reset discards every tracked start")
    func explicitReset() {
        var gate = LifecycleGate()
        _ = gate.receive(event(.start, firstToken), at: start)
        _ = gate.receive(event(.start, secondToken), at: start)
        gate.reset()
        #expect(!gate.isTracking)
        #expect(
            gate.receive(
                event(.settled, firstToken),
                at: start.addingTimeInterval(60)
            ) == .ignoredMissingStart
        )
        #expect(
            gate.receive(
                event(.settled, secondToken),
                at: start.addingTimeInterval(60)
            ) == .ignoredMissingStart
        )
    }

    private func event(
        _ signal: LocalSignal,
        _ token: LocalSessionToken
    ) -> LocalLifecycleEvent {
        LocalLifecycleEvent(signal: signal, sessionToken: token)
    }
}

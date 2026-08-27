import Foundation
import Testing
@testable import PiPingCore

@Suite("Lifecycle gate")
struct LifecycleGateTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

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
        #expect(gate.receive(.start, at: start) == .started)
        #expect(
            gate.receive(.settled, at: start)
                == .attention(elapsed: 0)
        )
    }

    @Test("updates the threshold without discarding an active run")
    func updatesThreshold() {
        var gate = LifecycleGate()
        #expect(gate.receive(.start, at: start) == .started)
        gate.updateMinimumDuration(15)
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(16))
                == .attention(elapsed: 16)
        )
    }

    @Test("ignores a settled signal without a start")
    func missingStart() {
        var gate = LifecycleGate()
        #expect(gate.receive(.settled, at: start) == .ignoredMissingStart)
    }

    @Test("does not reset the timer for a duplicate start")
    func duplicateStart() {
        var gate = LifecycleGate()
        #expect(gate.receive(.start, at: start) == .started)
        #expect(
            gate.receive(.start, at: start.addingTimeInterval(20))
                == .ignoredDuplicateStart
        )
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(31))
                == .attention(elapsed: 31)
        )
    }

    @Test("keeps short work quiet and resets")
    func shortRun() {
        var gate = LifecycleGate()
        _ = gate.receive(.start, at: start)
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(29))
                == .ignoredTooShort(elapsed: 29)
        )
        #expect(gate.receive(.settled, at: start.addingTimeInterval(40)) == .ignoredMissingStart)
    }

    @Test("accepts work at the exact threshold")
    func exactThreshold() {
        var gate = LifecycleGate()
        _ = gate.receive(.start, at: start)
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(30))
                == .attention(elapsed: 30)
        )
    }

    @Test("explicit reset discards a tracked start")
    func explicitReset() {
        var gate = LifecycleGate()
        #expect(gate.receive(.start, at: start) == .started)
        gate.reset()
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(60))
                == .ignoredMissingStart
        )
    }
}

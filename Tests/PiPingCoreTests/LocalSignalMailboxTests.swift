import Foundation
import Testing
@testable import PiPingCore

@Suite("Bounded local signal mailbox")
struct LocalSignalMailboxTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("preserves a normal ordered start and settled pair")
    func preservesNormalPair() async {
        let mailbox = LocalSignalMailbox(capacity: 2)
        #expect(mailbox.send(.start, receivedAt: start) == .enqueued)
        #expect(
            mailbox.send(.settled, receivedAt: start.addingTimeInterval(30))
                == .enqueued
        )

        #expect(
            await mailbox.next()
                == .signal(ReceivedLocalSignal(signal: .start, receivedAt: start))
        )
        #expect(
            await mailbox.next()
                == .signal(
                    ReceivedLocalSignal(
                        signal: .settled,
                        receivedAt: start.addingTimeInterval(30)
                    )
                )
        )
    }

    @Test("bounds a valid-token flood and resynchronizes before another pair")
    func boundsFlood() async {
        let mailbox = LocalSignalMailbox(capacity: 4)
        var enqueued = 0
        var overflowed = 0
        var dropped = 0

        for offset in 0..<10_000 {
            switch mailbox.send(.start, receivedAt: start.addingTimeInterval(Double(offset))) {
            case .enqueued: enqueued += 1
            case .overflowed: overflowed += 1
            case .dropped: dropped += 1
            case .terminated: Issue.record("Mailbox terminated unexpectedly")
            }
        }

        #expect(enqueued == 4)
        #expect(overflowed == 1)
        #expect(dropped == 9_995)
        #expect(await mailbox.next() == .overflow)

        #expect(mailbox.send(.start, receivedAt: start) == .enqueued)
        #expect(
            mailbox.send(.settled, receivedAt: start.addingTimeInterval(30))
                == .enqueued
        )

        var gate = LifecycleGate()
        guard case let .signal(first) = await mailbox.next(),
              case let .signal(second) = await mailbox.next() else {
            Issue.record("Expected an ordered signal pair after resynchronization")
            return
        }
        #expect(gate.receive(first.signal, at: first.receivedAt) == .started)
        #expect(
            gate.receive(second.signal, at: second.receivedAt)
                == .attention(elapsed: 30)
        )
    }

    @Test("overflow reset prevents a stale settled signal from notifying")
    func overflowResetsGate() async {
        var gate = LifecycleGate()
        #expect(gate.receive(.start, at: start) == .started)

        let mailbox = LocalSignalMailbox(capacity: 2)
        _ = mailbox.send(.start, receivedAt: start)
        _ = mailbox.send(.start, receivedAt: start)
        #expect(mailbox.send(.settled, receivedAt: start.addingTimeInterval(60)) == .overflowed)
        #expect(await mailbox.next() == .overflow)

        gate.reset()
        #expect(
            gate.receive(.settled, at: start.addingTimeInterval(60))
                == .ignoredMissingStart
        )
    }
}

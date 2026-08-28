import Foundation
import Testing
@testable import PiPingCore

@Suite("Local signal stream decoder")
struct LocalSignalStreamDecoderTests {
    private let firstToken = LocalSessionToken(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )
    private let secondToken = LocalSessionToken(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    )

    @Test("decodes one complete event")
    func completeEvent() {
        var decoder = LocalSignalStreamDecoder()
        let event = lifecycleEvent(.start, firstToken)
        #expect(decoder.append(event.wireValue.utf8) == [event])
    }

    @Test("reassembles an event split across every byte boundary")
    func splitEvent() {
        let event = lifecycleEvent(.settled, firstToken)
        let bytes = Array(event.wireValue.utf8)

        for split in 0..<bytes.count {
            var decoder = LocalSignalStreamDecoder()
            #expect(decoder.append(bytes[..<split]).isEmpty)
            #expect(decoder.append(bytes[split...]) == [event])
        }
    }

    @Test("decodes combined events from independent sessions")
    func combinedEvents() {
        var decoder = LocalSignalStreamDecoder()
        let first = lifecycleEvent(.start, firstToken)
        let second = lifecycleEvent(.settled, secondToken)
        #expect(
            decoder.append((first.wireValue + second.wireValue).utf8)
                == [first, second]
        )
    }

    @Test("decodes a burst of many complete session events")
    func manyCombinedEvents() {
        let events = (1...50).map { value in
            lifecycleEvent(
                value.isMultiple(of: 2) ? .settled : .start,
                LocalSessionToken(
                    uuid: UUID(
                        uuidString: String(
                            format: "00000000-0000-0000-0000-%012x",
                            value
                        )
                    )!
                )
            )
        }
        var decoder = LocalSignalStreamDecoder()
        #expect(decoder.append(events.map(\.wireValue).joined().utf8) == events)
    }

    @Test("rejects malformed lines without losing the next valid event")
    func malformedLine() {
        var decoder = LocalSignalStreamDecoder()
        let event = lifecycleEvent(.start, firstToken)
        #expect(
            decoder.append(("synthetic private prompt\n" + event.wireValue).utf8)
                == [event]
        )
    }

    @Test("bounds oversized lines across chunks and resynchronizes")
    func oversizedLine() {
        var decoder = LocalSignalStreamDecoder()
        let event = lifecycleEvent(.settled, secondToken)
        #expect(decoder.append(String(repeating: "x", count: 65).utf8).isEmpty)
        #expect(decoder.append(("more malformed data\n" + event.wireValue).utf8) == [event])
    }

    @Test("does not emit an incomplete event")
    func incompleteEvent() {
        var decoder = LocalSignalStreamDecoder()
        let event = lifecycleEvent(.start, firstToken)
        #expect(decoder.append(event.wireValue.dropLast().utf8).isEmpty)
    }

    private func lifecycleEvent(
        _ signal: LocalSignal,
        _ token: LocalSessionToken
    ) -> LocalLifecycleEvent {
        LocalLifecycleEvent(signal: signal, sessionToken: token)
    }
}

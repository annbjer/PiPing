public struct LocalSignalStreamDecoder: Sendable {
    private var pendingLine: [UInt8] = []
    private var discardingOversizedLine = false

    public init() {
        pendingLine.reserveCapacity(LocalLifecycleEvent.maximumLineByteCount)
    }

    public mutating func append<S: Sequence>(_ bytes: S) -> [LocalLifecycleEvent]
    where S.Element == UInt8 {
        var events: [LocalLifecycleEvent] = []

        for byte in bytes {
            if discardingOversizedLine {
                if byte == UInt8(ascii: "\n") {
                    discardingOversizedLine = false
                }
                continue
            }

            if byte == UInt8(ascii: "\n") {
                if !pendingLine.isEmpty,
                   let event = LocalLifecycleEvent(
                       wireValue: String(decoding: pendingLine, as: UTF8.self)
                   ) {
                    events.append(event)
                }
                pendingLine.removeAll(keepingCapacity: true)
                continue
            }

            guard pendingLine.count < LocalLifecycleEvent.maximumLineByteCount else {
                pendingLine.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
                continue
            }
            pendingLine.append(byte)
        }

        return events
    }
}

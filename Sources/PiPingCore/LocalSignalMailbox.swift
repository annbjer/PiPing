import Foundation

public struct ReceivedLocalSignal: Equatable, Sendable {
    public let signal: LocalSignal
    public let receivedAt: Date

    public init(signal: LocalSignal, receivedAt: Date) {
        self.signal = signal
        self.receivedAt = receivedAt
    }
}

public enum LocalSignalMailboxEvent: Equatable, Sendable {
    case signal(ReceivedLocalSignal)
    case overflow
}

public enum LocalSignalMailboxSendResult: Equatable, Sendable {
    case enqueued
    case overflowed
    case dropped
    case terminated
}

/// A single-consumer FIFO with bounded storage and fail-quiet resynchronization.
public final class LocalSignalMailbox: @unchecked Sendable {
    public static let defaultCapacity = 64

    private let capacity: Int
    private let lock = NSLock()
    private var buffer: [LocalSignalMailboxEvent] = []
    private var waiter: CheckedContinuation<LocalSignalMailboxEvent?, Never>?
    private var overflowPending = false
    private var finished = false

    public init(capacity: Int = LocalSignalMailbox.defaultCapacity) {
        precondition(capacity >= 2)
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    @discardableResult
    public func send(
        _ signal: LocalSignal,
        receivedAt: Date = Date()
    ) -> LocalSignalMailboxSendResult {
        let event = LocalSignalMailboxEvent.signal(
            ReceivedLocalSignal(signal: signal, receivedAt: receivedAt)
        )
        var waitingConsumer: CheckedContinuation<LocalSignalMailboxEvent?, Never>?
        let result: LocalSignalMailboxSendResult

        lock.lock()
        if finished {
            result = .terminated
        } else if overflowPending {
            result = .dropped
        } else if let waiter {
            self.waiter = nil
            waitingConsumer = waiter
            result = .enqueued
        } else if buffer.count < capacity {
            buffer.append(event)
            result = .enqueued
        } else {
            // Discard ambiguous queued state and block new signals until the
            // consumer resets its lifecycle gate after receiving this marker.
            buffer.removeAll(keepingCapacity: true)
            buffer.append(.overflow)
            overflowPending = true
            result = .overflowed
        }
        lock.unlock()

        waitingConsumer?.resume(returning: event)
        return result
    }

    public func next() async -> LocalSignalMailboxEvent? {
        await withCheckedContinuation { continuation in
            lock.lock()
            if !buffer.isEmpty {
                let event = buffer.removeFirst()
                if event == .overflow {
                    overflowPending = false
                }
                lock.unlock()
                continuation.resume(returning: event)
            } else if finished {
                lock.unlock()
                continuation.resume(returning: nil)
            } else {
                precondition(waiter == nil, "LocalSignalMailbox supports one consumer")
                waiter = continuation
                lock.unlock()
            }
        }
    }

    public func finish() {
        var waitingConsumer: CheckedContinuation<LocalSignalMailboxEvent?, Never>?

        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        buffer.removeAll(keepingCapacity: false)
        overflowPending = false
        waitingConsumer = waiter
        waiter = nil
        lock.unlock()

        waitingConsumer?.resume(returning: nil)
    }
}

import Darwin
import Foundation
import PiPingCore

final class LocalSignalListener: @unchecked Sendable {
    private let fifoURL: URL
    private let queue = DispatchQueue(label: "org.example.PiPing.local-signal")
    private let onSignal: @Sendable (LocalSignal) -> Void
    private let onError: @Sendable (String) -> Void
    private let startLock = NSLock()
    private var started = false
    private var endpoint: LocalIPCDescriptorSet?

    init(
        fifoURL: URL = RuntimePath.currentFIFO,
        onSignal: @escaping @Sendable (LocalSignal) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        self.fifoURL = fifoURL
        self.onSignal = onSignal
        self.onError = onError
    }

    func start() {
        startLock.lock()
        defer { startLock.unlock() }
        guard !started else { return }
        started = true

        do {
            let endpoint = try LocalIPC.openListener(at: fifoURL)
            self.endpoint = endpoint
            queue.async { [self, endpoint] in readLoop(endpoint: endpoint) }
        } catch {
            started = false
            onError("Local signal listener could not start.")
        }
    }

    private func readLoop(endpoint: LocalIPCDescriptorSet) {
        while true {
            var buffer = [UInt8](repeating: 0, count: 64)
            let count = buffer.withUnsafeMutableBytes { bytes in
                read(endpoint.fifoDescriptor, bytes.baseAddress, bytes.count)
            }

            if count < 0, errno == EINTR { continue }
            guard count > 0 else {
                onError("Local signal listener stopped.")
                return
            }
            let payload = String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
            for line in payload.split(separator: "\n", omittingEmptySubsequences: true) {
                if let signal = LocalSignal(wireValue: String(line)) {
                    onSignal(signal)
                }
            }
        }
    }
}

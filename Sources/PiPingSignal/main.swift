import Darwin
import Foundation
import PiPingCore

enum SignalClientError: Error {
    case invalidArguments
    case companionUnavailable
    case shortWrite
}

@main
enum PiPingSignalCommand {
    static func main() {
        do {
            try run(arguments: CommandLine.arguments)
        } catch {
            fputs("PiPing companion is unavailable.\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        guard arguments.count == 3,
              let signal = LocalSignal(rawValue: arguments[1]),
              let sessionToken = LocalSessionToken(wireValue: arguments[2]) else {
            throw SignalClientError.invalidArguments
        }
        let event = LocalLifecycleEvent(signal: signal, sessionToken: sessionToken)

        let endpoint: LocalIPCDescriptorSet
        do {
            endpoint = try LocalIPC.openWriter(at: RuntimePath.currentFIFO)
        } catch {
            throw SignalClientError.companionUnavailable
        }

        let payload = Array(event.wireValue.utf8)
        let written = payload.withUnsafeBytes { bytes in
            write(endpoint.fifoDescriptor, bytes.baseAddress, bytes.count)
        }
        guard written == payload.count else { throw SignalClientError.shortWrite }
    }
}

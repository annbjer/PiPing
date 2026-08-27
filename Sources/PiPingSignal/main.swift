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
        guard arguments.count == 2, let signal = LocalSignal(rawValue: arguments[1]) else {
            throw SignalClientError.invalidArguments
        }

        let endpoint: LocalIPCDescriptorSet
        do {
            endpoint = try LocalIPC.openWriter(at: RuntimePath.currentFIFO)
        } catch {
            throw SignalClientError.companionUnavailable
        }

        let payload = Array(signal.wireValue.utf8)
        let written = payload.withUnsafeBytes { bytes in
            write(endpoint.fifoDescriptor, bytes.baseAddress, bytes.count)
        }
        guard written == payload.count else { throw SignalClientError.shortWrite }
    }
}

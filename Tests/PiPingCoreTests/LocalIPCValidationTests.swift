#if os(macOS)
import Darwin
import Foundation
import Testing
@testable import PiPingCore

@Suite("Local IPC descriptor validation")
struct LocalIPCValidationTests {
    @Test("accepts a clean pinned directory and FIFO")
    func acceptsCleanEndpoint() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let listener = try LocalIPC.openListener(at: fixture.fifoURL)
        let writer = try LocalIPC.openWriter(at: fixture.fifoURL)

        try LocalIPC.validateDirectoryDescriptor(listener.directoryDescriptor)
        try LocalIPC.validateFIFODescriptor(listener.fifoDescriptor)
        try LocalIPC.validateFIFODescriptor(writer.fifoDescriptor)
    }

    @Test("rejects an extended ACL on the runtime directory")
    func rejectsDirectoryACL() throws {
        let fixture = try Fixture(createRuntimeDirectory: true)
        defer { fixture.remove() }
        try fixture.addSyntheticACL(at: fixture.runtimeDirectoryURL)

        expectError(.extendedACL) {
            _ = try LocalIPC.openListener(at: fixture.fifoURL)
        }
    }

    @Test("rejects an extended ACL on the actual FIFO descriptor")
    func rejectsFIFOACL() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let listener = try LocalIPC.openListener(at: fixture.fifoURL)
        _ = listener
        try fixture.addSyntheticACL(at: fixture.fifoURL)

        expectError(.extendedACL) {
            _ = try LocalIPC.openWriter(at: fixture.fifoURL)
        }
    }

    @Test("pins the opened FIFO and does not replay a replacement regular file")
    func pinsFIFOAcrossSubstitution() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let listener = try LocalIPC.openListener(at: fixture.fifoURL)

        try FileManager.default.moveItem(
            at: fixture.fifoURL,
            to: fixture.runtimeDirectoryURL.appendingPathComponent("synthetic-old-fifo")
        )
        try Data("start\nsettled\n".utf8).write(to: fixture.fifoURL)

        var metadata = stat()
        #expect(fstat(listener.fifoDescriptor, &metadata) == 0)
        #expect(metadata.st_mode & S_IFMT == S_IFIFO)
        expectError(.invalidType) {
            _ = try LocalIPC.openWriter(at: fixture.fifoURL)
        }

        let flags = fcntl(listener.fifoDescriptor, F_GETFL)
        #expect(flags >= 0)
        #expect(fcntl(listener.fifoDescriptor, F_SETFL, flags | O_NONBLOCK) == 0)
        var byte: UInt8 = 0
        errno = 0
        #expect(read(listener.fifoDescriptor, &byte, 1) == -1)
        #expect(errno == EAGAIN)
    }

    @Test("pins the runtime directory across pathname substitution")
    func pinsDirectoryAcrossSubstitution() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let listener = try LocalIPC.openListener(at: fixture.fifoURL)

        let pinnedDirectoryURL = fixture.rootURL.appendingPathComponent(
            "synthetic-pinned-runtime",
            isDirectory: true
        )
        try FileManager.default.moveItem(
            at: fixture.runtimeDirectoryURL,
            to: pinnedDirectoryURL
        )
        try FileManager.default.createDirectory(
            at: fixture.runtimeDirectoryURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("start\n".utf8).write(to: fixture.fifoURL)

        try LocalIPC.validateDirectoryDescriptor(listener.directoryDescriptor)
        try LocalIPC.validateFIFODescriptor(listener.fifoDescriptor)
        expectError(.invalidType) {
            _ = try LocalIPC.openWriter(at: fixture.fifoURL)
        }
    }

    @Test("validates the opened object rather than a prior pathname result")
    func rejectsOpenedRegularDescriptor() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let regularURL = fixture.rootURL.appendingPathComponent("synthetic-regular")
        try Data("start\n".utf8).write(to: regularURL)
        let descriptor = open(regularURL.path, O_RDONLY | O_CLOEXEC)
        #expect(descriptor >= 0)
        defer { Darwin.close(descriptor) }

        expectError(.invalidType) {
            try LocalIPC.validateFIFODescriptor(descriptor)
        }
    }

    private func expectError(
        _ expected: LocalIPCError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected local IPC validation to fail")
        } catch let error as LocalIPCError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error type")
        }
    }
}

private final class Fixture {
    let rootURL: URL
    let runtimeDirectoryURL: URL
    let fifoURL: URL

    init(createRuntimeDirectory: Bool = false) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PiPingTests-\(UUID().uuidString)",
            isDirectory: true
        )
        runtimeDirectoryURL = rootURL.appendingPathComponent(
            RuntimePath.directoryName,
            isDirectory: true
        )
        fifoURL = runtimeDirectoryURL.appendingPathComponent(RuntimePath.fifoName)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        if createRuntimeDirectory {
            try FileManager.default.createDirectory(
                at: runtimeDirectoryURL,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    func addSyntheticACL(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", "everyone allow read", url.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
#endif

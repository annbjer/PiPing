#if os(macOS)
import Darwin
import Foundation

public enum LocalIPCError: Error, Equatable, Sendable {
    case invalidPath
    case unavailable
    case invalidType
    case invalidOwner
    case insecurePermissions
    case extendedACL
    case aclInspectionFailed
}

public final class LocalIPCDescriptorSet: @unchecked Sendable {
    public let directoryDescriptor: Int32
    public let fifoDescriptor: Int32

    init(directoryDescriptor: Int32, fifoDescriptor: Int32) {
        self.directoryDescriptor = directoryDescriptor
        self.fifoDescriptor = fifoDescriptor
    }

    deinit {
        Darwin.close(fifoDescriptor)
        Darwin.close(directoryDescriptor)
    }
}

public enum LocalIPC {
    private static let directoryPermissions: mode_t = 0o700
    private static let fifoPermissions: mode_t = 0o600

    public static func openListener(at fifoURL: URL) throws -> LocalIPCDescriptorSet {
        let directoryURL = try validatedDirectoryURL(for: fifoURL)

        let createResult = mkdir(directoryURL.path, directoryPermissions)
        guard createResult == 0 || errno == EEXIST else {
            throw LocalIPCError.unavailable
        }

        let directoryDescriptor = open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directoryDescriptor >= 0 else { throw LocalIPCError.unavailable }

        do {
            try validateDirectoryDescriptor(directoryDescriptor)

            let createFIFOResult = mkfifoat(
                directoryDescriptor,
                RuntimePath.fifoName,
                fifoPermissions
            )
            guard createFIFOResult == 0 || errno == EEXIST else {
                throw LocalIPCError.unavailable
            }

            let fifoDescriptor = openat(
                directoryDescriptor,
                RuntimePath.fifoName,
                O_RDWR | O_NOFOLLOW | O_CLOEXEC
            )
            guard fifoDescriptor >= 0 else { throw LocalIPCError.unavailable }

            do {
                try validateFIFODescriptor(fifoDescriptor)
                return LocalIPCDescriptorSet(
                    directoryDescriptor: directoryDescriptor,
                    fifoDescriptor: fifoDescriptor
                )
            } catch {
                Darwin.close(fifoDescriptor)
                throw error
            }
        } catch {
            Darwin.close(directoryDescriptor)
            throw error
        }
    }

    public static func openWriter(at fifoURL: URL) throws -> LocalIPCDescriptorSet {
        let directoryURL = try validatedDirectoryURL(for: fifoURL)
        let directoryDescriptor = open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directoryDescriptor >= 0 else { throw LocalIPCError.unavailable }

        do {
            try validateDirectoryDescriptor(directoryDescriptor)
            let fifoDescriptor = openat(
                directoryDescriptor,
                RuntimePath.fifoName,
                O_WRONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
            )
            guard fifoDescriptor >= 0 else { throw LocalIPCError.unavailable }

            do {
                try validateFIFODescriptor(fifoDescriptor)
                return LocalIPCDescriptorSet(
                    directoryDescriptor: directoryDescriptor,
                    fifoDescriptor: fifoDescriptor
                )
            } catch {
                Darwin.close(fifoDescriptor)
                throw error
            }
        } catch {
            Darwin.close(directoryDescriptor)
            throw error
        }
    }

    static func validateDirectoryDescriptor(_ descriptor: Int32) throws {
        try validateDescriptor(
            descriptor,
            expectedType: S_IFDIR,
            expectedPermissions: directoryPermissions
        )
    }

    static func validateFIFODescriptor(_ descriptor: Int32) throws {
        try validateDescriptor(
            descriptor,
            expectedType: S_IFIFO,
            expectedPermissions: fifoPermissions
        )
    }

    private static func validatedDirectoryURL(for fifoURL: URL) throws -> URL {
        let directoryURL = fifoURL.deletingLastPathComponent()
        guard fifoURL.lastPathComponent == RuntimePath.fifoName,
              directoryURL.lastPathComponent == RuntimePath.directoryName else {
            throw LocalIPCError.invalidPath
        }
        return directoryURL
    }

    private static func validateDescriptor(
        _ descriptor: Int32,
        expectedType: mode_t,
        expectedPermissions: mode_t
    ) throws {
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw LocalIPCError.unavailable
        }
        guard metadata.st_mode & S_IFMT == expectedType else {
            throw LocalIPCError.invalidType
        }
        guard metadata.st_uid == geteuid() else {
            throw LocalIPCError.invalidOwner
        }
        guard metadata.st_mode & 0o777 == expectedPermissions else {
            throw LocalIPCError.insecurePermissions
        }
        try validateNoExtendedACL(descriptor)
    }

    private static func validateNoExtendedACL(_ descriptor: Int32) throws {
        errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            // Darwin reports ENOENT when an object has no extended ACL.
            guard errno == ENOENT else {
                throw LocalIPCError.aclInspectionFailed
            }
            return
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }

        var entry: acl_entry_t?
        errno = 0
        let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
        if result == 0 {
            throw LocalIPCError.extendedACL
        }
        guard errno == EINVAL else {
            throw LocalIPCError.aclInspectionFailed
        }
    }
}
#endif

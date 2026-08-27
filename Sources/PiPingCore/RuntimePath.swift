import Foundation

public enum RuntimePath {
    public static let directoryName = ".piping"
    public static let fifoName = "events.fifo"

    public static func directory(homeDirectory: URL) -> URL {
        homeDirectory.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func fifo(homeDirectory: URL) -> URL {
        directory(homeDirectory: homeDirectory).appendingPathComponent(fifoName)
    }

    #if os(macOS)
    public static var currentFIFO: URL {
        fifo(homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    }
    #endif
}

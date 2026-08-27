@preconcurrency import CloudKit
import Foundation

public enum CloudKitConfiguration {
    public static let containerIdentifierInfoKey = "PiPingCloudKitContainerIdentifier"

    public static func containerIdentifier(in bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(
            forInfoDictionaryKey: containerIdentifierInfoKey
        ) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("iCloud."), !trimmed.contains("org.example") else {
            return nil
        }
        return trimmed
    }

    public static func container(identifier: String) -> CKContainer {
        CKContainer(identifier: identifier)
    }
}

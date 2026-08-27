@preconcurrency import CloudKit
import PiPingCore

public enum CloudKitPublishingError: Error, Equatable {
    case missingSaveResult
    case rejected(String)
}

public final class CloudKitAttentionPublisher: AttentionPublishing, @unchecked Sendable {
    private let database: CKDatabase

    public init(containerIdentifier: String) {
        database = CloudKitConfiguration.container(
            identifier: containerIdentifier
        ).privateCloudDatabase
    }

    public init(container: CKContainer) {
        database = container.privateCloudDatabase
    }

    public init(database: CKDatabase) {
        self.database = database
    }

    public func publish(_ event: AttentionEvent) async throws {
        let record = CloudKitSchema.makeRecord(for: event)
        let result = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        guard let saveResult = result.saveResults[record.recordID] else {
            throw CloudKitPublishingError.missingSaveResult
        }
        if case let .failure(error) = saveResult {
            throw CloudKitPublishingError.rejected(String(describing: type(of: error)))
        }
    }
}

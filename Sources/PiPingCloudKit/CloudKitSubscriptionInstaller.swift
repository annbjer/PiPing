@preconcurrency import CloudKit

public enum SubscriptionInstallationResult: Equatable, Sendable {
    case alreadyInstalled
    case installed
}

public enum CloudKitSubscriptionError: Error, Equatable {
    case missingSaveResult
    case rejected(String)
}

public final class CloudKitSubscriptionInstaller: @unchecked Sendable {
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

    public func isInstalled() async throws -> Bool {
        do {
            _ = try await database.subscription(for: CloudKitSchema.subscriptionID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
    }

    public func installIfNeeded() async throws -> SubscriptionInstallationResult {
        if try await isInstalled() {
            return .alreadyInstalled
        }

        let subscription = CloudKitSchema.makeSubscription()
        let result = try await database.modifySubscriptions(
            saving: [subscription],
            deleting: []
        )
        guard let saveResult = result.saveResults[CloudKitSchema.subscriptionID] else {
            throw CloudKitSubscriptionError.missingSaveResult
        }
        switch saveResult {
        case .success:
            return .installed
        case let .failure(error):
            throw CloudKitSubscriptionError.rejected(String(describing: type(of: error)))
        }
    }
}

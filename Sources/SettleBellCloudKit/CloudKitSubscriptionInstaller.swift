@preconcurrency import CloudKit

public enum SubscriptionInstallationResult: Equatable, Sendable {
    case alreadyInstalled
    case installed
}

public enum CloudKitSubscriptionError: Error, Equatable {
    case missingSaveResult
    case subscriptionResetRequired
    case rejected(String)
}

public final class CloudKitSubscriptionInstaller: @unchecked Sendable {
    private let fetchSubscription: @Sendable () async throws -> CKSubscription
    private let saveSubscription: @Sendable (CKQuerySubscription) async throws -> Void

    public convenience init(containerIdentifier: String) {
        self.init(database: CloudKitConfiguration.container(
            identifier: containerIdentifier
        ).privateCloudDatabase)
    }

    public convenience init(container: CKContainer) {
        self.init(database: container.privateCloudDatabase)
    }

    public convenience init(database: CKDatabase) {
        self.init(
            fetchSubscription: {
                try await database.subscription(for: CloudKitSchema.subscriptionID)
            },
            saveSubscription: { subscription in
                let result = try await database.modifySubscriptions(
                    saving: [subscription], deleting: []
                )
                guard let saveResult = result.saveResults[CloudKitSchema.subscriptionID] else {
                    throw CloudKitSubscriptionError.missingSaveResult
                }
                switch saveResult {
                case let .success(saved):
                    guard CloudKitSchema.matchesSubscription(saved) else {
                        throw CloudKitSubscriptionError.subscriptionResetRequired
                    }
                case let .failure(error):
                    throw CloudKitSubscriptionError.rejected(String(describing: type(of: error)))
                }
            }
        )
    }

    // Internal seam for deterministic fixtures, with no CKContainer/network use.
    init(
        fetchSubscription: @escaping @Sendable () async throws -> CKSubscription,
        saveSubscription: @escaping @Sendable (CKQuerySubscription) async throws -> Void
    ) {
        self.fetchSubscription = fetchSubscription
        self.saveSubscription = saveSubscription
    }

    public func isInstalled() async throws -> Bool {
        do {
            let subscription = try await fetchSubscription()
            guard CloudKitSchema.matchesSubscription(subscription) else {
                throw CloudKitSubscriptionError.subscriptionResetRequired
            }
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
    }

    public func installIfNeeded() async throws -> SubscriptionInstallationResult {
        if try await isInstalled() {
            return .alreadyInstalled
        }
        try await saveSubscription(CloudKitSchema.makeSubscription())
        return .installed
    }
}

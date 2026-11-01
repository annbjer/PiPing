@preconcurrency import CloudKit
import Testing
@testable import SettleBellCloudKit

@Suite("CloudKit subscription reuse without network access")
struct CloudKitSubscriptionInstallerTests {
    @Test("correct existing subscription is reused without saving a duplicate")
    func correctReuse() async throws {
        let fixture = SubscriptionFixture(existing: CloudKitSchema.makeSubscription())
        let installer = fixture.installer()
        #expect(try await installer.isInstalled())
        #expect(try await installer.installIfNeeded() == .alreadyInstalled)
        let counts = await fixture.counts()
        #expect(counts.saves == 0)
    }

    @Test("mismatches fail both readiness and install without replacement", arguments: subscriptionMismatchCases)
    func mismatchRequiresReset(_ change: String) async {
        let fixture = SubscriptionFixture(existing: mismatchedSubscription(change))
        let installer = fixture.installer()
        await #expect(throws: CloudKitSubscriptionError.subscriptionResetRequired) {
            _ = try await installer.isInstalled()
        }
        await #expect(throws: CloudKitSubscriptionError.subscriptionResetRequired) {
            _ = try await installer.installIfNeeded()
        }
        let counts = await fixture.counts()
        #expect(counts.saves == 0)
    }

    @Test("missing subscription saves once; subsequent setup reuses it")
    func missingSubscription() async throws {
        let fixture = SubscriptionFixture(existing: nil)
        let installer = fixture.installer()
        #expect(try await !installer.isInstalled())
        #expect(try await installer.installIfNeeded() == .installed)
        #expect(try await installer.installIfNeeded() == .alreadyInstalled)
        let counts = await fixture.counts()
        #expect(counts.saves == 1)
    }

    @Test("fetch errors are not mistaken for absence and never trigger a save")
    func fetchFailure() async {
        let fixture = SubscriptionFixture(existing: nil, fetchError: CKError(.networkUnavailable))
        await #expect(throws: CKError.self) {
            _ = try await fixture.installer().installIfNeeded()
        }
        let counts = await fixture.counts()
        #expect(counts.saves == 0)
    }

    @Test("save failure does not report setup success")
    func saveFailure() async {
        let fixture = SubscriptionFixture(existing: nil, saveError: .missingSaveResult)
        await #expect(throws: CloudKitSubscriptionError.missingSaveResult) {
            _ = try await fixture.installer().installIfNeeded()
        }
        let counts = await fixture.counts()
        #expect(counts.saves == 1)
    }
}

private actor SubscriptionFixture {
    private var existing: CKSubscription?
    private let fetchError: CKError?
    private let saveError: CloudKitSubscriptionError?
    private var saves = 0

    init(existing: CKSubscription?, fetchError: CKError? = nil, saveError: CloudKitSubscriptionError? = nil) {
        self.existing = existing
        self.fetchError = fetchError
        self.saveError = saveError
    }

    nonisolated func installer() -> CloudKitSubscriptionInstaller {
        CloudKitSubscriptionInstaller(
            fetchSubscription: { try await self.fetch() },
            saveSubscription: { try await self.save($0) }
        )
    }

    func counts() -> (saves: Int, exists: Bool) {
        (saves, existing != nil)
    }

    private func fetch() throws -> CKSubscription {
        if let fetchError { throw fetchError }
        guard let existing else { throw CKError(.unknownItem) }
        return existing
    }

    private func save(_ subscription: CKQuerySubscription) throws {
        saves += 1
        #expect(CloudKitSchema.matchesSubscription(subscription))
        if let saveError { throw saveError }
        existing = subscription
    }
}

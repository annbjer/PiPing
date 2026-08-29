import Foundation
import PiPingCore
import Testing
import UserNotifications
@testable import PiPingMac

@Suite("Mac multi-session delivery")
struct MacAppStoreTests {
    @MainActor
    @Test("serializes overlapping attention delivery and acknowledges each request")
    func overlappingDelivery() async throws {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "PiPingCloudDeliveryApprovedV1")

        let notifications = RecordingNotifications()
        let publisher = RecordingPublisher()
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.PiPing.tests",
            defaults: defaults
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let firstToken = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let secondToken = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        store.receive(event(.start, firstToken), at: start)
        store.receive(event(.start, secondToken), at: start)
        store.receive(event(.settled, firstToken), at: start)
        store.receive(event(.settled, secondToken), at: start)

        for _ in 0..<100 {
            if await publisher.eventCount == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        let delivered = await notifications.events
        #expect(delivered.count == 2)
        #expect(await publisher.eventCount == 2)
        #expect(await publisher.maximumConcurrentPublications == 1)
        #expect(store.status == .attentionSent)
        #expect(store.cloudDeliveryStatus == .delivered)
        #expect(store.hasUnreadAttention)

        let appDelegate = AppDelegate(store: store)
        appDelegate.acknowledgeNotification(
            identifier: delivered[0].id.uuidString
        )
        #expect(store.hasUnreadAttention)
        appDelegate.acknowledgeNotification(
            identifier: delivered[1].id.uuidString
        )
        #expect(!store.hasUnreadAttention)
    }

    @MainActor
    @Test("an active run remains the primary status while delivery finishes")
    func runningStatusPrecedence() async throws {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "PiPingCloudDeliveryApprovedV1")
        let publisher = RecordingPublisher(delay: .milliseconds(50))
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: RecordingNotifications(),
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.PiPing.tests",
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let firstToken = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let secondToken = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        store.receive(event(.start, firstToken), at: now)
        store.receive(event(.settled, firstToken), at: now)
        store.receive(event(.start, secondToken), at: now)
        #expect(store.status == .running)

        for _ in 0..<100 {
            if await publisher.eventCount == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await publisher.eventCount == 1)
        #expect(store.status == .running)

        store.receive(event(.settled, secondToken), at: now)
        for _ in 0..<100 {
            if await publisher.eventCount == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await publisher.eventCount == 2)
        #expect(store.status == .attentionSent)
    }

    @MainActor
    @Test("starts FIFO listening from app launch without requiring a window")
    func launchStartsListener() {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            defaults: defaults
        )
        var startCount = 0
        let appDelegate = AppDelegate(
            store: store,
            listenerStarter: { startCount += 1 }
        )

        appDelegate.startListenerForApplicationLaunch()

        #expect(startCount == 1)
    }

    @MainActor
    @Test("refreshes the system authorization state after launch")
    func authorizationRefresh() async {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            defaults: defaults
        )

        #expect(store.authorization == .notDetermined)
        await store.refreshAuthorization()
        #expect(store.authorization == .authorized)
    }

    @MainActor
    @Test("a CloudKit-disabled build reports mobile delivery unavailable")
    func cloudDisabledStatus() {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            cloudActivationEnabled: false,
            cloudContainerIdentifier: nil,
            defaults: defaults
        )

        #expect(store.cloudDeliveryStatus == .unavailable)
        #expect(store.cloudDeliveryStatus.label == "Unavailable in this build")
    }

    @MainActor
    @Test("a configured CloudKit build still requires explicit approval")
    func cloudCapableStatus() {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.PiPing.tests",
            defaults: defaults
        )

        #expect(store.cloudDeliveryStatus == .disabled)
        #expect(store.cloudDeliveryStatus.label == "Setup required")
    }

    @MainActor
    @Test("failed local delivery does not leave an unacknowledgeable unread ID")
    func failedDeliveryClearsUnreadID() async throws {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: DisabledAttentionPublisher(),
            notifications: FailingNotifications(),
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        store.receive(event(.start, token), at: now)
        store.receive(event(.settled, token), at: now)
        #expect(store.hasUnreadAttention)
        for _ in 0..<100 {
            if store.status == .attentionFailed { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.status == .attentionFailed)
        #expect(!store.hasUnreadAttention)
        #expect(store.unreadAttentionCount == 0)
    }

    @MainActor
    @Test("unread capacity rejects a new delivery without evicting visible IDs")
    func unreadCapacity() async throws {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let notifications = RecordingNotifications()
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: DisabledAttentionPublisher(),
            notifications: notifications,
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        for batch in 0..<4 {
            for value in (batch * 64 + 1)...((batch + 1) * 64) {
                let token = LocalSessionToken(
                    uuid: UUID(
                        uuidString: String(
                            format: "00000000-0000-0000-0000-%012x",
                            value
                        )
                    )!
                )
                store.receive(event(.start, token), at: now)
                store.receive(event(.settled, token), at: now)
            }
            let expectedCount = (batch + 1) * 64
            for _ in 0..<100 {
                if await notifications.events.count == expectedCount { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(await notifications.events.count == expectedCount)
        }
        #expect(store.unreadAttentionCount == 256)

        let rejectedToken = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000fff")!
        )
        store.receive(event(.start, rejectedToken), at: now)
        store.receive(event(.settled, rejectedToken), at: now)
        #expect(store.status == .trackingLimitReached)
        #expect(store.unreadAttentionCount == 256)
        let delivered = await notifications.events
        #expect(delivered.count == 256)

        let appDelegate = AppDelegate(store: store)
        for notification in delivered {
            appDelegate.acknowledgeNotification(
                identifier: notification.id.uuidString
            )
        }
        #expect(store.unreadAttentionCount == 0)
        #expect(!store.hasUnreadAttention)
    }

    @MainActor
    @Test("attention category is actionless and reports native dismissals")
    func dismissalCategory() {
        let category = SystemLocalNotificationService.attentionCategory
        #expect(
            category.identifier
                == SystemLocalNotificationService.attentionCategoryIdentifier
        )
        #expect(category.actions.isEmpty)
        #expect(category.options.contains(.customDismissAction))
    }

    @MainActor
    @Test("opening the menu acknowledges every pending request")
    func acknowledgeAll() {
        let defaultsName = "PiPingMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        store.receive(event(.start, token), at: now)
        store.receive(event(.settled, token), at: now)
        #expect(store.hasUnreadAttention)
        store.acknowledgeAttention()
        #expect(!store.hasUnreadAttention)
    }

    private func event(
        _ signal: LocalSignal,
        _ token: LocalSessionToken
    ) -> LocalLifecycleEvent {
        LocalLifecycleEvent(signal: signal, sessionToken: token)
    }
}

private actor RecordingNotifications: LocalNotificationDelivering {
    private(set) var events: [AttentionEvent] = []

    func authorization() async -> LocalNotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }

    func deliver(_ event: AttentionEvent) async throws {
        events.append(event)
    }
}

private actor FailingNotifications: LocalNotificationDelivering {
    func authorization() async -> LocalNotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }

    func deliver(_ event: AttentionEvent) async throws {
        throw LocalNotificationDeliveryError.notAuthorized
    }
}

private actor RecordingPublisher: AttentionPublishing {
    private let delay: Duration
    private var activePublications = 0
    private(set) var maximumConcurrentPublications = 0
    private(set) var eventCount = 0

    init(delay: Duration = .milliseconds(5)) {
        self.delay = delay
    }

    func publish(_ event: AttentionEvent) async throws {
        activePublications += 1
        maximumConcurrentPublications = max(
            maximumConcurrentPublications,
            activePublications
        )
        try await Task.sleep(for: delay)
        eventCount += 1
        activePublications -= 1
    }
}

import Foundation
import Observation
import SettleBellCore
import SwiftUI
import Synchronization
import Testing
import UserNotifications
@testable import SettleBellMac

@Suite("Mac multi-session delivery")
struct MacAppStoreTests {
    @MainActor
    @Test("serializes overlapping attention delivery and acknowledges each request")
    func overlappingDelivery() async throws {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "SettleBellCloudDeliveryApprovedV1")

        let notifications = RecordingNotifications()
        let publisher = RecordingPublisher()
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
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
        #expect(store.cloudDeliveryStatus.label == "Published")
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "SettleBellCloudDeliveryApprovedV1")
        let publisher = RecordingPublisher(delay: .milliseconds(50))
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: RecordingNotifications(),
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let store = MacAppStore(
            publisher: DisabledAttentionPublisher(),
            notifications: RecordingNotifications(),
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
            defaults: defaults
        )

        #expect(store.cloudDeliveryStatus == .disabled)
        #expect(store.cloudDeliveryStatus.label == "Setup required")
    }

    @MainActor
    @Test("both windows observe approval status without performing setup")
    func cloudStatusViewObservation() async {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let publisher = RecordingPublisher()
        let notifications = RecordingNotifications()
        let store = MacAppStore(
            publisher: publisher,
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
            defaults: defaults
        )
        let settingsChanges = Mutex(0)
        let contentChanges = Mutex(0)

        // Read each view independently: observing ContentView alone would not
        // catch a return to the old hardcoded Settings label.
        for enabled in [true, false] {
            withObservationTracking {
                _ = SettingsView(store: store).body
            } onChange: {
                settingsChanges.withLock { $0 += 1 }
            }
            withObservationTracking {
                _ = ContentView(store: store).body
            } onChange: {
                contentChanges.withLock { $0 += 1 }
            }
            #expect(store.cloudDeliveryEnabled != enabled)
            #expect(await publisher.eventCount == 0)
            #expect(await notifications.events.isEmpty)
            #expect(store.authorization == .notDetermined)
            #expect(defaults.bool(forKey: "SettleBellCloudDeliveryApprovedV1") != enabled)

            if enabled {
                store.enableCloudDelivery()
                #expect(store.cloudDeliveryStatus.label == "Ready")
            } else {
                store.disableCloudDelivery()
                #expect(store.cloudDeliveryStatus.label == "Setup required")
            }
            let expectedChanges = enabled ? 1 : 2
            #expect(settingsChanges.withLock { $0 } == expectedChanges)
            #expect(contentChanges.withLock { $0 } == expectedChanges)
            #expect(store.cloudDeliveryEnabled == enabled)
        }
        #expect(await publisher.eventCount == 0)
        #expect(await notifications.events.isEmpty)
    }

    @MainActor
    @Test("failed Cloud publication reports attention while local delivery succeeds")
    func cloudFailureStatus() async throws {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "SettleBellCloudDeliveryApprovedV1")
        let notifications = RecordingNotifications()
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: FailingPublisher(),
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
            defaults: defaults
        )
        let token = LocalSessionToken(uuid: UUID())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        store.receive(event(.start, token), at: now)
        store.receive(event(.settled, token), at: now)
        for _ in 0..<100 {
            if store.cloudDeliveryStatus == .failed { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.cloudDeliveryStatus == .failed)
        #expect(store.cloudDeliveryStatus.label == "Delivery needs attention")
        #expect(store.status == .attentionSent)
        #expect(await notifications.events.count == 1)
    }

    @MainActor
    @Test("disable invalidates queued and in-flight consent", arguments: [false, true], [false, true])
    func disableWithPendingCloudWork(failFirst: Bool, reenable: Bool) async throws {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(true, forKey: "SettleBellCloudDeliveryApprovedV1")
        let publisher = PausingPublisher()
        defer { Task { await publisher.release(fail: false) } }
        let notifications = RecordingNotifications()
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for _ in 0..<2 {
            let token = LocalSessionToken(uuid: UUID())
            store.receive(event(.start, token), at: now)
            store.receive(event(.settled, token), at: now)
        }
        try await waitUntil { await publisher.isPaused }
        store.disableCloudDelivery()
        if reenable { store.enableCloudDelivery() }
        await publisher.release(fail: failFirst)
        try await waitUntil {
            await notifications.events.count == 2 && store.status == .attentionSent
        }
        #expect(await publisher.events.count == 1)
        #expect(store.cloudDeliveryStatus == (reenable ? .ready : .disabled))
        #expect(store.cloudDeliveryEnabled == reenable)
        #expect(store.unreadAttentionCount == 2)

        // Re-enable permits future attention, not the old queued completion.
        if !reenable { store.enableCloudDelivery() }
        let fresh = LocalSessionToken(uuid: UUID())
        store.receive(event(.start, fresh), at: now)
        store.receive(event(.settled, fresh), at: now)
        try await waitUntil {
            await publisher.events.count >= 2 && store.status == .attentionSent
        }
        #expect(await publisher.events.count == 2)
        #expect(await notifications.events.count == 3)
        #expect(store.cloudDeliveryStatus == .delivered)
    }

    @MainActor
    @Test("consent is rechecked after local delivery without retroactive opt-in", arguments: [false, true])
    func consentChangesDuringLocalDelivery(wasEnabled: Bool) async throws {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.set(wasEnabled, forKey: "SettleBellCloudDeliveryApprovedV1")
        let publisher = RecordingPublisher()
        let notifications = PausingNotifications()
        defer { Task { await notifications.release() } }
        let store = MacAppStore(
            notificationThreshold: .everyCompletion,
            publisher: publisher,
            notifications: notifications,
            cloudActivationEnabled: true,
            cloudContainerIdentifier: "iCloud.org.example.SettleBell.tests",
            defaults: defaults
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = LocalSessionToken(uuid: UUID())
        store.receive(event(.start, token), at: now)
        store.receive(event(.settled, token), at: now)
        try await waitUntil { await notifications.isPaused }
        if wasEnabled { store.disableCloudDelivery() } else { store.enableCloudDelivery() }
        await notifications.release()
        try await waitUntil { store.status == .attentionSent }
        #expect(await publisher.eventCount == 0)
        #expect(store.cloudDeliveryStatus == (wasEnabled ? .disabled : .ready))
        #expect(store.unreadAttentionCount == 1)
    }

    @MainActor
    private func waitUntil(_ condition: @MainActor () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(await condition(), "Timed out waiting for controlled fixture")
    }

    @MainActor
    @Test("failed local delivery does not leave an unacknowledgeable unread ID")
    func failedDeliveryClearsUnreadID() async throws {
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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
        let defaultsName = "SettleBellMacTests-\(UUID().uuidString)"
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

private actor FailingPublisher: AttentionPublishing {
    private enum Failure: Error { case unavailable }

    func publish(_ event: AttentionEvent) async throws {
        throw Failure.unavailable
    }
}

private actor PausingPublisher: AttentionPublishing {
    private enum Failure: Error { case unavailable }
    private var continuation: CheckedContinuation<Void, Error>?
    private(set) var events: [AttentionEvent] = []
    var isPaused: Bool { continuation != nil }

    func publish(_ event: AttentionEvent) async throws {
        events.append(event)
        if events.count == 1 {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
    }

    func release(fail: Bool) {
        let pending = continuation
        continuation = nil
        if fail { pending?.resume(throwing: Failure.unavailable) }
        else { pending?.resume() }
    }
}

private actor PausingNotifications: LocalNotificationDelivering {
    private var continuation: CheckedContinuation<Void, Never>?
    var isPaused: Bool { continuation != nil }
    func authorization() async -> LocalNotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func deliver(_ event: AttentionEvent) async throws {
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        let pending = continuation
        continuation = nil
        pending?.resume()
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

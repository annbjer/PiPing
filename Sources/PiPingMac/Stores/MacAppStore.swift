import Foundation
import Observation
import PiPingCloudKit
import PiPingCore

@MainActor
@Observable
final class MacAppStore {
    enum RunStatus: Equatable {
        case listening
        case running
        case ignoredShortRun
        case sendingAttention
        case attentionSent
        case attentionFailed
        case listenerError

        var label: String {
            switch self {
            case .listening: "Listening"
            case .running: "Pi is running"
            case .ignoredShortRun: "Short run ignored"
            case .sendingAttention: "Sending attention"
            case .attentionSent: "Attention sent"
            case .attentionFailed: "Notification not sent"
            case .listenerError: "Listener unavailable"
            }
        }

        var symbol: String {
            switch self {
            case .listening: "ear"
            case .running: "hourglass"
            case .ignoredShortRun: "bell.slash"
            case .sendingAttention: "bell"
            case .attentionSent: "bell.badge"
            case .attentionFailed: "bell.slash"
            case .listenerError: "exclamationmark.triangle"
            }
        }
    }

    enum CloudDeliveryStatus: Equatable {
        case disabled
        case unavailable
        case ready
        case delivered
        case failed

        var label: String {
            switch self {
            case .disabled: "Setup required"
            case .unavailable: "Local configuration required"
            case .ready: "Ready"
            case .delivered: "Published"
            case .failed: "Delivery needs attention"
            }
        }
    }

    private var gate: LifecycleGate
    private let publisher: any AttentionPublishing
    private let notifications: any LocalNotificationDelivering
    private let defaults: UserDefaults
    private let cloudDeliveryAvailable: Bool
    private let signalMailbox: LocalSignalMailbox
    private var listener: LocalSignalListener?
    private var signalConsumerTask: Task<Void, Never>?

    private(set) var status: RunStatus = .listening
    private(set) var authorization: LocalNotificationAuthorization = .notDetermined
    private(set) var lastElapsed: TimeInterval?
    private(set) var hasUnreadAttention = false
    private(set) var cloudDeliveryEnabled: Bool
    private(set) var cloudDeliveryStatus: CloudDeliveryStatus

    let minimumDuration: TimeInterval

    init(
        minimumDuration: TimeInterval = LifecycleGate.defaultMinimumDuration,
        publisher: (any AttentionPublishing)? = nil,
        notifications: any LocalNotificationDelivering = SystemLocalNotificationService(),
        signalMailboxCapacity: Int = LocalSignalMailbox.defaultCapacity,
        cloudActivationEnabled: Bool = FeatureGates.cloudKitActivationEnabled,
        cloudContainerIdentifier: String? = CloudKitConfiguration.containerIdentifier(),
        defaults: UserDefaults = .standard
    ) {
        self.minimumDuration = minimumDuration
        gate = LifecycleGate(minimumDuration: minimumDuration)
        let cloudDeliveryAvailable = cloudActivationEnabled && cloudContainerIdentifier != nil
        if let publisher {
            self.publisher = publisher
        } else if let cloudContainerIdentifier, cloudDeliveryAvailable {
            self.publisher = CloudKitAttentionPublisher(
                containerIdentifier: cloudContainerIdentifier
            )
        } else {
            self.publisher = DisabledAttentionPublisher()
        }
        self.notifications = notifications
        self.defaults = defaults
        self.cloudDeliveryAvailable = cloudDeliveryAvailable
        signalMailbox = LocalSignalMailbox(capacity: signalMailboxCapacity)
        let approved = defaults.bool(forKey: Self.cloudApprovalDefaultsKey)
        let cloudDeliveryEnabled = cloudDeliveryAvailable && approved
        self.cloudDeliveryEnabled = cloudDeliveryEnabled
        if cloudDeliveryEnabled {
            cloudDeliveryStatus = .ready
        } else if cloudActivationEnabled && !cloudDeliveryAvailable {
            cloudDeliveryStatus = .unavailable
        } else {
            cloudDeliveryStatus = .disabled
        }
    }

    func startListening() {
        guard listener == nil else { return }
        let mailbox = signalMailbox
        signalConsumerTask = Task { @MainActor [weak self, mailbox] in
            while let event = await mailbox.next() {
                guard let self else { return }
                switch event {
                case let .signal(received):
                    self.receive(received.signal, at: received.receivedAt)
                case .overflow:
                    self.gate.reset()
                    self.lastElapsed = nil
                    self.status = .listening
                }
            }
        }
        let newListener = LocalSignalListener(
            onSignal: { signal in
                // Overflow is intentionally fail-quiet. The mailbox discards
                // ambiguous queued state and asks the sole consumer to reset.
                _ = mailbox.send(signal, receivedAt: Date())
            },
            onError: { [weak self] _ in
                mailbox.finish()
                Task { @MainActor in self?.status = .listenerError }
            }
        )
        listener = newListener
        newListener.start()
        Task { await refreshAuthorization() }
    }

    func receive(_ signal: LocalSignal, at date: Date) {
        let decision = gate.receive(signal, at: date)
        switch decision {
        case .started:
            status = .running
        case .ignoredDuplicateStart:
            break
        case .ignoredMissingStart:
            status = .listening
        case let .ignoredTooShort(elapsed):
            lastElapsed = elapsed
            status = .ignoredShortRun
        case let .attention(elapsed):
            lastElapsed = elapsed
            hasUnreadAttention = true
            status = .sendingAttention
            let event = AttentionEvent(occurredAt: date)
            Task {
                var sent = false
                do {
                    try await notifications.deliver(event)
                    sent = true
                } catch {
                    // Remote delivery can still succeed when Mac notifications
                    // are unavailable, so resolve the final status after both paths.
                }
                if cloudDeliveryEnabled {
                    do {
                        try await publisher.publish(event)
                        cloudDeliveryStatus = .delivered
                        sent = true
                    } catch {
                        cloudDeliveryStatus = .failed
                    }
                }
                status = sent ? .attentionSent : .attentionFailed
            }
        }
    }

    func requestNotificationPermission() async {
        _ = try? await notifications.requestAuthorization()
        await refreshAuthorization()
    }

    func refreshAuthorization() async {
        authorization = await notifications.authorization()
    }

    func acknowledgeAttention() {
        hasUnreadAttention = false
    }

    func enableCloudDelivery() {
        guard cloudDeliveryAvailable else { return }
        defaults.set(true, forKey: Self.cloudApprovalDefaultsKey)
        cloudDeliveryEnabled = true
        cloudDeliveryStatus = .ready
    }

    func disableCloudDelivery() {
        defaults.set(false, forKey: Self.cloudApprovalDefaultsKey)
        cloudDeliveryEnabled = false
        cloudDeliveryStatus = cloudDeliveryAvailable ? .disabled : .unavailable
    }

    private static let cloudApprovalDefaultsKey = "PiPingCloudDeliveryApprovedV1"
}

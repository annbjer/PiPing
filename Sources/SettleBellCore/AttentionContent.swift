import Foundation

/// The complete remote and local notification content allowed in Phase 1.
public enum AttentionContent {
    public static let title = "Pi needs attention"
    public static let body = "Pi has fully settled and is ready for you."
}

public struct AttentionEvent: Equatable, Sendable {
    public let id: UUID
    public let occurredAt: Date

    public init(id: UUID = UUID(), occurredAt: Date = Date()) {
        self.id = id
        self.occurredAt = occurredAt
    }

    public var title: String { AttentionContent.title }
    public var body: String { AttentionContent.body }
}

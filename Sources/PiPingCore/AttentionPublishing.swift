public protocol AttentionPublishing: Sendable {
    func publish(_ event: AttentionEvent) async throws
}

public struct DisabledAttentionPublisher: AttentionPublishing {
    public init() {}

    public func publish(_ event: AttentionEvent) async throws {
        // Intentionally inert until CloudKit entitlements and signing are approved.
    }
}

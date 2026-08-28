import Foundation

public enum RemoteNotificationRegistrationError: Error, Equatable, Sendable {
    case registrationFailed
    case timedOut
    case alreadyInProgress
    case cancelled
}

/// Converts the one-shot APNs delegate callback into a bounded async operation.
/// Late callbacks after failure, timeout, or cancellation are intentionally ignored.
@MainActor
public final class RemoteNotificationRegistrationWaiter {
    private struct PendingRegistration {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var pending: PendingRegistration?

    public init() {}

    public func wait(
        timeout: Duration = .seconds(15),
        start: @MainActor () -> Void
    ) async throws {
        guard pending == nil else {
            throw RemoteNotificationRegistrationError.alreadyInProgress
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = PendingRegistration(
                    id: id,
                    continuation: continuation,
                    timeoutTask: nil
                )

                let timeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    self?.finish(
                        id: id,
                        result: .failure(RemoteNotificationRegistrationError.timedOut)
                    )
                }
                pending?.timeoutTask = timeoutTask
                start()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(
                    id: id,
                    result: .failure(RemoteNotificationRegistrationError.cancelled)
                )
            }
        }
    }

    public func didRegister() {
        finish(result: .success(()))
    }

    public func didFail() {
        finish(result: .failure(RemoteNotificationRegistrationError.registrationFailed))
    }

    private func finish(result: Result<Void, any Error>) {
        guard let pending else { return }
        finish(id: pending.id, result: result)
    }

    private func finish(id: UUID, result: Result<Void, any Error>) {
        guard let registration = pending, registration.id == id else { return }
        pending = nil
        registration.timeoutTask?.cancel()
        registration.continuation.resume(with: result)
    }
}

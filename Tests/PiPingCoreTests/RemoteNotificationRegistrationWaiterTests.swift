import Testing
@testable import PiPingCore

@Suite("Remote notification registration waiter")
@MainActor
struct RemoteNotificationRegistrationWaiterTests {
    @Test("accepts an immediate successful callback")
    func immediateSuccess() async throws {
        let waiter = RemoteNotificationRegistrationWaiter()

        try await waiter.wait(timeout: .seconds(1)) {
            waiter.didRegister()
        }
    }

    @Test("accepts a delayed successful callback")
    func delayedSuccess() async throws {
        let waiter = RemoteNotificationRegistrationWaiter()

        try await waiter.wait(timeout: .seconds(1)) {
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(20))
                waiter.didRegister()
            }
        }
    }

    @Test("reports a failed registration callback")
    func failedRegistration() async {
        let waiter = RemoteNotificationRegistrationWaiter()

        let error = await registrationError {
            try await waiter.wait(timeout: .seconds(1)) {
                waiter.didFail()
            }
        }

        #expect(error == .registrationFailed)
    }

    @Test("times out when the system does not call back")
    func missingCallback() async {
        let waiter = RemoteNotificationRegistrationWaiter()

        let error = await registrationError {
            try await waiter.wait(timeout: .milliseconds(20)) {}
        }

        #expect(error == .timedOut)
    }

    @Test("a timed-out attempt requires a fresh process before retry")
    func lateCallbackRequiresRestart() async {
        let waiter = RemoteNotificationRegistrationWaiter()

        let timeoutError = await registrationError {
            try await waiter.wait(timeout: .milliseconds(20)) {}
        }
        #expect(timeoutError == .timedOut)

        waiter.didRegister()
        let retryError = await registrationError {
            try await waiter.wait(timeout: .seconds(1)) {
                waiter.didRegister()
            }
        }
        #expect(retryError == .restartRequired)
    }

    @Test("a failed callback permits a clean retry")
    func failedCallbackAndRetry() async throws {
        let waiter = RemoteNotificationRegistrationWaiter()

        let failure = await registrationError {
            try await waiter.wait(timeout: .seconds(1)) {
                waiter.didFail()
            }
        }
        #expect(failure == .registrationFailed)

        try await waiter.wait(timeout: .seconds(1)) {
            waiter.didRegister()
        }
    }

    @Test("cancellation releases the wait and requires a fresh process")
    func cancellation() async {
        let waiter = RemoteNotificationRegistrationWaiter()
        var started = false
        let task = Task { @MainActor in
            try await waiter.wait(timeout: .seconds(1)) {
                started = true
            }
        }

        while !started {
            await Task.yield()
        }
        task.cancel()

        let error = await registrationError {
            try await task.value
        }
        #expect(error == .cancelled)

        let retryError = await registrationError {
            try await waiter.wait(timeout: .seconds(1)) {
                waiter.didRegister()
            }
        }
        #expect(retryError == .restartRequired)
    }

    private func registrationError(
        _ operation: () async throws -> Void
    ) async -> RemoteNotificationRegistrationError? {
        do {
            try await operation()
            return nil
        } catch let error as RemoteNotificationRegistrationError {
            return error
        } catch {
            return nil
        }
    }
}

import Foundation
import Testing
@testable import PiPingCore

@Suite("Phase 1 privacy boundary")
struct PrivacyBoundaryTests {
    @Test("notification copy is fixed and concise")
    func fixedCopy() {
        let event = AttentionEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(event.title == "Pi needs attention")
        #expect(event.body == "Pi has fully settled and is ready for you.")
        #expect(event.title.count < 40)
        #expect(event.body.count < 80)
    }

    @Test("wire protocol accepts only fixed signals plus an opaque UUID")
    func signalAllowlist() {
        let token = LocalSessionToken(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let start = LocalLifecycleEvent(signal: .start, sessionToken: token)
        let settled = LocalLifecycleEvent(signal: .settled, sessionToken: token)

        #expect(LocalLifecycleEvent(wireValue: start.wireValue) == start)
        #expect(LocalLifecycleEvent(wireValue: settled.wireValue) == settled)
        #expect(LocalLifecycleEvent(wireValue: "start\n") == nil)
        #expect(LocalLifecycleEvent(wireValue: "proceed \(token.wireValue)\n") == nil)
        #expect(LocalLifecycleEvent(wireValue: "start synthetic-prompt\n") == nil)
        #expect(LocalLifecycleEvent(wireValue: " start \(token.wireValue)\n") == nil)
        #expect(LocalLifecycleEvent(wireValue: start.wireValue + settled.wireValue) == nil)
    }

    @Test("remote delivery defaults off and accepts only explicit true values")
    func featureGates() {
        #expect(!FeatureGates.cloudKitActivationEnabled)
        #expect(!FeatureGates.cloudKitActivationEnabled(value: nil))
        #expect(!FeatureGates.cloudKitActivationEnabled(value: "NO"))
        #expect(FeatureGates.cloudKitActivationEnabled(value: "YES"))
        #expect(FeatureGates.cloudKitActivationEnabled(value: true))
        #expect(!FeatureGates.phaseTwoControlsEnabled)
    }

    @Test("runtime paths derive from a supplied home directory")
    func portableRuntimePath() {
        let syntheticHome = URL(fileURLWithPath: "/synthetic/home", isDirectory: true)
        #expect(
            RuntimePath.fifo(homeDirectory: syntheticHome).path
                == "/synthetic/home/.piping/events.fifo"
        )
    }
}

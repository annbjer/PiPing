#if os(iOS)
import SettleBellCore
import SwiftUI

struct MobileStatusView: View {
    let store: MobileSetupStore

    var body: some View {
        List {
            Section("Delivery") {
                LabeledContent("Status", value: store.status.label)
                LabeledContent("Apple Watch", value: "Mirrors iPhone")
                LabeledContent("Sound", value: "Normal system sound")
            }

            Section("Lock-screen preview") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AttentionContent.title)
                        .font(.headline)
                    Text(AttentionContent.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                if store.status == .ready {
                    Label("Notifications configured", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if store.status == .registrationRestartRequired {
                    Label("Close and reopen SettleBell before retrying", systemImage: "arrow.clockwise")
                        .foregroundStyle(.orange)
                } else if store.status == .subscriptionResetRequired {
                    Label("Existing subscription differs; review CloudKit setup before retrying", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Button(
                        store.status == .configuring
                            ? "Configuring…"
                            : "Configure Notifications"
                    ) {
                        Task { await store.configureAfterExplicitApproval() }
                    }
                    .disabled(
                        store.status == .configuring || !FeatureGates.cloudKitActivationEnabled
                    )
                }
            } footer: {
                if FeatureGates.cloudKitActivationEnabled {
                    Text("Requests notification permission and verifies or creates one fixed subscription in your private iCloud database. An existing mismatch requires separately reviewed recovery.")
                } else {
                    Text("Disabled until the local signing and CloudKit configuration is approved.")
                }
            }

            Section("Phase 1 boundary") {
                Label("Notifications only", systemImage: "arrow.right")
                Label("No replies or remote actions", systemImage: "hand.raised.slash")
            }
        }
        .navigationTitle("SettleBell")
    }
}
#endif

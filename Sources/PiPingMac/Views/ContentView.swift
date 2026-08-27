import PiPingCore
import SwiftUI

struct ContentView: View {
    let store: MacAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: store.status.symbol)
                    .font(.title2)
                    .foregroundStyle(
                        store.status == .listenerError ? Color.orange : Color.accentColor
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.status.label)
                        .font(.title3.weight(.semibold))
                    Text("Runs shorter than \(Int(store.minimumDuration)) seconds stay quiet.")
                        .foregroundStyle(.secondary)
                }
            }

            NotificationPreviewCard()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Mac notifications")
                    Text(permissionLabel)
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("iPhone / Watch")
                    Text(store.cloudDeliveryStatus.label)
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Remote control")
                    Text("Not available in Phase 1")
                        .foregroundStyle(.secondary)
                }
            }

            if store.authorization == .notDetermined {
                Button("Allow Mac Notifications") {
                    Task { await store.requestNotificationPermission() }
                }
                .buttonStyle(.borderedProminent)
            }

            if FeatureGates.cloudKitActivationEnabled {
                if store.cloudDeliveryEnabled {
                    Button("Disable iPhone / Watch Delivery") {
                        store.disableCloudDelivery()
                    }
                } else {
                    Button("Enable iPhone / Watch Delivery") {
                        store.enableCloudDelivery()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.cloudDeliveryStatus == .unavailable)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 390)
        .task { store.startListening() }
    }

    private var permissionLabel: String {
        switch store.authorization {
        case .notDetermined: "Not requested"
        case .denied: "Denied in System Settings"
        case .authorized: "Allowed"
        }
    }
}

import PiPingCore
import SwiftUI

struct SettingsView: View {
    let store: MacAppStore

    var body: some View {
        Form {
            Picker("Notify me", selection: thresholdBinding) {
                ForEach(NotificationThreshold.allCases) { threshold in
                    Text(threshold.title).tag(threshold)
                }
            }
            Text("Shorter Pi runs stay quiet unless Every completion is selected.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("CloudKit", value: "Inactive until approved setup")
            LabeledContent("Phase 1", value: "Notifications only")
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 430)
    }

    private var thresholdBinding: Binding<NotificationThreshold> {
        Binding(
            get: { store.notificationThreshold },
            set: { store.setNotificationThreshold($0) }
        )
    }
}

private extension NotificationThreshold {
    var title: String {
        switch self {
        case .everyCompletion: "Every completion"
        case .fifteenSeconds: "After 15 seconds"
        case .thirtySeconds: "After 30 seconds"
        }
    }
}

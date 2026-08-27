import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Minimum duration", value: "30 seconds")
            LabeledContent("CloudKit", value: "Inactive until approved setup")
            LabeledContent("Phase 1", value: "Notifications only")
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 430)
    }
}

import PiPingCore
import SwiftUI

struct NotificationPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notification preview", systemImage: "bell")
                .font(.headline)
            Text(AttentionContent.title)
                .font(.body.weight(.semibold))
            Text(AttentionContent.body)
                .foregroundStyle(.secondary)
            Label("Normal system sound", systemImage: "speaker.wave.2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

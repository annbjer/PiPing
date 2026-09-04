import AppKit
import SwiftUI

@MainActor
enum SettleBellVisualIdentity {
    static let menuSymbolSize = NSSize(width: 18, height: 18)

    static func menuBarImage(
        attention: Bool,
        colorScheme: ColorScheme,
        bundle: Bundle = .main
    ) -> NSImage {
        let resourceName: String
        if attention {
            resourceName = colorScheme == .dark
                ? "SettleBellMenuBarAttentionDark"
                : "SettleBellMenuBarAttentionLight"
        } else {
            resourceName = "SettleBellMenuBar"
        }

        let image = bundle.url(forResource: resourceName, withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(
                systemSymbolName: attention ? "bell.badge" : "bell",
                accessibilityDescription: "SettleBell"
            )
            ?? NSImage(size: menuSymbolSize)
        image.size = menuSymbolSize
        image.isTemplate = !attention
        image.accessibilityDescription = attention
            ? "SettleBell needs attention"
            : "SettleBell"
        return image
    }
}

struct MenuBarLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let hasUnreadAttention: Bool

    var body: some View {
        Image(
            nsImage: SettleBellVisualIdentity.menuBarImage(
                attention: hasUnreadAttention,
                colorScheme: colorScheme
            )
        )
        .renderingMode(hasUnreadAttention ? .original : .template)
        .resizable()
        .scaledToFit()
        .frame(width: 18, height: 18)
        .accessibilityLabel(
            hasUnreadAttention ? "SettleBell needs attention" : "SettleBell"
        )
    }
}

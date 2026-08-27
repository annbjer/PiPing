import AppKit
import SwiftUI

@MainActor
enum PiPingVisualIdentity {
    static let menuSymbolSize = NSSize(width: 18, height: 18)

    static func menuBarImage(
        attention: Bool,
        colorScheme: ColorScheme,
        bundle: Bundle = .main
    ) -> NSImage {
        let resourceName: String
        if attention {
            resourceName = colorScheme == .dark
                ? "PiPingMenuBarAttentionDark"
                : "PiPingMenuBarAttentionLight"
        } else {
            resourceName = "PiPingMenuBar"
        }

        let image = bundle.url(forResource: resourceName, withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(
                systemSymbolName: attention ? "bell.badge" : "bell",
                accessibilityDescription: "PiPing"
            )
            ?? NSImage(size: menuSymbolSize)
        image.size = menuSymbolSize
        image.isTemplate = !attention
        image.accessibilityDescription = attention
            ? "PiPing needs attention"
            : "PiPing"
        return image
    }
}

struct MenuBarLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let hasUnreadAttention: Bool

    var body: some View {
        Image(
            nsImage: PiPingVisualIdentity.menuBarImage(
                attention: hasUnreadAttention,
                colorScheme: colorScheme
            )
        )
        .renderingMode(hasUnreadAttention ? .original : .template)
        .resizable()
        .scaledToFit()
        .frame(width: 18, height: 18)
        .accessibilityLabel(
            hasUnreadAttention ? "PiPing needs attention" : "PiPing"
        )
    }
}

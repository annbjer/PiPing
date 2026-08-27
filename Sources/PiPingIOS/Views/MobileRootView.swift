#if os(iOS)
import SwiftUI

private enum MobileTab: Hashable {
    case status
    case privacy
}

struct MobileRootView: View {
    let store: MobileSetupStore
    @State private var selectedTab: MobileTab = .status

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MobileStatusView(store: store)
            }
            .tabItem { Label("Status", systemImage: "bell") }
            .tag(MobileTab.status)

            NavigationStack {
                PrivacyView()
            }
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
            .tag(MobileTab.privacy)
        }
        .task { await store.refreshExistingConfiguration() }
    }
}
#endif

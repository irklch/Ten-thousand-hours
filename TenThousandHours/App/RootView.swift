import SwiftUI

struct RootView: View {
    @Environment(TrackingStore.self) private var trackingStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            HistoryView()
                .tabItem { Label(AppTab.history.title, systemImage: AppTab.history.systemImage) }
                .tag(AppTab.history)
        }
        .tint(AppColor.primaryText)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                trackingStore.restore()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(TrackingStore.preview())
}

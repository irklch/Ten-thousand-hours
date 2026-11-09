import SwiftUI

struct RootView: View {
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
    }
}

#Preview {
    RootView()
}

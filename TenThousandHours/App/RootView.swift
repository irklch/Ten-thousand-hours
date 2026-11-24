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
        // Нажатие на напоминание открывает главную; таймер при этом не запускается.
        .onReceive(NotificationCenter.default.publisher(for: .dailyReminderOpened)) { _ in
            selectedTab = .home
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { trackingStore.isCelebrationPending },
                set: { isPresented in
                    if !isPresented { trackingStore.dismissCelebration() }
                }
            )
        ) {
            GoalCelebrationView()
                .environment(trackingStore)
        }
    }
}

#Preview {
    RootView()
        .environment(TrackingStore.preview())
}

import SwiftUI

struct HomeView: View {
    var body: some View {
        ContentUnavailableView(
            "Главная",
            systemImage: AppTab.home.systemImage,
            description: Text("Таймер и прогресс появятся здесь")
        )
        .foregroundStyle(AppColor.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
    }
}

#Preview {
    HomeView()
}

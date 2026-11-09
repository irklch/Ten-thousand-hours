import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Сессий пока нет",
                systemImage: AppTab.history.systemImage,
                description: Text("Завершённые сессии появятся здесь")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.background)
            .navigationTitle("История")
        }
    }
}

#Preview {
    HistoryView()
}

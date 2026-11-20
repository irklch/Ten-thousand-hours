import SwiftUI

struct HistoryView: View {
    @Environment(TrackingStore.self) private var store
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    AppColor.background
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.background)
            .navigationTitle("История")
        }
        .task(id: store.sessionsRevision) {
            let model = viewModel ?? HistoryViewModel(store: store)
            model.reload()
            viewModel = model
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HistoryViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "Сессий пока нет",
                    systemImage: AppTab.history.systemImage,
                    description: Text("Завершённые сессии появятся здесь")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.items) { item in
                            Button {
                                viewModel.edit(item)
                            } label: {
                                HistoryRow(
                                    duration: item.durationText,
                                    date: item.dateText,
                                    accessibilityLabel: item.accessibilityLabel
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(Text("Изменить продолжительность"))
                            .accessibilityIdentifier("history.row")
                        }
                    }
                }
            }
        }
        .sheet(item: $viewModel.editedSession) { session in
            EditSessionDurationView(viewModel: viewModel.makeEditViewModel(for: session))
        }
        .alert(
            "Не удалось загрузить историю",
            isPresented: Binding(
                get: { viewModel.loadError != nil },
                set: { isPresented in
                    if !isPresented { viewModel.reload() }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}

#Preview {
    HistoryView()
        .environment(TrackingStore.preview())
}

import SwiftUI

/// Поздравление с 10 000 часов. Макета в Figma нет, поэтому это минималистичный экран в стиле приложения:
/// заголовок, полностью заполненная сетка и две кнопки. «Закрыть» ничего не удаляет —
/// «Начать заново» остаётся доступным на главном экране.
struct GoalCelebrationView: View {
    @Environment(TrackingStore.self) private var store
    @State private var isResetConfirmationPresented = false

    var body: some View {
        let viewModel = HomeViewModel(store: store)

        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("10 000 часов!")
                    .appTextStyle(.largeTimer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(AppColor.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Твоя цель достигнута")
                    .appTextStyle(.body)
                    .foregroundStyle(AppColor.secondaryText)
            }
            .padding(.top, Layout.topPadding)

            completedGrid(viewModel.progress)

            VStack(spacing: AppSpacing.medium) {
                Button(role: .destructive) {
                    isResetConfirmationPresented = true
                } label: {
                    Text("Начать заново").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primaryText)
                .accessibilityIdentifier("celebration.restart")

                Button {
                    store.dismissCelebration()
                } label: {
                    Text("Закрыть").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.primaryText)
                .accessibilityIdentifier("celebration.close")
            }
            .controlSize(.large)
            .disabled(viewModel.isProcessing)
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
        .resetProgressConfirmation(isPresented: $isResetConfirmationPresented) {
            store.resetProgress()
        }
        .errorAlert(viewModel)
    }

    /// Та же сетка, что на главной; все 10 000 точек заполнены.
    private func completedGrid(_ progress: ProgressDisplay) -> some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                ProgressGridRows(
                    layout: ProgressGridLayout(availableWidth: proxy.size.width, style: .home),
                    filledDotCount: ProgressGoal.targetHours
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: progress.accessibilitySummary))
    }
}

private extension GoalCelebrationView {
    enum Layout {
        static let topPadding: CGFloat = 44
    }
}

extension View {
    /// Системное подтверждение сброса: «Отмена» ничего не меняет, «Начать заново» удаляет историю.
    func resetProgressConfirmation(isPresented: Binding<Bool>, onConfirm: @escaping () -> Void) -> some View {
        alert("Начать заново?", isPresented: isPresented) {
            Button("Отмена", role: .cancel) {}
            Button("Начать заново", role: .destructive, action: onConfirm)
        } message: {
            Text("Накопленные 10 000 часов и история сессий будут удалены. Это действие нельзя отменить.")
        }
    }

    /// Ошибка последней операции `TrackingStore` (Play/Stop, сброс). После закрытия операцию можно повторить.
    func errorAlert(_ viewModel: HomeViewModel) -> some View {
        alert(
            "Ошибка",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.dismissError() }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    GoalCelebrationView()
        .environment(TrackingStore.preview())
}

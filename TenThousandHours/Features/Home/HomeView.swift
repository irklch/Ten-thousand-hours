import SwiftUI

struct HomeView: View {
    @Environment(TrackingStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let viewModel = HomeViewModel(store: store)

        VStack(spacing: 0) {
            timerSection(viewModel)
            progressHeader(viewModel)
            ProgressGrid(filledDotCount: viewModel.filledDotCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
        .task(id: RefreshTrigger(isRunning: viewModel.isRunning, isActive: scenePhase == .active)) {
            guard viewModel.isRunning, scenePhase == .active else { return }
            await viewModel.keepTimerUpdated()
        }
        .alert(
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

    private func timerSection(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: Layout.timerSpacing) {
            Text(verbatim: viewModel.timerText)
                .appTextStyle(.largeTimer)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(AppColor.primaryText)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel(Text("Время сессии"))
                .accessibilityValue(Text(verbatim: viewModel.timerAccessibilityValue))
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("home.timer")

            PlayStopButton(isRunning: viewModel.isRunning) {
                viewModel.togglePlayStop()
            }
            .disabled(viewModel.isProcessing)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.timerTopPadding)
        .padding(.bottom, Layout.timerBottomPadding)
    }

    private func progressHeader(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(verbatim: viewModel.percentText)
                .appTextStyle(.progress)
                .foregroundStyle(AppColor.primaryText)
                .accessibilityIdentifier("home.percent")
            Text(verbatim: viewModel.hoursText)
                .appTextStyle(.body)
                .foregroundStyle(AppColor.secondaryText)
                .accessibilityIdentifier("home.hours")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Layout.headerBottomPadding)
    }
}

private extension HomeView {
    enum Layout {
        static let timerTopPadding: CGFloat = 44
        static let timerSpacing: CGFloat = 24
        static let timerBottomPadding: CGFloat = 48
        static let headerBottomPadding: CGFloat = 16
    }

    struct RefreshTrigger: Equatable {
        let isRunning: Bool
        let isActive: Bool
    }
}

#Preview {
    HomeView()
        .environment(TrackingStore.preview())
}

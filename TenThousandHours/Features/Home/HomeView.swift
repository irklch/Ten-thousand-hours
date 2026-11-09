import SwiftUI

struct HomeView: View {
    @Environment(TrackingStore.self) private var store

    var body: some View {
        VStack(spacing: AppSpacing.xLarge) {
            Spacer()

            Text(Duration.seconds(store.currentSessionElapsedSeconds), format: .time(pattern: .hourMinuteSecond))
                .appTextStyle(.largeTimer)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(AppColor.primaryText)

            PlayStopButton(isRunning: store.isRunning) {
                store.isRunning ? store.stop() : store.start()
            }
            .disabled(store.isProcessing)

            VStack(spacing: AppSpacing.xxSmall) {
                Text(verbatim: ProgressFormatter.percent(store.progress))
                    .appTextStyle(.progress)
                    .foregroundStyle(AppColor.primaryText)
                Text("\(store.completedHours) ч из \(ProgressGoal.targetHours)")
                    .appTextStyle(.caption)
                    .foregroundStyle(AppColor.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
        .task {
            await store.keepRefreshing()
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { store.error != nil },
                set: { isPresented in
                    if !isPresented { store.dismissError() }
                }
            ),
            presenting: store.error
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

#Preview {
    HomeView()
        .environment(TrackingStore.preview())
}

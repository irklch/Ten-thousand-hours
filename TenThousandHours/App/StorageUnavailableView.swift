import SwiftUI

/// Shown instead of the app when the store cannot be opened (App Group unavailable, SwiftData error).
/// It has no progress and no Play/Stop: without the store they would show a made-up state.
struct StorageUnavailableView: View {
    let error: (any Error)?
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Данные недоступны", systemImage: "exclamationmark.triangle")
        } description: {
            Text(verbatim: message)
        } actions: {
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primaryText)
                .accessibilityIdentifier("storage.retry")
        }
        .background(AppColor.background)
    }

    private var message: String {
        if let error = error as? SharedStoreError, let description = error.errorDescription {
            return description
        }
        return String(localized: "Не удалось открыть хранилище данных. Сохранённые сессии не удалены.")
    }
}

#Preview {
    StorageUnavailableView(error: SharedStoreError.appGroupUnavailable) {}
}

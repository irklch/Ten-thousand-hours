import SwiftUI

/// Показывается вместо приложения, когда хранилище не открывается (App Group недоступна, ошибка SwiftData).
/// Здесь нет прогресса и Play/Stop: без хранилища они показали бы выдуманное состояние.
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

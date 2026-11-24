import AppIntents
import Foundation

/// Play из виджета. `LiveActivityIntent`: система запускает его в процессе приложения (в фоне,
/// исходный файл входит в оба таргета), где ActivityKit может запустить Live Activity.
/// Повторный Play при идущем таймере не создаёт новую сессию (`TimerEngine.start`).
nonisolated struct StartTrackingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Начать отслеживание времени"
    static let description = IntentDescription("Запускает таймер 10 000 Hours")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try SharedTracking.engine().start()
        await SharedTracking.didChange()
        return .result()
    }
}

/// Stop из виджета, с экрана блокировки и из Dynamic Island. Сессии короче минуты отбрасываются по существующим правилам.
/// Stop без активной сессии ничего не меняет.
nonisolated struct StopTrackingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Остановить отслеживание времени"
    static let description = IntentDescription("Останавливает таймер 10 000 Hours")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try SharedTracking.engine().stop()
        await SharedTracking.didChange()
        return .result()
    }
}

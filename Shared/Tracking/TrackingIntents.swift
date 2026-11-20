import AppIntents
import Foundation

/// Play from the widget. Runs in the widget process without opening the app.
/// A repeated Play while the timer is running does not create a new session (`TimerEngine.start`).
nonisolated struct StartTrackingIntent: AppIntent {
    static let title: LocalizedStringResource = "Начать отслеживание времени"
    static let description = IntentDescription("Запускает таймер 10 000 Hours")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try SharedTracking.commands().start()
        WidgetTimelineReloader.reload()
        return .result()
    }
}

/// Stop from the widget. Sessions shorter than a minute are discarded by the existing rules.
/// Stop with no active session changes nothing.
nonisolated struct StopTrackingIntent: AppIntent {
    static let title: LocalizedStringResource = "Остановить отслеживание времени"
    static let description = IntentDescription("Останавливает таймер 10 000 Hours")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try SharedTracking.commands().stop()
        WidgetTimelineReloader.reload()
        return .result()
    }
}

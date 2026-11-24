import AppIntents
import Foundation

/// Play from the widget. `LiveActivityIntent`: the system runs it in the app's process (in the background,
/// the source file is in both targets), where ActivityKit may start a Live Activity.
/// A repeated Play while the timer is running does not create a new session (`TimerEngine.start`).
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

/// Stop from the widget, the Lock Screen and the Dynamic Island. Sessions shorter than a minute are discarded by the existing rules.
/// Stop with no active session changes nothing.
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

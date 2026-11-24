import Foundation

/// Небольшие флаги в общих `UserDefaults` App Group. Сессии, длительности и прогресс здесь не хранятся —
/// их единственный источник SwiftData.
nonisolated struct SharedPreferences: @unchecked Sendable {
    private enum Key {
        static let lastTrackingDate = "lastTrackingDate"
        static let isGoalCelebrationShown = "isGoalCelebrationShown"
    }

    let defaults: UserDefaults

    /// Общие для приложения и виджета значения.
    static var shared: SharedPreferences {
        SharedPreferences(defaults: UserDefaults(suiteName: ModelContainerFactory.appGroupIdentifier) ?? .standard)
    }

    /// Отдельный пустой набор значений: тесты, Preview и UI-тесты.
    static func ephemeral() -> SharedPreferences {
        let name = "TenThousandHours.ephemeral.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return SharedPreferences(defaults: defaults)
    }

    /// Момент последнего Play или Stop (в том числе отброшенной короткой сессии).
    var lastTrackingDate: Date? {
        defaults.object(forKey: Key.lastTrackingDate) as? Date
    }

    func recordTracking(at date: Date) {
        defaults.set(date, forKey: Key.lastTrackingDate)
    }

    /// Поздравление с 10 000 часов уже показано в текущем цикле.
    var isGoalCelebrationShown: Bool {
        get { defaults.bool(forKey: Key.isGoalCelebrationShown) }
        nonmutating set { defaults.set(newValue, forKey: Key.isGoalCelebrationShown) }
    }
}

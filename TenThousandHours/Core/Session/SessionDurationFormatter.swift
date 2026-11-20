import Foundation

nonisolated enum SessionDurationFormatter {
    static func format(_ seconds: Int) -> String {
        let (hours, minutes) = components(seconds)
        switch (hours, minutes) {
        case (0, _):
            return "\(minutes) мин"
        case (_, 0):
            return "\(hours) ч"
        default:
            return "\(hours) ч \(minutes) мин"
        }
    }

    static func spoken(_ seconds: Int, locale: Locale = Locale(identifier: "ru_RU")) -> String {
        let (hours, minutes) = components(seconds)
        return Duration.seconds(hours * 3_600 + minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .wide, zeroValueUnits: .hide).locale(locale)
        )
    }

    static func components(_ seconds: Int) -> (hours: Int, minutes: Int) {
        let total = max(0, seconds)
        return (total / 3_600, total % 3_600 / 60)
    }
}

nonisolated enum SessionDateFormatter {
    static func format(
        _ date: Date,
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "ru_RU")
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let style = Date.VerbatimFormatStyle(
            format: """
            \(day: .defaultDigits) \(month: .wide) \(year: .defaultDigits) · \
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)
            """,
            locale: locale,
            timeZone: timeZone,
            calendar: calendar
        )
        return date.formatted(style)
    }
}

import Foundation

nonisolated enum ElapsedTimeFormatter {
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let remainder = total % 60

        if hours > 0 {
            return String(format: "%02ld:%02ld:%02ld", hours, minutes, remainder)
        }
        return String(format: "%02ld:%02ld", minutes, remainder)
    }

    static func spoken(_ seconds: Int, locale: Locale = Locale(identifier: "ru_RU")) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale)
        )
    }
}

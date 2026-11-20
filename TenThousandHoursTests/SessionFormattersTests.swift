import XCTest
@testable import TenThousandHours

final class SessionFormattersTests: XCTestCase {
    func testDurationUnderOneHourShowsMinutesOnly() {
        XCTAssertEqual(SessionDurationFormatter.format(60), "1 мин")
        XCTAssertEqual(SessionDurationFormatter.format(90), "1 мин")
        XCTAssertEqual(SessionDurationFormatter.format(3_599), "59 мин")
    }

    func testDurationOverOneHour() {
        XCTAssertEqual(SessionDurationFormatter.format(3_600), "1 ч")
        XCTAssertEqual(SessionDurationFormatter.format(5_400), "1 ч 30 мин")
        XCTAssertEqual(SessionDurationFormatter.format(9_294), "2 ч 34 мин")
    }

    func testDurationOverTwentyFourHoursDoesNotWrap() {
        XCTAssertEqual(SessionDurationFormatter.format(86_400), "24 ч")
        XCTAssertEqual(SessionDurationFormatter.format(100 * 3_600 + 5 * 60 + 59), "100 ч 5 мин")
    }

    func testSpokenDurationIsRussianWithoutSeconds() {
        XCTAssertEqual(SessionDurationFormatter.spoken(9_294), "2 часа 34 минуты")
        XCTAssertEqual(SessionDurationFormatter.spoken(7_200), "2 часа")
        XCTAssertEqual(SessionDurationFormatter.spoken(90), "1 минута")
    }

    func testStartDateIsFormattedInRussianInGivenTimeZone() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Europe/Moscow")
        (components.year, components.month, components.day, components.hour, components.minute) = (2026, 11, 9, 10, 30)
        let date = try XCTUnwrap(components.date)

        XCTAssertEqual(
            SessionDateFormatter.format(date, timeZone: try XCTUnwrap(TimeZone(identifier: "Europe/Moscow"))),
            "9 ноября 2026 · 10:30"
        )
        XCTAssertEqual(
            SessionDateFormatter.format(date, timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))),
            "9 ноября 2026 · 16:30"
        )
    }
}

final class SessionDurationInputTests: XCTestCase {
    func testInitialValuesComeFromDurationWithoutSeconds() {
        let input = SessionDurationInput(durationSeconds: 9_240 + 59)
        XCTAssertEqual(input.hours, "2")
        XCTAssertEqual(input.minutes, "34")
        XCTAssertEqual(input.durationSeconds, 9_240)
    }

    func testValidValues() {
        XCTAssertEqual(SessionDurationInput(hours: "0", minutes: "1").durationSeconds, 60)
        XCTAssertEqual(SessionDurationInput(hours: "3", minutes: "15").durationSeconds, 11_700)
        XCTAssertEqual(SessionDurationInput(hours: "30", minutes: "0").durationSeconds, 108_000)
        XCTAssertEqual(SessionDurationInput(hours: " 2 ", minutes: "05").durationSeconds, 7_500)
    }

    func testZeroDurationIsRejected() {
        XCTAssertEqual(SessionDurationInput(hours: "0", minutes: "0").result, .failure(.tooShort))
    }

    func testNegativeAndNonNumericValuesAreRejected() {
        XCTAssertEqual(SessionDurationInput(hours: "-1", minutes: "30").result, .failure(.invalidHours))
        XCTAssertEqual(SessionDurationInput(hours: "1", minutes: "-5").result, .failure(.invalidMinutes))
        XCTAssertEqual(SessionDurationInput(hours: "", minutes: "5").result, .failure(.invalidHours))
        XCTAssertEqual(SessionDurationInput(hours: "1.5", minutes: "0").result, .failure(.invalidHours))
        XCTAssertEqual(SessionDurationInput(hours: "1", minutes: "").result, .failure(.invalidMinutes))
        XCTAssertEqual(SessionDurationInput(hours: "١", minutes: "0").result, .failure(.invalidHours))
    }

    func testMinutesAboveFiftyNineAreRejected() {
        XCTAssertEqual(SessionDurationInput(hours: "1", minutes: "60").result, .failure(.invalidMinutes))
        XCTAssertEqual(SessionDurationInput(hours: "1", minutes: "59").durationSeconds, 7_140)
    }

    func testOverflowIsRejected() {
        XCTAssertEqual(SessionDurationInput(hours: String(Int.max), minutes: "0").result, .failure(.tooLarge))
        XCTAssertEqual(SessionDurationInput(hours: String(Int.max / 3_600), minutes: "59").result, .failure(.tooLarge))
        XCTAssertEqual(SessionDurationInput(hours: "99999999999999999999999", minutes: "0").result, .failure(.tooLarge))
        XCTAssertEqual(
            SessionDurationInput(hours: String(Int.max / 3_600), minutes: "0").durationSeconds,
            Int.max / 3_600 * 3_600
        )
    }
}

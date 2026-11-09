import XCTest
@testable import TenThousandHours

final class ElapsedTimeFormatterTests: XCTestCase {
    func testZeroShowsMinutesAndSeconds() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(0), "00:00")
    }

    func testUnderOneHourShowsMinutesAndSeconds() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(154), "02:34")
        XCTAssertEqual(ElapsedTimeFormatter.clock(3_599), "59:59")
    }

    func testOverOneHourShowsHours() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(3_600), "01:00:00")
        XCTAssertEqual(ElapsedTimeFormatter.clock(3_754), "01:02:34")
    }

    func testOverTwentyFourHoursDoesNotWrap() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(86_400), "24:00:00")
        XCTAssertEqual(ElapsedTimeFormatter.clock(93_605), "26:00:05")
    }

    func testVeryLongDurationExpandsHours() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(1_234 * 3_600 + 61), "1234:01:01")
    }

    func testNegativeValueIsTreatedAsZero() {
        XCTAssertEqual(ElapsedTimeFormatter.clock(-5), "00:00")
    }

    func testSpokenValueIsRussian() {
        XCTAssertTrue(ElapsedTimeFormatter.spoken(154).contains("мин"))
    }
}

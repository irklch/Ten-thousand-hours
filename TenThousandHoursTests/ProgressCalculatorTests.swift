import XCTest
@testable import TenThousandHours

final class ProgressCalculatorTests: XCTestCase {
    private func progress(_ completed: Int, active: Int = 0) -> ProgressSnapshot {
        ProgressCalculator.progress(completedSessionsSeconds: completed, activeSessionSeconds: active)
    }

    func testGoalIsTenThousandHours() {
        XCTAssertEqual(ProgressGoal.targetSeconds, 36_000_000)
    }

    func testZeroSecondsGivesZeroDots() {
        let result = progress(0)
        XCTAssertEqual(result.completedHours, 0)
        XCTAssertEqual(result.filledDotCount, 0)
        XCTAssertEqual(result.progressPercent, 0)
        XCTAssertFalse(result.goalReached)
    }

    func testIncompleteHourGivesZeroDots() {
        XCTAssertEqual(progress(3_599).filledDotCount, 0)
        XCTAssertEqual(progress(3_599).completedHours, 0)
    }

    func testFullHourGivesOneDot() {
        XCTAssertEqual(progress(3_600).filledDotCount, 1)
    }

    func testTwoHoursGiveTwoDots() {
        XCTAssertEqual(progress(7_200).filledDotCount, 2)
    }

    func testIncompleteHoursAccumulateAcrossSessions() {
        let sessions = [1_800, 1_200, 600]
        let result = progress(sessions.reduce(0, +))

        XCTAssertEqual(result.totalSeconds, 3_600)
        XCTAssertEqual(result.completedHours, 1)
    }

    func testPercentIsTotalSecondsOverGoal() {
        let result = progress(1_245 * 3_600 + 1_800)
        XCTAssertEqual(result.progressPercent, Double(1_245 * 3_600 + 1_800) / 36_000_000 * 100, accuracy: 1e-12)
    }

    func testTenThousandHoursIsHundredPercent() {
        let result = progress(36_000_000)

        XCTAssertEqual(result.progressPercent, 100)
        XCTAssertEqual(result.filledDotCount, 10_000)
        XCTAssertTrue(result.goalReached)
    }

    func testOneSecondBeforeGoalIsNotReached() {
        let result = progress(35_999_999)

        XCTAssertFalse(result.goalReached)
        XCTAssertEqual(result.filledDotCount, 9_999)
        XCTAssertLessThan(result.progressPercent, 100)
    }

    func testMoreThanGoalIsVisuallyCappedButTotalIsKept() {
        let result = progress(40_000_000)

        XCTAssertEqual(result.totalSeconds, 40_000_000)
        XCTAssertEqual(result.completedHours, 11_111)
        XCTAssertEqual(result.progressPercent, 100)
        XCTAssertEqual(result.filledDotCount, 10_000)
        XCTAssertTrue(result.goalReached)
    }

    func testActiveSessionIsIncluded() {
        let result = progress(3_000, active: 600)

        XCTAssertEqual(result.totalSeconds, 3_600)
        XCTAssertEqual(result.filledDotCount, 1)
    }

    func testGoalCanBeReachedDuringActiveSession() {
        XCTAssertTrue(progress(35_999_000, active: 1_000).goalReached)
    }

    func testPercentFormattingUsesTwoDecimalsWithoutRoundingUp() {
        XCTAssertEqual(ProgressFormatter.percent(progress(0)), "0,00%")
        XCTAssertEqual(ProgressFormatter.percent(progress(1_245 * 3_600)), "12,45%")
        XCTAssertEqual(ProgressFormatter.percent(progress(35_999_999)), "99,99%")
        XCTAssertEqual(ProgressFormatter.percent(progress(40_000_000)), "100,00%")
    }

    func testHoursFormattingUsesThousandsSeparatorAndWholeHours() {
        XCTAssertEqual(ProgressFormatter.hours(progress(0)), "0 / 10\u{00A0}000 ч")
        XCTAssertEqual(ProgressFormatter.hours(progress(3_599)), "0 / 10\u{00A0}000 ч")
        XCTAssertEqual(ProgressFormatter.hours(progress(1_245 * 3_600 + 3_599)), "1\u{00A0}245 / 10\u{00A0}000 ч")
        XCTAssertEqual(ProgressFormatter.hours(progress(40_000_000)), "11\u{00A0}111 / 10\u{00A0}000 ч")
    }
}

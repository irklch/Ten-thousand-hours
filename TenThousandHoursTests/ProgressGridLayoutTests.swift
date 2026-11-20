import XCTest
@testable import TenThousandHours

final class ProgressGridLayoutTests: XCTestCase {
    private let homeLayout = ProgressGridLayout(availableWidth: 346, style: .home)

    private func allDotCounts(_ layout: ProgressGridLayout) -> [Int] {
        (0..<layout.rows).map { layout.dotCount(inRow: $0) }
    }

    private func filledTotal(_ layout: ProgressGridLayout, filled: Int) -> Int {
        (0..<layout.rows).reduce(0) { $0 + layout.filledDotCount(inRow: $1, totalFilled: filled) }
    }

    func testExactlyTenThousandLogicalDots() {
        for width in [280.0, 319, 339, 346, 348, 374] as [CGFloat] {
            for style in [ProgressGridStyle.home, .fullscreen] {
                let layout = ProgressGridLayout(availableWidth: width, style: style)
                XCTAssertEqual(allDotCounts(layout).reduce(0, +), 10_000, "width \(width)")
                XCTAssertEqual(layout.dotCount(inRow: layout.rows), 0)
                XCTAssertEqual(layout.dotCount(inRow: -1), 0)
            }
        }
    }

    func testColumnsMatchFigmaAndAdaptToWidth() {
        XCTAssertEqual(ProgressGridLayout(availableWidth: 339, style: .home).columns, 38)
        XCTAssertEqual(homeLayout.columns, 38)
        XCTAssertEqual(ProgressGridLayout(availableWidth: 319, style: .home).columns, 35)
        XCTAssertEqual(ProgressGridLayout(availableWidth: 374, style: .home).columns, 41)
        XCTAssertEqual(ProgressGridLayout(availableWidth: 348, style: .fullscreen).columns, 32)
        XCTAssertEqual(ProgressGridLayout(availableWidth: 0, style: .home).columns, 1)
    }

    func testContentNeverOverflowsHorizontally() {
        for width in stride(from: CGFloat(10), through: 500, by: 7) {
            for style in [ProgressGridStyle.home, .fullscreen] {
                let layout = ProgressGridLayout(availableWidth: width, style: style)
                if width >= style.dotDiameter {
                    XCTAssertLessThanOrEqual(layout.contentWidth, width, "width \(width)")
                }
            }
        }
        XCTAssertEqual(ProgressGridLayout(availableWidth: 339, style: .home).contentWidth, 339)
        XCTAssertEqual(ProgressGridLayout(availableWidth: 348, style: .fullscreen).contentWidth, 348)
    }

    func testRowsAreCeilingOfTotalOverColumnsWithPartialLastRow() {
        XCTAssertEqual(homeLayout.rows, 264)
        XCTAssertEqual(homeLayout.dotCount(inRow: 0), 38)
        XCTAssertEqual(homeLayout.dotCount(inRow: 262), 38)
        XCTAssertEqual(homeLayout.dotCount(inRow: 263), 10_000 - 263 * 38)

        let fullscreen = ProgressGridLayout(availableWidth: 348, style: .fullscreen)
        XCTAssertEqual(fullscreen.rows, 313)
        XCTAssertEqual(fullscreen.dotCount(inRow: 312), 16)

        let exact = ProgressGridLayout(availableWidth: 4 * 6 + 3 * 3, style: .home)
        XCTAssertEqual(exact.columns, 4)
        XCTAssertEqual(exact.rows, 2_500)
        XCTAssertEqual(exact.dotCount(inRow: 2_499), 4)
    }

    func testZeroProgressFillsNothing() {
        XCTAssertEqual(filledTotal(homeLayout, filled: 0), 0)
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 0, totalFilled: 0), 0)
    }

    func testOneFilledDotIsFirstDot() {
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 0, totalFilled: 1), 1)
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 1, totalFilled: 1), 0)
        XCTAssertEqual(filledTotal(homeLayout, filled: 1), 1)
    }

    func testPartialProgressFillsSequentiallyLeftToRightTopToBottom() {
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 63, totalFilled: 2_450), 38)
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 64, totalFilled: 2_450), 2_450 - 64 * 38)
        XCTAssertEqual(homeLayout.filledDotCount(inRow: 65, totalFilled: 2_450), 0)
        XCTAssertEqual(filledTotal(homeLayout, filled: 2_450), 2_450)
    }

    func testNineThousandNineHundredNinetyNineLeavesLastDotEmpty() {
        let lastRow = homeLayout.rows - 1
        XCTAssertEqual(homeLayout.filledDotCount(inRow: lastRow, totalFilled: 9_999), homeLayout.dotCount(inRow: lastRow) - 1)
        XCTAssertEqual(filledTotal(homeLayout, filled: 9_999), 9_999)
    }

    func testTenThousandFillsEverything() {
        XCTAssertEqual(filledTotal(homeLayout, filled: 10_000), 10_000)
        XCTAssertEqual(homeLayout.filledDotCount(inRow: homeLayout.rows - 1, totalFilled: 10_000), homeLayout.dotCount(inRow: homeLayout.rows - 1))
    }

    func testProgressAboveGoalIsCapped() {
        XCTAssertEqual(filledTotal(homeLayout, filled: 12_345), 10_000)
        XCTAssertEqual(filledTotal(homeLayout, filled: -5), 0)
    }

    func testSameFilledCountOnHomeAndFullscreen() {
        let fullscreen = ProgressGridLayout(availableWidth: 348, style: .fullscreen)
        for filled in [0, 1, 1_245, 9_999, 10_000, 11_000] {
            XCTAssertEqual(filledTotal(homeLayout, filled: filled), filledTotal(fullscreen, filled: filled))
        }
    }
}

final class ProgressGridPositioningTests: XCTestCase {
    private let layout = ProgressGridLayout(availableWidth: 339, style: .home)

    func testBoundaryRowIsRowOfFirstUnfilledDot() {
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 0, layout: layout), 0)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 37, layout: layout), 0)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 38, layout: layout), 1)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 2_450, layout: layout), 64)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 9_999, layout: layout), 263)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 10_000, layout: layout), 263)
        XCTAssertEqual(ProgressGridPositioning.boundaryRow(filledDotCount: 50_000, layout: layout), 263)
    }

    private let viewport: CGFloat = 339

    private func target(_ filled: Int, above: CGFloat = 0) -> ProgressGridScrollTarget {
        ProgressGridPositioning.initialTarget(
            filledDotCount: filled,
            layout: layout,
            viewportHeight: viewport,
            contentAboveGrid: above
        )
    }

    func testZeroProgressShowsBeginning() {
        XCTAssertEqual(target(0), ProgressGridScrollTarget(row: 0, anchor: .top))
        XCTAssertTrue(target(0).isContentStart)
        XCTAssertFalse(target(2_450).isContentStart)
    }

    func testBoundaryVisibleFromStartKeepsBeginning() {
        XCTAssertEqual(layout.bottom(ofRow: 37), 339)
        XCTAssertEqual(target(1), ProgressGridScrollTarget(row: 0, anchor: .top))
        XCTAssertEqual(target(1_245), ProgressGridScrollTarget(row: 0, anchor: .top))
        XCTAssertEqual(target(38 * 38 - 1), ProgressGridScrollTarget(row: 0, anchor: .top))
        XCTAssertEqual(target(38 * 38), ProgressGridScrollTarget(row: 38, anchor: .center))
    }

    func testContentAboveGridIsTakenIntoAccount() {
        XCTAssertEqual(target(1_245, above: 96), ProgressGridScrollTarget(row: 32, anchor: .center))
    }

    func testHalfProgressCentersBoundary() {
        XCTAssertEqual(target(5_000), ProgressGridScrollTarget(row: 5_000 / 38, anchor: .center))
        XCTAssertEqual(target(2_450), ProgressGridScrollTarget(row: 64, anchor: .center))
    }

    func testAlmostFullProgressCentersBoundaryNearEnd() {
        XCTAssertEqual(target(9_999), ProgressGridScrollTarget(row: 263, anchor: .center))
    }

    func testFullProgressShowsEnd() {
        let end = ProgressGridScrollTarget(row: layout.rows - 1, anchor: .bottom)
        XCTAssertEqual(target(10_000), end)
        XCTAssertEqual(target(10_500), end)
    }

    func testPositionsOnlyOnceSoManualScrollIsKeptWhenProgressChanges() {
        var state = ProgressGridScrollState()

        XCTAssertNil(state.targetIfNeeded(filledDotCount: 2_450, layout: layout, viewportHeight: 0))
        XCTAssertFalse(state.hasPositioned)

        XCTAssertEqual(
            state.targetIfNeeded(filledDotCount: 2_450, layout: layout, viewportHeight: viewport),
            ProgressGridScrollTarget(row: 64, anchor: .center)
        )
        XCTAssertTrue(state.hasPositioned)
        XCTAssertNil(state.targetIfNeeded(filledDotCount: 2_451, layout: layout, viewportHeight: viewport))
        XCTAssertNil(state.targetIfNeeded(filledDotCount: 5_000, layout: layout, viewportHeight: viewport))
    }

    func testAccessibilitySummaryIsSingleSentence() {
        let progress = ProgressCalculator.progress(completedSessionsSeconds: 1_245 * 3_600, activeSessionSeconds: 0)
        XCTAssertEqual(
            ProgressFormatter.accessibilitySummary(progress),
            "Прогресс: 12,45%. Завершено часов: 1\u{00A0}245 из 10\u{00A0}000"
        )
    }
}

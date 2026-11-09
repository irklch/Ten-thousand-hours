import XCTest
@testable import TenThousandHours

final class AppTabTests: XCTestCase {
    @MainActor
    func testTabsAreOrderedHomeThenHistory() {
        XCTAssertEqual(AppTab.allCases, [.home, .history])
    }

    @MainActor
    func testTabsUseExistingSystemSymbols() {
        for tab in AppTab.allCases {
            XCTAssertNotNil(UIImage(systemName: tab.systemImage), "Нет SF Symbol \(tab.systemImage)")
        }
    }
}

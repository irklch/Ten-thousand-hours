import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwitchingBetweenTabs() {
        let app = XCUIApplication()
        app.launch()

        let homeTab = app.tabBars.buttons["Главная"]
        let historyTab = app.tabBars.buttons["История"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        XCTAssertTrue(homeTab.isSelected)

        historyTab.tap()
        XCTAssertTrue(historyTab.isSelected)
        XCTAssertTrue(app.navigationBars["История"].waitForExistence(timeout: 5))

        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected)
    }
}

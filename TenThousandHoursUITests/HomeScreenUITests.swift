import XCTest

final class HomeScreenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (reset ? ["-ui-testing-reset"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func waitForValue(of element: XCUIElement, toDifferFrom value: String?, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { object, _ in
            ((object as? XCUIElement)?.value as? String) != value
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func testPlayAndStopShortSession() {
        let app = launchApp(reset: true)
        let timer = app.staticTexts["home.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        let idleValue = timer.value as? String
        XCTAssertEqual(app.staticTexts["home.percent"].label, "0,00%")

        app.buttons["Начать"].tap()
        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(of: timer, toDifferFrom: idleValue), "Таймер не начал отсчёт")

        app.buttons["Остановить"].tap()
        XCTAssertTrue(app.buttons["Начать"].waitForExistence(timeout: 5))
        XCTAssertEqual(timer.value as? String, idleValue)
        XCTAssertEqual(app.staticTexts["home.percent"].label, "0,00%")
    }

    @MainActor
    func testSwitchingTabsKeepsTimerRunning() {
        let app = launchApp(reset: true)
        let timer = app.staticTexts["home.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        let idleValue = timer.value as? String

        app.buttons["Начать"].tap()
        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))

        app.tabBars.buttons["История"].tap()
        XCTAssertTrue(app.navigationBars["История"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Главная"].tap()

        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(of: timer, toDifferFrom: idleValue), "Таймер сброшен после смены вкладки")
    }

    @MainActor
    func testActiveSessionIsRestoredAfterRelaunch() {
        let app = launchApp(reset: true)
        XCTAssertTrue(app.buttons["Начать"].waitForExistence(timeout: 10))
        app.buttons["Начать"].tap()
        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))
        let idleValue = app.staticTexts["home.timer"].value as? String
        app.terminate()

        let relaunched = launchApp(reset: false)
        XCTAssertTrue(relaunched.buttons["Остановить"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(of: relaunched.staticTexts["home.timer"], toDifferFrom: idleValue))
    }
}

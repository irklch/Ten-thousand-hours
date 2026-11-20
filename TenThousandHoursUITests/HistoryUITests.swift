import XCTest

final class HistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(seedHours: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset"]
        if let seedHours {
            app.launchArguments += ["-ui-testing-seed-hours", String(seedHours)]
        }
        app.launch()
        return app
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["История"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    @MainActor
    private func firstRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "history.row").firstMatch
    }

    @MainActor
    private func openEditor(_ app: XCUIApplication) {
        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 10), .completed)
        row.tap()
        XCTAssertTrue(app.navigationBars["Длительность"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.doubleTap()
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    @MainActor
    func testEmptyHistoryShowsPlaceholder() {
        let app = launchApp()
        openHistory(app)

        XCTAssertTrue(app.staticTexts["Сессий пока нет"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Завершённые сессии появятся здесь"].exists)
        XCTAssertFalse(firstRow(app).exists)
    }

    @MainActor
    func testEditingDurationUpdatesHistoryAndHomeProgress() {
        let app = launchApp(seedHours: 2)
        openHistory(app)
        let row = firstRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.hasPrefix("2 часа"), row.label)

        openEditor(app)
        replaceText(in: app.textFields["edit.hours"], with: "3")
        replaceText(in: app.textFields["edit.minutes"], with: "15")
        app.buttons["Сохранить"].tap()

        XCTAssertTrue(app.navigationBars["Длительность"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(firstRow(app).label.hasPrefix("3 часа 15 минут"), firstRow(app).label)

        app.tabBars.buttons["Главная"].tap()
        XCTAssertTrue(app.staticTexts["home.percent"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.percent"].label, "0,03%")
        XCTAssertTrue(app.staticTexts["home.hours"].label.hasPrefix("3 /"), app.staticTexts["home.hours"].label)
    }

    @MainActor
    func testCancelKeepsOriginalDuration() {
        let app = launchApp(seedHours: 2)
        openHistory(app)
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 5))

        openEditor(app)
        replaceText(in: app.textFields["edit.hours"], with: "9")
        app.buttons["Отмена"].tap()

        XCTAssertTrue(app.navigationBars["Длительность"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(firstRow(app).label.hasPrefix("2 часа"), firstRow(app).label)
    }

    @MainActor
    func testZeroDurationCannotBeSaved() {
        let app = launchApp(seedHours: 2)
        openHistory(app)
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 5))

        openEditor(app)
        replaceText(in: app.textFields["edit.hours"], with: "0")
        replaceText(in: app.textFields["edit.minutes"], with: "0")

        XCTAssertEqual(app.textFields["edit.hours"].value as? String, "0")
        XCTAssertEqual(app.textFields["edit.minutes"].value as? String, "0")
        XCTAssertFalse(app.buttons["Сохранить"].isEnabled)
        XCTAssertTrue(app.staticTexts["edit.validation"].exists)
    }
}

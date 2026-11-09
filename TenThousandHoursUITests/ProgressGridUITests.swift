import XCTest

final class ProgressGridUITests: XCTestCase {
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
    private func grid(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["home.progressGrid"]
    }

    @MainActor
    private func closeButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Закрыть"]
    }

    @MainActor
    func testTapOnGridOpensFullscreenWithoutTabBarAndCloseReturns() {
        let app = launchApp()
        XCTAssertTrue(grid(in: app).waitForExistence(timeout: 10))

        grid(in: app).tap()

        XCTAssertTrue(closeButton(in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Главная"].isHittable)

        closeButton(in: app).tap()

        XCTAssertTrue(grid(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Главная"].isHittable)
        XCTAssertFalse(closeButton(in: app).exists)
    }

    @MainActor
    func testDragScrollsGridAndDoesNotOpenFullscreen() {
        let app = launchApp(seedHours: 2_450)
        let grid = grid(in: app)
        XCTAssertTrue(grid.waitForExistence(timeout: 10))
        let before = grid.screenshot().pngRepresentation

        grid.swipeUp()

        XCTAssertFalse(closeButton(in: app).waitForExistence(timeout: 2))
        XCTAssertNotEqual(grid.screenshot().pngRepresentation, before, "Сетка не прокрутилась")
        XCTAssertTrue(app.staticTexts["home.timer"].exists)
    }

    @MainActor
    func testProgressLineScrollsTogetherWithGrid() {
        let app = launchApp()
        XCTAssertTrue(grid(in: app).waitForExistence(timeout: 10))
        grid(in: app).tap()

        let progressLine = app.descendants(matching: .any)["fullscreen.progressLine"]
        XCTAssertTrue(progressLine.waitForExistence(timeout: 5))
        let initialY = progressLine.frame.minY

        app.swipeUp()

        let lineMoved = !progressLine.exists || progressLine.frame.minY < initialY - 50
        XCTAssertTrue(lineMoved, "Строка прогресса закреплена, а должна прокручиваться")
        XCTAssertTrue(closeButton(in: app).isHittable)
    }

    @MainActor
    func testTimerKeepsRunningWhileFullscreenIsOpen() {
        let app = launchApp()
        let timer = app.staticTexts["home.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        app.buttons["Начать"].tap()
        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))
        let valueBeforeOpening = timer.value as? String

        grid(in: app).tap()
        XCTAssertTrue(closeButton(in: app).waitForExistence(timeout: 5))
        sleep(3)
        closeButton(in: app).tap()

        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(timer.value as? String, valueBeforeOpening)
    }
}

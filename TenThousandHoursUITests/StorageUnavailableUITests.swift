import XCTest

/// The store is unavailable at launch: an error screen with no progress and no Play/Stop; Retry opens the app.
final class StorageUnavailableUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testErrorScreenAndRetryAfterTemporaryUnavailability() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-storage-failures", "1"]
        app.launch()

        let retry = app.buttons["storage.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Данные недоступны"].exists)
        XCTAssertFalse(app.buttons["Начать"].exists, "Без хранилища Play недоступен")
        XCTAssertFalse(app.staticTexts["home.percent"].exists, "Без хранилища прогресс не показывается")

        retry.tap()

        XCTAssertTrue(app.buttons["Начать"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.percent"].label, "0,00%")
    }
}

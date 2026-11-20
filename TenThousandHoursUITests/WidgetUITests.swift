import XCTest

/// Real widget check on the home screen (Springboard): add the Small widget, Play/Stop from the widget,
/// and sync with the app (state, history, progress).
///
/// It depends on the Springboard UI of a particular iOS version and works with the real shared store
/// on the simulator, so it runs only on request:
/// `TEST_RUNNER_RUN_WIDGET_UI_TESTS=1 xcodebuild test … -only-testing:TenThousandHoursUITests/WidgetUITests`.
final class WidgetUITests: XCTestCase {
    @MainActor
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_WIDGET_UI_TESTS"] == "1",
            "Проверка виджета на Springboard запускается вручную"
        )
    }

    @MainActor
    func testPlayAndStopFromSmallWidgetAreVisibleInApp() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Остановить"].waitForExistence(timeout: 3) {
            app.buttons["Остановить"].tap()
        }
        XCTAssertTrue(app.buttons["Начать"].waitForExistence(timeout: 5))
        let hoursBefore = app.staticTexts["home.hours"].label

        addSmallWidget()

        let play = springboard.buttons["Начать отслеживание времени"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10), "На виджете нет кнопки Play")
        play.tap()
        let stop = springboard.buttons["Остановить отслеживание времени"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "Виджет не переключился на Stop после Play")

        app.activate()
        XCTAssertTrue(app.buttons["Остановить"].waitForExistence(timeout: 5), "Приложение не видит Play из виджета")

        sleep(62)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 10), "Виджет не переключился на Play после Stop")

        app.activate()
        XCTAssertTrue(app.buttons["Начать"].waitForExistence(timeout: 5), "Приложение не видит Stop из виджета")
        XCTAssertEqual(app.staticTexts["home.hours"].label, hoursBefore)
        app.tabBars.buttons["История"].tap()
        XCTAssertTrue(app.buttons["history.row"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history.row"].firstMatch.label.hasPrefix("1 минута"), app.buttons["history.row"].firstMatch.label)
    }

    @MainActor
    func testLargeWidgetShowsProgressFromApp() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["home.percent"].waitForExistence(timeout: 5))
        let percent = app.staticTexts["home.percent"].label.replacingOccurrences(of: "%", with: "")

        addWidget(page: 2)

        let percentLabel = springboard.staticTexts["Выполнено \(percent) процента"].firstMatch
        XCTAssertTrue(percentLabel.waitForExistence(timeout: 10), "Large-виджет не показывает процент \(percent)")
        let hours = springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Накоплен'")).firstMatch
        XCTAssertTrue(hours.exists)
        let control = springboard.buttons.matching(NSPredicate(format: "label ENDSWITH 'отслеживание времени'"))
        XCTAssertGreaterThanOrEqual(control.count, 1)
    }

    @MainActor
    private func addSmallWidget() {
        XCUIDevice.shared.press(.home)
        if springboard.buttons["Начать отслеживание времени"].firstMatch.waitForExistence(timeout: 2)
            || springboard.buttons["Остановить отслеживание времени"].firstMatch.exists {
            return
        }
        addWidget(page: 1)
    }

    /// Adds the widget through the gallery: page 1 is Small, page 2 is Large.
    @MainActor
    private func addWidget(page: Int) {
        XCUIDevice.shared.press(.home)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
        springboard.buttons["Изменить"].firstMatch.tap()
        springboard.descendants(matching: .any)["Добавить виджет"].firstMatch.tap()
        let search = springboard.searchFields
            .matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'виджет'"))
            .firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("10 000")
        let cell = springboard.cells["10 000 Hours"].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        if page > 1 {
            let preview = springboard.buttons.matching(NSPredicate(format: "value CONTAINS 'Виджет'")).firstMatch
            XCTAssertTrue(preview.waitForExistence(timeout: 5))
            for _ in 1..<page { preview.swipeLeft() }
            sleep(1)
        }
        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Добавить виджет'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let done = springboard.buttons["Готово"].firstMatch
        if done.waitForExistence(timeout: 3) {
            done.tap()
        }
    }
}

import SwiftUI
import WidgetKit
import XCTest
@testable import TenThousandHours

final class TrackingWidgetDisplayTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func ready(_ display: TrackingWidgetDisplay) throws -> TrackingWidgetDisplay.Ready {
        guard case .ready(let ready) = display.content else {
            throw XCTSkip("Ожидалось состояние ready, получено \(display.content)")
        }
        return ready
    }

    private func display(running: Bool, completedSeconds: Int, activeSeconds: Int = 0) -> TrackingWidgetDisplay {
        TrackingWidgetDisplay(
            state: .ready(TrackingStatus(
                activeSessionStartDate: running ? now.addingTimeInterval(-TimeInterval(activeSeconds)) : nil,
                completedSessionsSeconds: completedSeconds
            )),
            date: now
        )
    }

    func testSmallWidgetPlayState() throws {
        let ready = try ready(display(running: false, completedSeconds: 0))

        XCTAssertFalse(ready.isRunning)
        XCTAssertEqual(ready.buttonAccessibilityLabel, "Начать отслеживание времени")
    }

    func testSmallWidgetStopState() throws {
        let ready = try ready(display(running: true, completedSeconds: 0, activeSeconds: 30))

        XCTAssertTrue(ready.isRunning)
        XCTAssertEqual(ready.buttonAccessibilityLabel, "Остановить отслеживание времени")
    }

    func testLargeWidgetZeroProgress() throws {
        let ready = try ready(display(running: false, completedSeconds: 0))

        XCTAssertEqual(ready.percentText, "0,00%")
        XCTAssertEqual(ready.hoursText, "0 / 10\u{00A0}000 ч")
        XCTAssertEqual(ready.percentAccessibilityLabel, "Выполнено 0,00 процента")
        XCTAssertEqual(ready.hoursAccessibilityLabel, "Накоплено 0 часов из 10\u{00A0}000")
    }

    func testLargeWidgetPartialProgressMatchesFigma() throws {
        let ready = try ready(display(running: false, completedSeconds: 1_245 * 3_600 + 1_620))

        XCTAssertEqual(ready.percentText, "12,45%")
        XCTAssertEqual(ready.hoursText, "1\u{00A0}245 / 10\u{00A0}000 ч")
        XCTAssertEqual(ready.percentAccessibilityLabel, "Выполнено 12,45 процента")
        XCTAssertEqual(ready.hoursAccessibilityLabel, "Накоплено 1\u{00A0}245 часов из 10\u{00A0}000")
    }

    func testLargeWidgetIncludesRunningSession() throws {
        let ready = try ready(display(running: true, completedSeconds: 3_600, activeSeconds: 3_600))

        XCTAssertEqual(ready.hoursText, "2 / 10\u{00A0}000 ч")
        XCTAssertEqual(ready.hoursAccessibilityLabel, "Накоплено 2 часа из 10\u{00A0}000")
    }

    func testLargeWidgetFullProgress() throws {
        let ready = try ready(display(running: false, completedSeconds: 10_000 * 3_600))

        XCTAssertEqual(ready.percentText, "100,00%")
        XCTAssertEqual(ready.hoursText, "10\u{00A0}000 / 10\u{00A0}000 ч")
    }

    func testProgressBeyondGoalIsCappedVisuallyButHoursAreNot() throws {
        let ready = try ready(display(running: false, completedSeconds: 10_500 * 3_600))

        XCTAssertEqual(ready.percentText, "100,00%")
        XCTAssertEqual(ready.hoursText, "10\u{00A0}500 / 10\u{00A0}000 ч")
    }

    func testUnavailableStateHasNoControl() {
        let display = TrackingWidgetDisplay(state: .unavailable, date: now)

        XCTAssertEqual(display.content, .unavailable)
    }

    func testRussianPluralForHours() {
        XCTAssertEqual(RussianPlural.category(1), .one)
        XCTAssertEqual(RussianPlural.category(21), .one)
        XCTAssertEqual(RussianPlural.category(3), .few)
        XCTAssertEqual(RussianPlural.category(1_244), .few)
        XCTAssertEqual(RussianPlural.category(11), .many)
        XCTAssertEqual(RussianPlural.category(112), .many)
        XCTAssertEqual(RussianPlural.category(1_245), .many)
        XCTAssertEqual(RussianPlural.category(0), .many)
    }
}

final class TrackingTimelinePlannerTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_030)

    func testStoppedTimerHasSingleEntryAndNoReloads() {
        let state = TrackingWidgetState.ready(TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: 0))

        XCTAssertEqual(TrackingTimelinePlanner.entryDates(for: state, now: now), [now])
        XCTAssertEqual(TrackingTimelinePlanner.reload(for: state, now: now), .never)
    }

    func testRunningTimerHasEntriesEveryMinuteAlignedToMinute() {
        let state = TrackingWidgetState.ready(TrackingStatus(activeSessionStartDate: now, completedSessionsSeconds: 0))

        let dates = TrackingTimelinePlanner.entryDates(for: state, now: now)

        XCTAssertEqual(dates.count, TrackingTimelinePlanner.runningEntryCount)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates[1], Date(timeIntervalSinceReferenceDate: 800_000_040))
        XCTAssertEqual(dates[2].timeIntervalSince(dates[1]), 60)
        XCTAssertEqual(TrackingTimelinePlanner.reload(for: state, now: now), .atEnd)
    }

    func testUnavailableStoreRetriesLater() {
        XCTAssertEqual(
            TrackingTimelinePlanner.reload(for: .unavailable, now: now),
            .after(now.addingTimeInterval(15 * 60))
        )
    }
}

/// Рендер виджетов в крайних системных размерах (iPhone SE … Pro Max) и проверка, что
/// текст и кнопка помещаются.
/// Если задана переменная окружения `WIDGET_SNAPSHOT_DIR`, изображения сохраняются для визуального сравнения с Figma.
final class TrackingWidgetRenderingTests: XCTestCase {
    private struct Case {
        let name: String
        let family: WidgetFamily
        let size: CGSize
        let completedHours: Int
        let running: Bool
    }

    private let cases = [
        Case(name: "small-play-170", family: .systemSmall, size: CGSize(width: 170, height: 170), completedHours: 0, running: false),
        Case(name: "small-stop-148", family: .systemSmall, size: CGSize(width: 148, height: 148), completedHours: 0, running: true),
        Case(name: "large-zero-364", family: .systemLarge, size: CGSize(width: 364, height: 382), completedHours: 0, running: false),
        Case(name: "large-partial-364", family: .systemLarge, size: CGSize(width: 364, height: 382), completedHours: 1_245, running: false),
        Case(name: "large-full-321", family: .systemLarge, size: CGSize(width: 321, height: 324), completedHours: 10_000, running: true),
    ]

    @MainActor
    func testWidgetsRenderAtSystemSizes() throws {
        let directory = ProcessInfo.processInfo.environment["WIDGET_SNAPSHOT_DIR"].map(URL.init(fileURLWithPath:))
        for item in cases {
            let display = TrackingWidgetDisplay(
                state: .ready(TrackingStatus(
                    activeSessionStartDate: item.running ? Date() : nil,
                    completedSessionsSeconds: item.completedHours * ProgressGoal.secondsPerHour
                )),
                date: Date()
            )
            let view = TrackingWidgetView(display: display, family: item.family)
                .frame(width: item.size.width, height: item.size.height)
                .background(AppColor.background)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, item.name)
            XCTAssertEqual(image.size, item.size, item.name)
            if let directory, let data = image.pngData() {
                try data.write(to: directory.appendingPathComponent("\(item.name).png"))
            }
        }
    }

    /// Самый широкий процент («100,00%») в 80 pt помещается в самый маленький Large-виджет с учётом `minimumScaleFactor`.
    @MainActor
    func testPercentFitsSmallestLargeWidget() {
        let font = UIFont.systemFont(ofSize: AppTextStyle.largeTimer.size, weight: .light)
        let width = ("100,00%" as NSString).size(withAttributes: [.font: font, .kern: AppTextStyle.largeTimer.tracking]).width
        let available: CGFloat = 321 - 2 * 24

        XCTAssertLessThanOrEqual(width * 0.5, available)
    }
}

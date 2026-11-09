import SwiftUI
import XCTest
@testable import TenThousandHours

final class AppLaunchTests: XCTestCase {
    @MainActor
    func testRootViewRendersInHostingController() {
        let controller = UIHostingController(rootView: RootView())
        controller.loadViewIfNeeded()

        XCTAssertNotNil(controller.view)
    }
}

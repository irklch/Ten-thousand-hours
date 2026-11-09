import SwiftData
import XCTest
@testable import TenThousandHours

final class ModelContainerFactoryTests: XCTestCase {
    @MainActor
    func testMakesInMemoryContainer() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)

        let configuration = try XCTUnwrap(container.configurations.first)
        XCTAssertTrue(configuration.isStoredInMemoryOnly)
        XCTAssertEqual(container.schema.entities.count, ModelContainerFactory.models.count)
    }

    @MainActor
    func testInMemoryContainerProvidesWorkingContext() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        XCTAssertFalse(context.hasChanges)
        XCTAssertNoThrow(try context.save())
    }
}

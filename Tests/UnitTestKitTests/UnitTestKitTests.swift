import XCTest
@testable import UnitTestKit

final class UnitTestKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(UnitTestKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

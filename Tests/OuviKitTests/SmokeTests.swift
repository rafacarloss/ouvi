import XCTest
@testable import OuviKit

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertFalse(OuviInfo.version.isEmpty)
    }
}

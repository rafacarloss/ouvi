import Testing
@testable import OuviKit

@Suite struct SmokeTests {
    @Test func version() {
        #expect(!OuviInfo.version.isEmpty)
    }
}

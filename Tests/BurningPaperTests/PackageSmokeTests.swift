import XCTest
@testable import BurningPaper

final class PackageSmokeTests: XCTestCase {
    func testExposesPackageVersion() {
        XCTAssertEqual(BurningPaper.version, "0.1.0")
    }
}

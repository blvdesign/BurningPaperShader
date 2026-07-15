import XCTest
@testable import BurningPaper

final class PackageSmokeTests: XCTestCase {
    func testExposesInternalPackageVersion() {
        XCTAssertEqual(BurningPaperPackage.version, "0.1.0")
    }
}

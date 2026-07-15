import XCTest
import BurningPaperShaderTypes

final class UniformABITests: XCTestCase {
    func testBurningPaperUniformLayout() {
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.size, 144)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.stride, 144)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.alignment, 16)

        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.textureSize), 0)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.viewSize), 8)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.paperColor), 16)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.time), 32)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.ignitionPoint), 40)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.hasIgnition), 64)
        XCTAssertEqual(MemoryLayout<BurningPaperUniforms>.offset(of: \.resetState), 128)
    }
}

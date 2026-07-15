import BurningPaper
import XCTest

final class BurningPaperPublicAPITests: XCTestCase {
    func testConsumerCanConstructAndMutatePublicConfiguration() {
        var color = BurningPaperColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1)
        color.alpha = 0.6

        var configuration = BurningPaperConfiguration(paperColor: color)
        configuration.burnSpeed = 1.4
        configuration.flameAmount = 0.3

        XCTAssertEqual(configuration.paperColor.alpha, 0.6)
        XCTAssertEqual(configuration.burnSpeed, 1.4)
        XCTAssertEqual(configuration.flameAmount, 0.3)
        XCTAssertEqual(BurningPaperColor.naturalWhite.alpha, 1)
        XCTAssertEqual(BurningPaperConfiguration.default.paperColor, .naturalWhite)
    }
}

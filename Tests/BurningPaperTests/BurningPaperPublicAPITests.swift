import BurningPaper
import CoreGraphics
import Metal
import XCTest

final class BurningPaperPublicAPITests: XCTestCase {
    @MainActor
    func testConsumerCanConstructBurningPaperView() {
        let controller = BurningPaperController()

        _ = BurningPaperView(
            controller: controller,
            configuration: BurningPaperConfiguration(flameAmount: 0.2),
            isInteractive: false
        )
    }

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

    func testConsumerCanUseLowLevelRendererAPI() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try BurningPaperRenderer(
            device: device,
            colorPixelFormat: .bgra8Unorm
        )

        renderer.configuration = BurningPaperConfiguration(flameAmount: 0.2)
        renderer.ignite(at: CGPoint(x: 0.5, y: 0.5))
        renderer.ignite(path: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.8)])
        renderer.reset()

        XCTAssertEqual(renderer.configuration.flameAmount, 0.2)
    }
}

import Metal
import XCTest
@testable import BurningPaper

final class BurningPaperRendererTests: XCTestCase {
    func testRendererLoadsPackageMetalLibrary() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())

        _ = try BurningPaperRenderer(
            device: device,
            colorPixelFormat: .bgra8Unorm
        )
    }

    func testRendererErrorsHaveDescriptiveMessages() {
        XCTAssertEqual(
            BurningPaperRendererError.commandQueueCreationFailed.errorDescription,
            "Unable to create a Metal command queue."
        )
        XCTAssertEqual(
            BurningPaperRendererError.shaderLibraryLoadingFailed(reason: "missing bundle").errorDescription,
            "Unable to load the BurningPaper package Metal library: missing bundle"
        )
        XCTAssertEqual(
            BurningPaperRendererError.shaderFunctionMissing(name: "paperFragment").errorDescription,
            "The BurningPaper Metal function 'paperFragment' is missing from the package library."
        )
        XCTAssertEqual(
            BurningPaperRendererError.computePipelineCreationFailed(reason: "unsupported").errorDescription,
            "Unable to create the BurningPaper compute pipeline: unsupported"
        )
        XCTAssertEqual(
            BurningPaperRendererError.renderPipelineCreationFailed(reason: "unsupported").errorDescription,
            "Unable to create the BurningPaper render pipeline: unsupported"
        )
    }

    func testStateTextureSizeCapsLongDimensionAndPreservesAspectRatio() {
        XCTAssertEqual(
            BurningPaperStateTextureSizer.size(
                for: CGSize(width: 1179, height: 2556),
                maxDimension: 1024
            ),
            BurningPaperTextureSize(width: 472, height: 1024)
        )
        XCTAssertEqual(
            BurningPaperStateTextureSizer.size(
                for: CGSize(width: 2556, height: 1179),
                maxDimension: 1024
            ),
            BurningPaperTextureSize(width: 1024, height: 472)
        )
    }

    func testIgnitionQueuePreservesAllPointsInOneMaximumLengthPath() {
        let path = (0..<BurnIgnitionPlanner.maximumIgnitionsPerPath).map { index in
            BurnIgnition(
                normalizedPoint: CGPoint(x: CGFloat(index) / 95, y: 0.5),
                radiusScale: 1,
                heatScale: 1,
                seed: Float(index)
            )
        }
        var queue = BurningPaperIgnitionQueue()

        queue.enqueue(path)
        var drained: [BurnIgnition] = []
        while queue.count > 0 {
            drained.append(contentsOf: queue.drainFrame())
        }

        XCTAssertEqual(drained, path)
        XCTAssertEqual(drained.count, 96)
    }

    func testIgnitionQueueEvictsOnlyCompleteOldestBatchesAtCapacity() {
        let oldPath = makeIgnitions(count: 96, seedOffset: 0)
        let preservedPaths = (1...8).map { makeIgnitions(count: 96, seedOffset: $0 * 100) }
        var queue = BurningPaperIgnitionQueue()

        queue.enqueue(oldPath)
        preservedPaths.forEach { queue.enqueue($0) }

        var drained: [BurnIgnition] = []
        while queue.count > 0 {
            drained.append(contentsOf: queue.drainFrame())
        }

        XCTAssertEqual(drained, preservedPaths.flatMap { $0 })
        XCTAssertFalse(drained.contains { $0.seed < 100 })
    }

    func testResetFramePreservesQueuedIgnitionsForFollowingFrame() {
        let path = makeIgnitions(count: 24, seedOffset: 0)
        var queue = BurningPaperIgnitionQueue()
        queue.enqueue(path)

        let resetFrame = BurningPaperFrameIgnitionPolicy.takeIgnitions(
            from: &queue,
            isResetting: true
        )
        let followingFrame = BurningPaperFrameIgnitionPolicy.takeIgnitions(
            from: &queue,
            isResetting: false
        )

        XCTAssertTrue(resetFrame.isEmpty)
        XCTAssertEqual(followingFrame, Array(path.prefix(18)))
        XCTAssertEqual(queue.count, 6)
    }

    private func makeIgnitions(count: Int, seedOffset: Int) -> [BurnIgnition] {
        (0..<count).map { index in
            BurnIgnition(
                normalizedPoint: CGPoint(x: 0.5, y: 0.5),
                radiusScale: 1,
                heatScale: 1,
                seed: Float(seedOffset + index)
            )
        }
    }
}

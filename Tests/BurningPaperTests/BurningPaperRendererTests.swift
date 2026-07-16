import CoreGraphics
import Foundation
import Metal
import MetalKit
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

    func testRenderPipelineUsesStraightAlphaCompositing() {
        let descriptor = BurningPaperRenderPipelineDescriptor.make(
            colorPixelFormat: .bgra8Unorm
        )
        let attachment = descriptor.colorAttachments[0]

        XCTAssertEqual(attachment?.sourceRGBBlendFactor, .sourceAlpha)
        XCTAssertEqual(attachment?.sourceAlphaBlendFactor, .one)
        XCTAssertEqual(attachment?.destinationRGBBlendFactor, .oneMinusSourceAlpha)
        XCTAssertEqual(attachment?.destinationAlphaBlendFactor, .oneMinusSourceAlpha)
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

    func testStateTextureSizeDoesNotUpscaleSmallDrawable() {
        XCTAssertEqual(
            BurningPaperStateTextureSizer.size(
                for: CGSize(width: 320, height: 480),
                maxDimension: 1024
            ),
            BurningPaperTextureSize(width: 320, height: 480)
        )
    }

    func testStateTextureSizeRejectsInvalidDrawable() {
        XCTAssertNil(
            BurningPaperStateTextureSizer.size(
                for: .zero,
                maxDimension: 1024
            )
        )
        XCTAssertNil(
            BurningPaperStateTextureSizer.size(
                for: CGSize(width: CGFloat.nan, height: 480),
                maxDimension: 1024
            )
        )
        XCTAssertNil(
            BurningPaperStateTextureSizer.size(
                for: CGSize(width: 320, height: CGFloat.infinity),
                maxDimension: 1024
            )
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

    func testIgnitionQueueKeepsNewestCompletePathWithinNinetySixTotal() {
        let oldPath = makeIgnitions(count: 96, seedOffset: 0)
        let newestPath = makeIgnitions(count: 24, seedOffset: 100)
        var queue = BurningPaperIgnitionQueue()

        queue.enqueue(oldPath)
        queue.enqueue(newestPath)

        var drained: [BurnIgnition] = []
        while queue.count > 0 {
            drained.append(contentsOf: queue.drainFrame())
        }

        XCTAssertEqual(BurningPaperIgnitionQueue.maximumQueuedIgnitions, 96)
        XCTAssertEqual(drained, newestPath)
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

    func testIgnitionPassesDoNotAdvanceSimulationBeforeSingleFrameStep() {
        let ignitions = makeIgnitions(count: 3, seedOffset: 0)

        let steps = BurningPaperSimulationStepPolicy.steps(
            ignitions: ignitions,
            frameDeltaTime: 0.025,
            isResetting: false
        )

        XCTAssertEqual(steps.map(\.deltaTime), [0, 0, 0, 0.025])
        XCTAssertEqual(steps.compactMap(\.ignition), ignitions)
        XCTAssertNil(steps.last?.ignition)
        XCTAssertEqual(steps.filter { $0.deltaTime > 0 }.count, 1)
    }

    func testResetPassPrecedesSingleFrameStepWithoutAdvancingTime() {
        let steps = BurningPaperSimulationStepPolicy.steps(
            ignitions: [],
            frameDeltaTime: 0.025,
            isResetting: true
        )

        XCTAssertEqual(steps.map(\.deltaTime), [0, 0.025])
        XCTAssertEqual(steps.map(\.resetsState), [true, false])
        XCTAssertEqual(steps.filter { $0.deltaTime > 0 }.count, 1)
    }

    func testTextureStateReplacementIsAtomicWhenSecondAllocationFails() {
        var state = BurningPaperTextureState<String>()
        var initialTextures = ["old-read", "old-write"].makeIterator()
        XCTAssertTrue(
            state.replace(
                size: BurningPaperTextureSize(width: 320, height: 480),
                makeTexture: { initialTextures.next() }
            )
        )

        var allocationCount = 0
        XCTAssertFalse(
            state.replace(
                size: BurningPaperTextureSize(width: 640, height: 960),
                makeTexture: {
                    allocationCount += 1
                    return allocationCount == 1 ? "new-read" : nil
                }
            )
        )

        XCTAssertEqual(state.read, "old-read")
        XCTAssertEqual(state.write, "old-write")
        XCTAssertEqual(state.size, BurningPaperTextureSize(width: 320, height: 480))
    }

    func testRendererRejectsIncompatibleMTKViewContract() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try BurningPaperRenderer(device: device, colorPixelFormat: .bgra8Unorm)
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.sampleCount = 1

        XCTAssertTrue(renderer.isCompatible(with: view))

        view.colorPixelFormat = .rgba16Float
        XCTAssertFalse(renderer.isCompatible(with: view))

        view.colorPixelFormat = .bgra8Unorm
        view.sampleCount = 4
        XCTAssertFalse(renderer.isCompatible(with: view))

        view.sampleCount = 1
        view.device = nil
        XCTAssertFalse(renderer.isCompatible(with: view))
    }

    func testPublicMutationCanBeCalledConcurrentlyWithoutDeadlock() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try BurningPaperRenderer(device: device, colorPixelFormat: .bgra8Unorm)

        DispatchQueue.concurrentPerform(iterations: 200) { index in
            switch index % 4 {
            case 0:
                renderer.configuration = BurningPaperConfiguration(burnSpeed: Float(index % 3) + 0.5)
            case 1:
                renderer.ignite(at: CGPoint(x: 0.25, y: 0.75))
            case 2:
                renderer.ignite(path: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.9)])
            default:
                renderer.reset()
            }
        }

        XCTAssertTrue((0.01...3).contains(renderer.configuration.burnSpeed))
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

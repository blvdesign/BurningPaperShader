import CoreGraphics
import MetalKit
import XCTest
@testable import BurningPaper

@MainActor
final class BurningPaperViewTests: XCTestCase {
    func testControllerCommandsAreConsumedOnceAcrossConfigurationUpdates() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 1)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer
        let point = CGPoint(x: 0.25, y: 0.75)

        controller.ignite(at: point)
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: BurningPaperConfiguration(burnSpeed: 1.5)
        )

        XCTAssertEqual(renderer.events, [.path([point])])
        XCTAssertEqual(renderer.configuration.burnSpeed, 1.5)
    }

    func testDragThenResetPreservesOrderSoResetWins() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 2)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer

        interaction.dragChanged(
            location: CGPoint(x: 20, y: 20),
            in: CGSize(width: 100, height: 100)
        )
        controller.reset()

        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        XCTAssertEqual(renderer.events.count, 2)
        guard case .ignitions = renderer.events[0] else {
            return XCTFail("Expected drag ignitions before reset")
        }
        XCTAssertEqual(renderer.events[1], .reset)
    }

    func testResetThenDragPreservesOrderAndNewDragStartsFresh() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 3)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer
        let size = CGSize(width: 100, height: 100)

        interaction.dragChanged(location: CGPoint(x: 10, y: 10), in: size)
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )
        renderer.removeAllEvents()

        controller.reset()
        interaction.dragChanged(location: CGPoint(x: 90, y: 90), in: size)
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        XCTAssertEqual(renderer.events.count, 2)
        XCTAssertEqual(renderer.events[0], .reset)
        guard case let .ignitions(ignitions) = renderer.events[1] else {
            return XCTFail("Expected new drag ignitions after reset")
        }
        XCTAssertEqual(ignitions.count, 1)
    }

    func testCommandsRemainPendingUntilRendererBecomesAvailable() {
        let controller = BurningPaperController()
        let interaction = BurningPaperViewState(controller: controller, seed: 4)
        let coordinator = BurningPaperMetalView.Coordinator()
        let point = CGPoint(x: 0.3, y: 0.7)

        controller.ignite(at: point)
        interaction.dragChanged(
            location: CGPoint(x: 80, y: 20),
            in: CGSize(width: 100, height: 100)
        )
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        let renderer = RecordingBurningPaperRenderer()
        coordinator.renderer = renderer
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        XCTAssertEqual(renderer.events.count, 2)
        XCTAssertEqual(renderer.events[0], .path([point]))
        guard case .ignitions = renderer.events[1] else {
            return XCTFail("Expected retained gesture ignitions after the command")
        }
    }

    func testInteractiveDragPlansContinuousVariedIgnitions() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 5)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer
        let size = CGSize(width: 200, height: 100)

        interaction.dragChanged(
            location: CGPoint(x: 20, y: 20),
            in: size
        )
        interaction.dragChanged(
            location: CGPoint(x: 180, y: 80),
            in: size
        )
        interaction.dragEnded(
            location: CGPoint(x: 190, y: 90),
            in: size
        )
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        let ignitions = renderer.events.flatMap { event -> [BurnIgnition] in
            guard case let .ignitions(ignitions) = event else { return [] }
            return ignitions
        }
        XCTAssertGreaterThan(ignitions.count, 3)
        XCTAssertGreaterThan(Set(ignitions.map(\.radiusScale)).count, 1)
        XCTAssertGreaterThan(Set(ignitions.map(\.seed)).count, 1)
        XCTAssertTrue(ignitions.allSatisfy {
            (0...1).contains($0.normalizedPoint.x) &&
                (0...1).contains($0.normalizedPoint.y)
        })
    }

    func testNonInteractiveDragDoesNotPlanPackageIgnitions() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 6)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer
        interaction.setInteractive(false)

        interaction.dragChanged(
            location: CGPoint(x: 25, y: 25),
            in: CGSize(width: 100, height: 100)
        )
        interaction.dragEnded(
            location: CGPoint(x: 75, y: 75),
            in: CGSize(width: 100, height: 100)
        )
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        XCTAssertTrue(renderer.events.isEmpty)
    }

    func testDisablingInteractionMidDragPreventsReenabledDragConnectingToOldPoint() {
        let controller = BurningPaperController()
        let renderer = RecordingBurningPaperRenderer()
        let interaction = BurningPaperViewState(controller: controller, seed: 7)
        let coordinator = BurningPaperMetalView.Coordinator()
        coordinator.renderer = renderer
        let size = CGSize(width: 100, height: 100)

        interaction.dragChanged(location: CGPoint(x: 10, y: 10), in: size)
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )
        renderer.removeAllEvents()

        interaction.setInteractive(false)
        interaction.setInteractive(true)
        interaction.dragChanged(location: CGPoint(x: 90, y: 90), in: size)
        coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: .default
        )

        guard case let .ignitions(ignitions) = renderer.events.first else {
            return XCTFail("Expected a fresh ignition after re-enabling interaction")
        }
        XCTAssertEqual(renderer.events.count, 1)
        XCTAssertEqual(ignitions.count, 1)
    }

    func testMetalViewUsesTransparentHighRefreshRenderingContract() {
        let view = MTKView()

        BurningPaperMetalView.configure(view)

        XCTAssertEqual(view.colorPixelFormat, .bgra8Unorm)
        XCTAssertFalse(view.framebufferOnly)
        XCTAssertFalse(view.isOpaque)
        XCTAssertEqual(view.clearColor.alpha, 0)
        XCTAssertEqual(view.preferredFramesPerSecond, 120)
        XCTAssertFalse(view.enableSetNeedsDisplay)
        XCTAssertFalse(view.isPaused)
    }

    func testRendererInitializationFailureIsRetainedAndShowsOpaquePaperFallback() throws {
        let view = MTKView()
        view.device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        BurningPaperMetalView.configure(view)
        let expectedError = TestRendererError.failed
        let coordinator = BurningPaperMetalView.Coordinator { _, _ in
            throw expectedError
        }
        let configuration = BurningPaperConfiguration(
            paperColor: BurningPaperColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.1)
        )

        coordinator.installRenderer(in: view, configuration: configuration)

        XCTAssertEqual(coordinator.rendererInitializationError as? TestRendererError, expectedError)
        XCTAssertTrue(view.isOpaque)
        XCTAssertEqual(view.clearColor.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(view.clearColor.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(view.clearColor.blue, 0.6, accuracy: 0.001)
        XCTAssertEqual(view.clearColor.alpha, 1, accuracy: 0.001)
    }

}

private final class RecordingBurningPaperRenderer: BurningPaperRendering {
    enum Event: Equatable {
        case path([CGPoint])
        case ignitions([BurnIgnition])
        case reset
    }

    var configuration = BurningPaperConfiguration.default
    private(set) var events: [Event] = []

    func ignite(path: [CGPoint]) {
        events.append(.path(path))
    }

    func ignite(_ ignitions: [BurnIgnition]) {
        events.append(.ignitions(ignitions))
    }

    func reset() {
        events.append(.reset)
    }

    func removeAllEvents() {
        events.removeAll(keepingCapacity: true)
    }
}

private enum TestRendererError: Error, Equatable {
    case failed
}

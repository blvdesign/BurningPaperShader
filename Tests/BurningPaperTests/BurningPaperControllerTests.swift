import CoreGraphics
import XCTest
@testable import BurningPaper

@MainActor
@available(macOS 10.15, *)
final class BurningPaperControllerTests: XCTestCase {
    func testIgnitePointPublishesNormalizedIgniteCommand() {
        let controller = BurningPaperController()

        controller.ignite(at: CGPoint(x: 0.25, y: 0.75))

        XCTAssertEqual(
            controller.drainPendingCommands().first?.kind,
            .ignite([CGPoint(x: 0.25, y: 0.75)])
        )
    }

    func testIgnitePathPublishesEveryNormalizedPoint() {
        let controller = BurningPaperController()
        let points = [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: 0.4, y: 0.6),
            CGPoint(x: 0.8, y: 0.9)
        ]

        controller.ignite(path: points)

        XCTAssertEqual(controller.drainPendingCommands().first?.kind, .ignite(points))
    }

    func testResetPublishesResetCommand() {
        let controller = BurningPaperController()

        controller.reset()

        XCTAssertEqual(controller.drainPendingCommands().first?.kind, .reset)
    }

    func testCoordinatesAreClampedToNormalizedRange() {
        let controller = BurningPaperController()

        controller.ignite(path: [
            CGPoint(x: -2, y: 3),
            CGPoint(x: 4, y: -5)
        ])

        XCTAssertEqual(
            controller.drainPendingCommands().first?.kind,
            .ignite([
                CGPoint(x: 0, y: 1),
                CGPoint(x: 1, y: 0)
            ])
        )
    }

    func testRepeatedIdenticalCommandsHaveDifferentIdentities() {
        let controller = BurningPaperController()
        let point = CGPoint(x: 0.5, y: 0.5)

        controller.ignite(at: point)
        controller.ignite(at: point)
        let commands = controller.drainPendingCommands()

        XCTAssertEqual(commands.count, 2)
        XCTAssertNotEqual(commands[0].id, commands[1].id)
    }

    func testEmptyPathIsANoOp() {
        let controller = BurningPaperController()

        let revisionBeforeEmptyPath = controller.commandRevision
        controller.ignite(path: [])

        XCTAssertEqual(controller.commandRevision, revisionBeforeEmptyPath)
        XCTAssertTrue(controller.drainPendingCommands().isEmpty)
    }

    func testNonFinitePointIsRejected() {
        let controller = BurningPaperController()

        let revisionBeforeInvalidPoint = controller.commandRevision
        controller.ignite(at: CGPoint(x: .nan, y: 0.5))

        XCTAssertEqual(controller.commandRevision, revisionBeforeInvalidPoint)
        XCTAssertTrue(controller.drainPendingCommands().isEmpty)
    }

    func testNonFinitePathPointsAreRemovedBeforePublishing() {
        let controller = BurningPaperController()

        controller.ignite(path: [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: .infinity, y: 0.5),
            CGPoint(x: 0.8, y: 0.9)
        ])

        XCTAssertEqual(
            controller.drainPendingCommands().first?.kind,
            .ignite([
                CGPoint(x: 0.1, y: 0.2),
                CGPoint(x: 0.8, y: 0.9)
            ])
        )
    }

    func testSynchronousCommandsDrainOnceInExactOrder() {
        let controller = BurningPaperController()
        let firstPoint = CGPoint(x: 0.2, y: 0.3)
        let secondPoint = CGPoint(x: 0.7, y: 0.8)

        controller.reset()
        controller.ignite(at: firstPoint)
        controller.ignite(at: secondPoint)

        let commands = controller.drainPendingCommands()

        XCTAssertEqual(commands.map(\.kind), [
            .reset,
            .ignite([firstPoint]),
            .ignite([secondPoint])
        ])
        XCTAssertEqual(controller.commandRevision, 3)
        XCTAssertTrue(controller.drainPendingCommands().isEmpty)
        XCTAssertEqual(controller.commandRevision, 3)
    }

    func testInvalidAndEmptyInputsDoNotChangeRevisionOrQueue() {
        let controller = BurningPaperController()
        let validPoint = CGPoint(x: 0.25, y: 0.75)
        controller.ignite(at: validPoint)
        let revisionBeforeInvalidInputs = controller.commandRevision

        controller.ignite(path: [])
        controller.ignite(at: CGPoint(x: .nan, y: 0.5))
        controller.ignite(path: [CGPoint(x: 0.5, y: .infinity)])

        XCTAssertEqual(controller.commandRevision, revisionBeforeInvalidInputs)
        XCTAssertEqual(
            controller.drainPendingCommands().map(\.kind),
            [.ignite([validPoint])]
        )
    }
}

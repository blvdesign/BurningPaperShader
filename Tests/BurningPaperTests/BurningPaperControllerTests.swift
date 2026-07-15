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
            controller.command?.kind,
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

        XCTAssertEqual(controller.command?.kind, .ignite(points))
    }

    func testResetPublishesResetCommand() {
        let controller = BurningPaperController()

        controller.reset()

        XCTAssertEqual(controller.command?.kind, .reset)
    }

    func testCoordinatesAreClampedToNormalizedRange() {
        let controller = BurningPaperController()

        controller.ignite(path: [
            CGPoint(x: -2, y: 3),
            CGPoint(x: 4, y: -5)
        ])

        XCTAssertEqual(
            controller.command?.kind,
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
        let firstID = controller.command?.id
        controller.ignite(at: point)
        let secondID = controller.command?.id

        XCTAssertNotNil(firstID)
        XCTAssertNotNil(secondID)
        XCTAssertNotEqual(firstID, secondID)
    }

    func testEmptyPathIsANoOp() {
        let controller = BurningPaperController()

        controller.reset()
        let commandBeforeEmptyPath = controller.command
        controller.ignite(path: [])

        XCTAssertEqual(controller.command, commandBeforeEmptyPath)
    }

    func testNonFinitePointIsRejected() {
        let controller = BurningPaperController()

        controller.reset()
        let commandBeforeInvalidPoint = controller.command
        controller.ignite(at: CGPoint(x: .nan, y: 0.5))

        XCTAssertEqual(controller.command, commandBeforeInvalidPoint)
    }

    func testNonFinitePathPointsAreRemovedBeforePublishing() {
        let controller = BurningPaperController()

        controller.ignite(path: [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: .infinity, y: 0.5),
            CGPoint(x: 0.8, y: 0.9)
        ])

        XCTAssertEqual(
            controller.command?.kind,
            .ignite([
                CGPoint(x: 0.1, y: 0.2),
                CGPoint(x: 0.8, y: 0.9)
            ])
        )
    }
}

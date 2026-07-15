import CoreGraphics
import XCTest
@testable import BurningPaper

final class BurnIgnitionPlannerTests: XCTestCase {
    func testDeterministicDragPreservesProvenVariation() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(
            from: CGPoint(x: 0.2, y: 0.2),
            to: CGPoint(x: 0.7, y: 0.62),
            random: &random
        )

        XCTAssertGreaterThan(ignitions.count, 8)
        XCTAssertLessThanOrEqual(ignitions.count, 26)

        let radiusScales = ignitions.map(\.radiusScale)
        XCTAssertGreaterThan(radiusScales.max() ?? 0, 1.2)
        XCTAssertLessThan(radiusScales.min() ?? 1, 0.7)

        let uniqueRoundedSeeds = Set(ignitions.map { Int($0.seed.rounded()) })
        XCTAssertGreaterThan(uniqueRoundedSeeds.count, ignitions.count / 2)
    }

    func testGeneratedPointsAreClampedToNormalizedCoordinates() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(
            from: CGPoint(x: -1, y: 2),
            to: CGPoint(x: 3, y: -4),
            random: &random
        )

        XCTAssertFalse(ignitions.isEmpty)
        XCTAssertTrue(ignitions.allSatisfy {
            (0...1).contains($0.normalizedPoint.x) &&
                (0...1).contains($0.normalizedPoint.y)
        })
    }

    func testNilStartCreatesOneIgnition() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(
            from: nil,
            to: CGPoint(x: 0.4, y: 0.6),
            random: &random
        )

        XCTAssertEqual(ignitions.count, 1)
        XCTAssertEqual(ignitions.first?.normalizedPoint, CGPoint(x: 0.4, y: 0.6))
    }

    func testPathSkipsRepeatedSharedVertices() {
        let points = [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: 0.5, y: 0.45),
            CGPoint(x: 0.8, y: 0.7)
        ]
        var compactRandom = SeededRandomNumberGenerator(seed: 91)
        var repeatedRandom = SeededRandomNumberGenerator(seed: 91)

        let compact = BurnIgnitionPlanner.ignitions(for: points, random: &compactRandom)
        let withRepeatedVertex = BurnIgnitionPlanner.ignitions(
            for: [points[0], points[1], points[1], points[2]],
            random: &repeatedRandom
        )

        XCTAssertEqual(withRepeatedVertex, compact)
    }

    func testNonemptyPathNeverCreatesAnEmptyBurn() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(
            for: [CGPoint(x: 0.25, y: 0.75)],
            random: &random
        )

        XCTAssertEqual(ignitions.count, 1)
    }
}

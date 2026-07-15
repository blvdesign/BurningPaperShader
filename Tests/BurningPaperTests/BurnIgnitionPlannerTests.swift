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

    func testLongPathFitsRendererBudgetAndPreservesEndpointCoverage() {
        let points = (0...240).map { index in
            CGPoint(x: CGFloat(index) / 240, y: 0.5)
        }
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(for: points, random: &random)

        XCTAssertFalse(ignitions.isEmpty)
        XCTAssertLessThanOrEqual(ignitions.count, BurnIgnitionPlanner.maximumIgnitionsPerPath)
        XCTAssertEqual(BurnIgnitionPlanner.maximumIgnitionsPerPath, 96)
        XCTAssertEqual(ignitions.first?.normalizedPoint, points.first)
        XCTAssertGreaterThan(ignitions.last?.normalizedPoint.x ?? 0, 0.95)
        XCTAssertLessThan(abs((ignitions.last?.normalizedPoint.y ?? 0) - 0.5), 0.08)
    }

    func testDirectInvalidEndReturnsNoIgnitions() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let nanEnd = BurnIgnitionPlanner.ignitions(
            from: CGPoint(x: 0.2, y: 0.2),
            to: CGPoint(x: .nan, y: 0.5),
            random: &random
        )
        let infiniteEnd = BurnIgnitionPlanner.ignitions(
            from: nil,
            to: CGPoint(x: 0.5, y: .infinity),
            random: &random
        )

        XCTAssertTrue(nanEnd.isEmpty)
        XCTAssertTrue(infiniteEnd.isEmpty)
    }

    func testDirectInvalidStartFallsBackToSingleValidEndIgnition() {
        var random = SeededRandomNumberGenerator(seed: 42)

        let ignitions = BurnIgnitionPlanner.ignitions(
            from: CGPoint(x: -.infinity, y: 0.2),
            to: CGPoint(x: 0.4, y: 0.6),
            random: &random
        )

        XCTAssertEqual(ignitions.count, 1)
        XCTAssertEqual(ignitions.first?.normalizedPoint, CGPoint(x: 0.4, y: 0.6))
    }

    func testPathSkipsNonFinitePointsWithoutChangingValidExpansion() {
        let validPoints = [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: 0.5, y: 0.45),
            CGPoint(x: 0.8, y: 0.7)
        ]
        var validRandom = SeededRandomNumberGenerator(seed: 73)
        var invalidRandom = SeededRandomNumberGenerator(seed: 73)

        let valid = BurnIgnitionPlanner.ignitions(for: validPoints, random: &validRandom)
        let withInvalidPoints = BurnIgnitionPlanner.ignitions(
            for: [
                validPoints[0],
                CGPoint(x: .nan, y: 0.3),
                validPoints[1],
                CGPoint(x: 0.6, y: .infinity),
                validPoints[2]
            ],
            random: &invalidRandom
        )

        XCTAssertEqual(withInvalidPoints, valid)
    }
}

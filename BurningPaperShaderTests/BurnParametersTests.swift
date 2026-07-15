import CoreGraphics
import XCTest
@testable import BurningPaperShader

final class BurnParametersTests: XCTestCase {
    func testSanitizedClampsUnsafeValues() {
        let unsafe = BurnParameters(
            burnSpeed: -1,
            spreadRate: 10,
            coolingRate: -2,
            ignitionRadius: 1,
            edgeWidth: -0.1,
            stainWidth: 2,
            charWidth: -0.5,
            glowAmount: 5,
            noiseStrength: -3,
            frontComplexity: 9,
            ignitionVariance: -4,
            flameAmount: 4,
            paperWrinkleAmount: -2,
            smokeAmount: 8,
            emberAmount: -2
        )

        let safe = unsafe.sanitized

        XCTAssertEqual(safe.burnSpeed, 0.01)
        XCTAssertEqual(safe.spreadRate, 3.0)
        XCTAssertEqual(safe.coolingRate, 0.0)
        XCTAssertEqual(safe.ignitionRadius, 0.2)
        XCTAssertEqual(safe.edgeWidth, 0.001)
        XCTAssertEqual(safe.stainWidth, 0.25)
        XCTAssertEqual(safe.charWidth, 0.001)
        XCTAssertEqual(safe.glowAmount, 1.0)
        XCTAssertEqual(safe.noiseStrength, 0.0)
        XCTAssertEqual(safe.frontComplexity, 1.0)
        XCTAssertEqual(safe.ignitionVariance, 0.0)
        XCTAssertEqual(safe.flameAmount, 1.0)
        XCTAssertEqual(safe.paperWrinkleAmount, 0.0)
        XCTAssertEqual(safe.smokeAmount, 1.0)
        XCTAssertEqual(safe.emberAmount, 0.0)
    }

    func testBurnTriggerCanCarryContinuousIgnitionsWithPerPointVariation() {
        let points = [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: 0.2, y: 0.25),
            CGPoint(x: 0.32, y: 0.31)
        ]

        let trigger = BurnTrigger(
            ignitions: [
                BurnIgnition(normalizedPoint: points[0], radiusScale: 0.8, heatScale: 0.7, seed: 11),
                BurnIgnition(normalizedPoint: points[1], radiusScale: 1.2, heatScale: 1.1, seed: 29),
                BurnIgnition(normalizedPoint: points[2], radiusScale: 1.5, heatScale: 0.95, seed: 41)
            ]
        )

        XCTAssertEqual(trigger.ignitions.map(\.normalizedPoint), points)
        XCTAssertNotEqual(trigger.ignitions[0].radiusScale, trigger.ignitions[1].radiusScale)
        XCTAssertNotEqual(trigger.ignitions[1].seed, trigger.ignitions[2].seed)
    }

    func testIgnitionPlannerVariesDragIgnitionsWithoutUniformStamping() {
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
}

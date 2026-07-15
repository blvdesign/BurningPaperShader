import XCTest
@testable import BurningPaper

final class BurningPaperConfigurationTests: XCTestCase {
    func testDefaultPreservesExistingBurnParametersAndNaturalPaperColor() {
        let configuration = BurningPaperConfiguration.default

        XCTAssertEqual(configuration.burnSpeed, 0.94)
        XCTAssertEqual(configuration.spreadRate, 1.16)
        XCTAssertEqual(configuration.coolingRate, 0.11)
        XCTAssertEqual(configuration.ignitionRadius, 0.022)
        XCTAssertEqual(configuration.edgeWidth, 0.065)
        XCTAssertEqual(configuration.stainWidth, 0.14)
        XCTAssertEqual(configuration.charWidth, 0.022)
        XCTAssertEqual(configuration.glowAmount, 0.46)
        XCTAssertEqual(configuration.noiseStrength, 0.88)
        XCTAssertEqual(configuration.frontComplexity, 0.94)
        XCTAssertEqual(configuration.ignitionVariance, 0.95)
        XCTAssertEqual(configuration.flameAmount, 0.42)
        XCTAssertEqual(configuration.paperWrinkleAmount, 0.72)
        XCTAssertEqual(configuration.smokeAmount, 0.22)
        XCTAssertEqual(configuration.emberAmount, 0.24)
        XCTAssertEqual(configuration.paperColor, .naturalWhite)
        XCTAssertEqual(BurningPaperConfiguration(), configuration)
    }

    func testSanitizedClampsEveryParameterToItsLowerBound() {
        let unsafe = BurningPaperConfiguration(
            burnSpeed: -1,
            spreadRate: -1,
            coolingRate: -1,
            ignitionRadius: -1,
            edgeWidth: -1,
            stainWidth: -1,
            charWidth: -1,
            glowAmount: -1,
            noiseStrength: -1,
            frontComplexity: -1,
            ignitionVariance: -1,
            flameAmount: -1,
            paperWrinkleAmount: -1,
            smokeAmount: -1,
            emberAmount: -1
        ).sanitized

        XCTAssertEqual(unsafe.burnSpeed, 0.01)
        XCTAssertEqual(unsafe.spreadRate, 0.0)
        XCTAssertEqual(unsafe.coolingRate, 0.0)
        XCTAssertEqual(unsafe.ignitionRadius, 0.005)
        XCTAssertEqual(unsafe.edgeWidth, 0.001)
        XCTAssertEqual(unsafe.stainWidth, 0.001)
        XCTAssertEqual(unsafe.charWidth, 0.001)
        XCTAssertEqual(unsafe.glowAmount, 0.0)
        XCTAssertEqual(unsafe.noiseStrength, 0.0)
        XCTAssertEqual(unsafe.frontComplexity, 0.0)
        XCTAssertEqual(unsafe.ignitionVariance, 0.0)
        XCTAssertEqual(unsafe.flameAmount, 0.0)
        XCTAssertEqual(unsafe.paperWrinkleAmount, 0.0)
        XCTAssertEqual(unsafe.smokeAmount, 0.0)
        XCTAssertEqual(unsafe.emberAmount, 0.0)
    }

    func testSanitizedClampsEveryParameterToItsUpperBound() {
        let unsafe = BurningPaperConfiguration(
            burnSpeed: 10,
            spreadRate: 10,
            coolingRate: 10,
            ignitionRadius: 10,
            edgeWidth: 10,
            stainWidth: 10,
            charWidth: 10,
            glowAmount: 10,
            noiseStrength: 10,
            frontComplexity: 10,
            ignitionVariance: 10,
            flameAmount: 10,
            paperWrinkleAmount: 10,
            smokeAmount: 10,
            emberAmount: 10
        ).sanitized

        XCTAssertEqual(unsafe.burnSpeed, 3.0)
        XCTAssertEqual(unsafe.spreadRate, 3.0)
        XCTAssertEqual(unsafe.coolingRate, 2.0)
        XCTAssertEqual(unsafe.ignitionRadius, 0.2)
        XCTAssertEqual(unsafe.edgeWidth, 0.25)
        XCTAssertEqual(unsafe.stainWidth, 0.25)
        XCTAssertEqual(unsafe.charWidth, 0.15)
        XCTAssertEqual(unsafe.glowAmount, 1.0)
        XCTAssertEqual(unsafe.noiseStrength, 1.0)
        XCTAssertEqual(unsafe.frontComplexity, 1.0)
        XCTAssertEqual(unsafe.ignitionVariance, 1.0)
        XCTAssertEqual(unsafe.flameAmount, 1.0)
        XCTAssertEqual(unsafe.paperWrinkleAmount, 1.0)
        XCTAssertEqual(unsafe.smokeAmount, 1.0)
        XCTAssertEqual(unsafe.emberAmount, 1.0)
    }

    func testSanitizedClampsPaperColorChannels() {
        let configuration = BurningPaperConfiguration(
            paperColor: BurningPaperColor(red: -1, green: 2, blue: -3, alpha: 4)
        ).sanitized

        XCTAssertEqual(
            configuration.paperColor,
            BurningPaperColor(red: 0, green: 1, blue: 0, alpha: 1)
        )
    }

    func testDefaultConfigurationCanBeMutatedThroughPublicProperties() {
        var configuration = BurningPaperConfiguration.default

        configuration.burnSpeed = 1.5
        configuration.paperColor = BurningPaperColor(red: 0.8, green: 0.7, blue: 0.6, alpha: 0.9)

        XCTAssertEqual(configuration.burnSpeed, 1.5)
        XCTAssertEqual(
            configuration.paperColor,
            BurningPaperColor(red: 0.8, green: 0.7, blue: 0.6, alpha: 0.9)
        )
    }
}

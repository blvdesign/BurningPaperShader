import Foundation

struct BurnParameters: Equatable {
    var burnSpeed: Float
    var spreadRate: Float
    var coolingRate: Float
    var ignitionRadius: Float
    var edgeWidth: Float
    var stainWidth: Float
    var charWidth: Float
    var glowAmount: Float
    var noiseStrength: Float
    var frontComplexity: Float
    var ignitionVariance: Float
    var flameAmount: Float
    var paperWrinkleAmount: Float
    var smokeAmount: Float
    var emberAmount: Float

    static let defaults = BurnParameters(
        burnSpeed: 0.94,
        spreadRate: 1.16,
        coolingRate: 0.11,
        ignitionRadius: 0.022,
        edgeWidth: 0.065,
        stainWidth: 0.14,
        charWidth: 0.022,
        glowAmount: 0.46,
        noiseStrength: 0.88,
        frontComplexity: 0.94,
        ignitionVariance: 0.95,
        flameAmount: 0.42,
        paperWrinkleAmount: 0.72,
        smokeAmount: 0.22,
        emberAmount: 0.24
    )

    var sanitized: BurnParameters {
        BurnParameters(
            burnSpeed: burnSpeed.clamped(to: 0.01...3.0),
            spreadRate: spreadRate.clamped(to: 0.0...3.0),
            coolingRate: coolingRate.clamped(to: 0.0...2.0),
            ignitionRadius: ignitionRadius.clamped(to: 0.005...0.2),
            edgeWidth: edgeWidth.clamped(to: 0.001...0.25),
            stainWidth: stainWidth.clamped(to: 0.001...0.25),
            charWidth: charWidth.clamped(to: 0.001...0.15),
            glowAmount: glowAmount.clamped(to: 0.0...1.0),
            noiseStrength: noiseStrength.clamped(to: 0.0...1.0),
            frontComplexity: frontComplexity.clamped(to: 0.0...1.0),
            ignitionVariance: ignitionVariance.clamped(to: 0.0...1.0),
            flameAmount: flameAmount.clamped(to: 0.0...1.0),
            paperWrinkleAmount: paperWrinkleAmount.clamped(to: 0.0...1.0),
            smokeAmount: smokeAmount.clamped(to: 0.0...1.0),
            emberAmount: emberAmount.clamped(to: 0.0...1.0)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

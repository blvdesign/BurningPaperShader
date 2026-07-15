/// Controls the appearance and propagation of the burning paper effect.
public struct BurningPaperConfiguration: Equatable, Sendable {
    /// The simulation speed, sanitized to `0.01...3.0`.
    public var burnSpeed: Float

    /// The rate at which fire spreads, sanitized to `0...3.0`.
    public var spreadRate: Float

    /// The rate at which burned areas cool, sanitized to `0...2.0`.
    public var coolingRate: Float

    /// The normalized ignition radius, sanitized to `0.005...0.2`.
    public var ignitionRadius: Float

    /// The width of the active burning edge, sanitized to `0.001...0.25`.
    public var edgeWidth: Float

    /// The width of the brown heat stain, sanitized to `0.001...0.25`.
    public var stainWidth: Float

    /// The width of the charred rim, sanitized to `0.001...0.15`.
    public var charWidth: Float

    /// The intensity of the glowing edge, sanitized to `0...1`.
    public var glowAmount: Float

    /// The strength of spatial burn variation, sanitized to `0...1`.
    public var noiseStrength: Float

    /// The irregularity of the burn front, sanitized to `0...1`.
    public var frontComplexity: Float

    /// The variation between ignition points, sanitized to `0...1`.
    public var ignitionVariance: Float

    /// The amount of visible flame, sanitized to `0...1`.
    public var flameAmount: Float

    /// The strength of the procedural paper wrinkles, sanitized to `0...1`.
    public var paperWrinkleAmount: Float

    /// The amount of smoke shading, sanitized to `0...1`.
    public var smokeAmount: Float

    /// The amount of glowing embers, sanitized to `0...1`.
    public var emberAmount: Float

    /// The base color of the procedural paper.
    public var paperColor: BurningPaperColor

    /// Creates a configuration with individually adjustable burn parameters.
    public init(
        burnSpeed: Float = 0.94,
        spreadRate: Float = 1.16,
        coolingRate: Float = 0.11,
        ignitionRadius: Float = 0.022,
        edgeWidth: Float = 0.065,
        stainWidth: Float = 0.14,
        charWidth: Float = 0.022,
        glowAmount: Float = 0.46,
        noiseStrength: Float = 0.88,
        frontComplexity: Float = 0.94,
        ignitionVariance: Float = 0.95,
        flameAmount: Float = 0.42,
        paperWrinkleAmount: Float = 0.72,
        smokeAmount: Float = 0.22,
        emberAmount: Float = 0.24,
        paperColor: BurningPaperColor = .naturalWhite
    ) {
        self.burnSpeed = burnSpeed
        self.spreadRate = spreadRate
        self.coolingRate = coolingRate
        self.ignitionRadius = ignitionRadius
        self.edgeWidth = edgeWidth
        self.stainWidth = stainWidth
        self.charWidth = charWidth
        self.glowAmount = glowAmount
        self.noiseStrength = noiseStrength
        self.frontComplexity = frontComplexity
        self.ignitionVariance = ignitionVariance
        self.flameAmount = flameAmount
        self.paperWrinkleAmount = paperWrinkleAmount
        self.smokeAmount = smokeAmount
        self.emberAmount = emberAmount
        self.paperColor = paperColor
    }

    /// The configuration tuned for the standard burning paper appearance.
    public static let `default` = BurningPaperConfiguration()

    var sanitized: BurningPaperConfiguration {
        let fallback = Self.default

        return BurningPaperConfiguration(
            burnSpeed: burnSpeed.burningPaperSanitized(to: 0.01...3.0, fallback: fallback.burnSpeed),
            spreadRate: spreadRate.burningPaperSanitized(to: 0.0...3.0, fallback: fallback.spreadRate),
            coolingRate: coolingRate.burningPaperSanitized(to: 0.0...2.0, fallback: fallback.coolingRate),
            ignitionRadius: ignitionRadius.burningPaperSanitized(to: 0.005...0.2, fallback: fallback.ignitionRadius),
            edgeWidth: edgeWidth.burningPaperSanitized(to: 0.001...0.25, fallback: fallback.edgeWidth),
            stainWidth: stainWidth.burningPaperSanitized(to: 0.001...0.25, fallback: fallback.stainWidth),
            charWidth: charWidth.burningPaperSanitized(to: 0.001...0.15, fallback: fallback.charWidth),
            glowAmount: glowAmount.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.glowAmount),
            noiseStrength: noiseStrength.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.noiseStrength),
            frontComplexity: frontComplexity.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.frontComplexity),
            ignitionVariance: ignitionVariance.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.ignitionVariance),
            flameAmount: flameAmount.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.flameAmount),
            paperWrinkleAmount: paperWrinkleAmount.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.paperWrinkleAmount),
            smokeAmount: smokeAmount.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.smokeAmount),
            emberAmount: emberAmount.burningPaperSanitized(to: 0.0...1.0, fallback: fallback.emberAmount),
            paperColor: paperColor.sanitized
        )
    }
}

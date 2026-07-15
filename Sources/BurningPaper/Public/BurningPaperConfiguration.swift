public struct BurningPaperConfiguration: Equatable, Sendable {
    public var burnSpeed: Float
    public var spreadRate: Float
    public var coolingRate: Float
    public var ignitionRadius: Float
    public var edgeWidth: Float
    public var stainWidth: Float
    public var charWidth: Float
    public var glowAmount: Float
    public var noiseStrength: Float
    public var frontComplexity: Float
    public var ignitionVariance: Float
    public var flameAmount: Float
    public var paperWrinkleAmount: Float
    public var smokeAmount: Float
    public var emberAmount: Float
    public var paperColor: BurningPaperColor

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

    public static let `default` = BurningPaperConfiguration()

    var sanitized: BurningPaperConfiguration {
        BurningPaperConfiguration(
            burnSpeed: burnSpeed.burningPaperClamped(to: 0.01...3.0),
            spreadRate: spreadRate.burningPaperClamped(to: 0.0...3.0),
            coolingRate: coolingRate.burningPaperClamped(to: 0.0...2.0),
            ignitionRadius: ignitionRadius.burningPaperClamped(to: 0.005...0.2),
            edgeWidth: edgeWidth.burningPaperClamped(to: 0.001...0.25),
            stainWidth: stainWidth.burningPaperClamped(to: 0.001...0.25),
            charWidth: charWidth.burningPaperClamped(to: 0.001...0.15),
            glowAmount: glowAmount.burningPaperClamped(to: 0.0...1.0),
            noiseStrength: noiseStrength.burningPaperClamped(to: 0.0...1.0),
            frontComplexity: frontComplexity.burningPaperClamped(to: 0.0...1.0),
            ignitionVariance: ignitionVariance.burningPaperClamped(to: 0.0...1.0),
            flameAmount: flameAmount.burningPaperClamped(to: 0.0...1.0),
            paperWrinkleAmount: paperWrinkleAmount.burningPaperClamped(to: 0.0...1.0),
            smokeAmount: smokeAmount.burningPaperClamped(to: 0.0...1.0),
            emberAmount: emberAmount.burningPaperClamped(to: 0.0...1.0),
            paperColor: paperColor.sanitized
        )
    }
}

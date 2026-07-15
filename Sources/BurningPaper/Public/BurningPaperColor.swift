public struct BurningPaperColor: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let naturalWhite = BurningPaperColor(
        red: 0.978,
        green: 0.966,
        blue: 0.925,
        alpha: 1
    )

    var sanitized: BurningPaperColor {
        BurningPaperColor(
            red: red.burningPaperClamped(to: 0...1),
            green: green.burningPaperClamped(to: 0...1),
            blue: blue.burningPaperClamped(to: 0...1),
            alpha: alpha.burningPaperClamped(to: 0...1)
        )
    }
}

extension Float {
    func burningPaperClamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

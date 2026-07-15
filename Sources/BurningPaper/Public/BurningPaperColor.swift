/// An RGBA color used by the burning paper renderer.
public struct BurningPaperColor: Equatable, Sendable {
    /// The red component. Sanitized to `0...1` before rendering.
    public var red: Float

    /// The green component. Sanitized to `0...1` before rendering.
    public var green: Float

    /// The blue component. Sanitized to `0...1` before rendering.
    public var blue: Float

    /// The alpha component. Sanitized to `0...1` before rendering.
    public var alpha: Float

    /// Creates a color from red, green, blue, and alpha components.
    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// The warm white color used by the default procedural paper.
    public static let naturalWhite = BurningPaperColor(
        red: 0.978,
        green: 0.966,
        blue: 0.925,
        alpha: 1
    )

    var sanitized: BurningPaperColor {
        let fallback = Self.naturalWhite

        return BurningPaperColor(
            red: red.burningPaperSanitized(to: 0...1, fallback: fallback.red),
            green: green.burningPaperSanitized(to: 0...1, fallback: fallback.green),
            blue: blue.burningPaperSanitized(to: 0...1, fallback: fallback.blue),
            alpha: alpha.burningPaperSanitized(to: 0...1, fallback: fallback.alpha)
        )
    }
}

extension Float {
    func burningPaperSanitized(to range: ClosedRange<Float>, fallback: Float) -> Float {
        if isNaN {
            return fallback
        }
        if self == .infinity {
            return range.upperBound
        }
        if self == -.infinity {
            return range.lowerBound
        }

        return min(max(self, range.lowerBound), range.upperBound)
    }
}

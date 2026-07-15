import CoreGraphics

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

enum BurnIgnitionPlanner {
    static let maximumIgnitionsPerPath = 96

    static func ignitions<R: RandomNumberGenerator>(
        from start: CGPoint?,
        to end: CGPoint,
        random: inout R
    ) -> [BurnIgnition] {
        guard isFinite(end) else {
            return []
        }

        let start = start.flatMap { isFinite($0) ? $0 : nil }
        guard let start else {
            return [makeIgnition(at: end, radiusScale: Float.random(in: 0.72...1.36, using: &random), random: &random)]
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        let steps = max(1, min(9, Int(ceil(distance * 74))))
        let normalLength = max(distance, 0.0001)
        let normal = CGPoint(x: -dy / normalLength, y: dx / normalLength)
        let tangent = CGPoint(x: dx / normalLength, y: dy / normalLength)

        return (1...steps).flatMap { index in
            let rawT = CGFloat(index) / CGFloat(steps)
            let tJitter = CGFloat.random(in: -0.22...0.18, using: &random) / CGFloat(max(steps, 1))
            let t = min(max(rawT + tJitter, 0), 1)
            let lateral = CGFloat.random(in: -0.014...0.014, using: &random) * (0.7 + distance * 8.0)
            let forward = CGFloat.random(in: -0.006...0.008, using: &random)
            let center = CGPoint(
                x: start.x + dx * t + normal.x * lateral + tangent.x * forward,
                y: start.y + dy * t + normal.y * lateral + tangent.y * forward
            )

            var ignitions = [
                makeIgnition(
                    at: center,
                    radiusScale: Float.random(in: 0.58...1.58, using: &random),
                    random: &random
                )
            ]

            if distance > 0.012 && Float.random(in: 0...1, using: &random) > 0.48 {
                let sideOffset = CGFloat.random(in: -0.026...0.026, using: &random)
                let sidePoint = CGPoint(
                    x: center.x + normal.x * sideOffset + tangent.x * CGFloat.random(in: -0.004...0.004, using: &random),
                    y: center.y + normal.y * sideOffset + tangent.y * CGFloat.random(in: -0.004...0.004, using: &random)
                )
                ignitions.append(
                    makeIgnition(
                        at: sidePoint,
                        radiusScale: Float.random(in: 0.34...0.78, using: &random),
                        random: &random
                    )
                )
            }

            if distance > 0.035 && Float.random(in: 0...1, using: &random) > 0.86 {
                let emberPoint = CGPoint(
                    x: center.x + CGFloat.random(in: -0.028...0.028, using: &random),
                    y: center.y + CGFloat.random(in: -0.028...0.028, using: &random)
                )
                ignitions.append(
                    makeIgnition(
                        at: emberPoint,
                        radiusScale: Float.random(in: 0.22...0.48, using: &random),
                        random: &random
                    )
                )
            }

            return ignitions
        }
    }

    static func ignitions<R: RandomNumberGenerator>(
        for normalizedPoints: [CGPoint],
        random: inout R
    ) -> [BurnIgnition] {
        let validPoints = normalizedPoints.filter(isFinite)
        guard let first = validPoints.first else {
            return []
        }

        var result = ignitions(from: nil, to: first, random: &random)
        var previous = first

        for point in validPoints.dropFirst() where point != previous {
            result.append(contentsOf: ignitions(from: previous, to: point, random: &random))
            previous = point
        }

        return evenlyDownsampled(result, maximumCount: maximumIgnitionsPerPath)
    }

    private static func evenlyDownsampled(
        _ ignitions: [BurnIgnition],
        maximumCount: Int
    ) -> [BurnIgnition] {
        guard ignitions.count > maximumCount else {
            return ignitions
        }

        let lastIndex = ignitions.count - 1
        return (0..<maximumCount).map { sampleIndex in
            let position = Double(sampleIndex) * Double(lastIndex) / Double(maximumCount - 1)
            return ignitions[Int(position.rounded())]
        }
    }

    private static func isFinite(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
    }

    private static func makeIgnition<R: RandomNumberGenerator>(
        at point: CGPoint,
        radiusScale: Float,
        random: inout R
    ) -> BurnIgnition {
        BurnIgnition(
            normalizedPoint: CGPoint(
                x: min(max(point.x, 0), 1),
                y: min(max(point.y, 0), 1)
            ),
            radiusScale: radiusScale,
            heatScale: Float.random(in: 0.66...1.28, using: &random),
            seed: Float.random(in: 0...4096, using: &random)
        )
    }
}

import MetalKit
import SwiftUI

struct BurnIgnition: Equatable {
    var normalizedPoint: CGPoint
    var radiusScale: Float
    var heatScale: Float
    var seed: Float
}

struct BurnTrigger: Equatable, Identifiable {
    let id = UUID()
    var ignitions: [BurnIgnition]

    init(normalizedPoint: CGPoint) {
        self.ignitions = [
            BurnIgnition(
                normalizedPoint: normalizedPoint,
                radiusScale: 1,
                heatScale: 1,
                seed: Float.random(in: 0...4096)
            )
        ]
    }

    init(normalizedPoints: [CGPoint]) {
        let baseSeed = Float.random(in: 0...4096)
        self.ignitions = normalizedPoints.enumerated().map { index, point in
            BurnIgnition(
                normalizedPoint: point,
                radiusScale: 1,
                heatScale: 1,
                seed: baseSeed + Float(index) * 17.31
            )
        }
    }

    init(ignitions: [BurnIgnition]) {
        self.ignitions = ignitions
    }
}

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
    static func ignitions<R: RandomNumberGenerator>(
        from start: CGPoint?,
        to end: CGPoint,
        random: inout R
    ) -> [BurnIgnition] {
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

struct MetalView: UIViewRepresentable {
    var parameters: BurnParameters
    var trigger: BurnTrigger?
    var resetToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isOpaque = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 120
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        if let device = view.device,
           let renderer = BurnRenderer(device: device, colorPixelFormat: view.colorPixelFormat) {
            view.delegate = renderer
            context.coordinator.renderer = renderer
        }

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        let renderer = context.coordinator.renderer
        renderer?.parameters = parameters.sanitized

        if context.coordinator.lastResetToken != resetToken {
            renderer?.reset()
            context.coordinator.lastResetToken = resetToken
        }

        if context.coordinator.lastTriggerID != trigger?.id, let trigger {
            renderer?.ignite(trigger.ignitions)
            context.coordinator.lastTriggerID = trigger.id
        }
    }

    final class Coordinator {
        var renderer: BurnRenderer?
        var lastTriggerID: UUID?
        var lastResetToken: UUID?
    }
}

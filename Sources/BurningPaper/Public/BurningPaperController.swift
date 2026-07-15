import Combine
import CoreGraphics
import Foundation

struct BurningPaperCommand: Equatable, Identifiable {
    enum Kind: Equatable {
        case ignite([CGPoint])
        case reset
    }

    let id: UUID
    let kind: Kind

    init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

/// Sends programmatic ignition and reset commands to a burning paper view.
@MainActor
@available(macOS 10.15, *)
public final class BurningPaperController: ObservableObject {
    @Published private(set) var commandRevision: UInt64 = 0
    private var pendingCommands: [BurningPaperCommand] = []

    /// Creates a controller with no pending command.
    public init() {}

    /// Ignites the paper at a normalized point.
    ///
    /// Coordinates are clamped to `0...1`. A point containing `NaN` or infinity
    /// is ignored so non-finite values never reach the renderer.
    public func ignite(at normalizedPoint: CGPoint) {
        guard let point = Self.normalized(normalizedPoint) else {
            return
        }

        enqueue(.ignite([point]))
    }

    /// Ignites the paper along a path of normalized points.
    ///
    /// Coordinates are clamped to `0...1`, while points containing `NaN` or
    /// infinity are omitted. An empty resulting path is a no-op.
    public func ignite(path normalizedPoints: [CGPoint]) {
        let points = normalizedPoints.compactMap(Self.normalized)
        guard !points.isEmpty else {
            return
        }

        enqueue(.ignite(points))
    }

    /// Resets the paper to its initial unburned state.
    public func reset() {
        enqueue(.reset)
    }

    func drainPendingCommands() -> [BurningPaperCommand] {
        let commands = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)
        return commands
    }

    private func enqueue(_ kind: BurningPaperCommand.Kind) {
        pendingCommands.append(BurningPaperCommand(kind: kind))
        commandRevision &+= 1
    }

    private static func normalized(_ point: CGPoint) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite else {
            return nil
        }

        return CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }
}

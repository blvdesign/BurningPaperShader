import CoreGraphics
import SwiftUI

@MainActor
final class BurningPaperViewState: ObservableObject {
    @Published private(set) var revision: UInt64 = 0

    private var lastDragPoint: CGPoint?
    private var pendingIgnitions: [[BurnIgnition]] = []
    private var random: SeededRandomNumberGenerator

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        random = SeededRandomNumberGenerator(seed: seed)
    }

    func dragChanged(location: CGPoint, in size: CGSize, isInteractive: Bool) {
        guard isInteractive else {
            lastDragPoint = nil
            return
        }

        planIgnitions(to: location, in: size)
    }

    func dragEnded(location: CGPoint, in size: CGSize, isInteractive: Bool) {
        guard isInteractive else {
            lastDragPoint = nil
            return
        }

        planIgnitions(to: location, in: size)
        lastDragPoint = nil
    }

    func drainPendingIgnitions() -> [[BurnIgnition]] {
        let batches = pendingIgnitions
        pendingIgnitions.removeAll(keepingCapacity: true)
        return batches
    }

    func clearPendingIgnitions() {
        pendingIgnitions.removeAll(keepingCapacity: true)
        lastDragPoint = nil
    }

    private func planIgnitions(to location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite,
              location.x.isFinite, location.y.isFinite else {
            return
        }

        let point = CGPoint(
            x: min(max(location.x / size.width, 0), 1),
            y: min(max(location.y / size.height, 0), 1)
        )
        let ignitions = BurnIgnitionPlanner.ignitions(
            from: lastDragPoint,
            to: point,
            random: &random
        )
        lastDragPoint = point

        guard !ignitions.isEmpty else {
            return
        }

        pendingIgnitions.append(ignitions)
        revision &+= 1
    }
}

/// A SwiftUI surface that renders and optionally interacts with burning paper.
@MainActor
public struct BurningPaperView: View {
    @ObservedObject private var controller: BurningPaperController
    @StateObject private var interaction: BurningPaperViewState

    private let configuration: BurningPaperConfiguration
    private let isInteractive: Bool

    /// Creates a burning-paper surface driven by the supplied controller.
    public init(
        controller: BurningPaperController,
        configuration: BurningPaperConfiguration = .default,
        isInteractive: Bool = true
    ) {
        _controller = ObservedObject(wrappedValue: controller)
        _interaction = StateObject(wrappedValue: BurningPaperViewState())
        self.configuration = configuration
        self.isInteractive = isInteractive
    }

    public var body: some View {
        GeometryReader { proxy in
            if isInteractive {
                metalView
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                interaction.dragChanged(
                                    location: value.location,
                                    in: proxy.size,
                                    isInteractive: true
                                )
                            }
                            .onEnded { value in
                                interaction.dragEnded(
                                    location: value.location,
                                    in: proxy.size,
                                    isInteractive: true
                                )
                            }
                    )
            } else {
                metalView
            }
        }
    }

    private var metalView: some View {
        BurningPaperMetalView(
            controller: controller,
            configuration: configuration,
            interaction: interaction,
            commandRevision: controller.commandRevision,
            interactionRevision: interaction.revision
        )
    }
}
